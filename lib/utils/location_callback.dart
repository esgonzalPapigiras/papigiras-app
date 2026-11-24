import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import '../runtime/api_destination.dart';

// Same original serialized queue, tour context and recordedAt API contract.
const pendingLocationsKey = 'pendingCoordinatorLocations';
// Each isolate owns its queue. SharedPreferences does not provide a cross-
// isolate read/modify/write transaction; using one key loses offline points.
const pendingBackgroundLocationsKey = 'pendingBackgroundCoordinatorLocations';

enum LocationQueue { foreground, background }

const maximumPendingLocations = 200;
const nativeTrackingSessionKey = 'nativeTrackingSession';
const nativeTrackingTourKey = 'nativeTrackingTour';
const pendingNativeClaimKey = 'pendingNativeGpsClaim';
const pendingLocationStopPrefix = 'pendingLocationStop:';
const locationRejectionPrefix = 'rejectedLocationSession:';
Future<void> _sendChain = Future<void>.value();
String? _registeredTrackingSession;
String? _registeredTrackingToken;

Future<void> claimLocationSharing(
  String token,
  int tourId,
  String session, {
  int? expectedOwnerGeneration,
  LabApiClient? transport,
}) async {
  final client = transport ?? locationClientForTests ?? LabApiClient();
  try {
    await client
        .post(
          LabApi.uri('/app/services/coordinator/location-sharing'),
          headers: {'Content-Type': 'application/json', 'Authorization': token},
          body: jsonEncode({
            'tourId': tourId,
            'session': session,
            'enabled': true,
            if (expectedOwnerGeneration != null)
              'expectedOwnerGeneration': expectedOwnerGeneration,
          }),
        )
        .timeout(const Duration(seconds: 12));
    _registeredTrackingSession = session;
    _registeredTrackingToken = token;
  } finally {
    if (transport == null && locationClientForTests == null) client.close();
  }
}

Future<String?> coordinatorSharingOnServer(String token, int? tourId) async {
  final client = locationClientForTests ?? LabApiClient();
  try {
    final response = await client
        .get(
          LabApi.uri(
            '/app/services/coordinator/me/session',
            tourId == null ? null : {'tourId': tourId.toString()},
          ),
          headers: {'Authorization': token},
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body);
    if (data is! Map ||
        !data.containsKey('sharingSession') ||
        (data['sharingSession'] != null && data['sharingSession'] is! String)) {
      throw const FormatException('Respuesta de sesión no reconocida.');
    }
    return data['sharingSession'] as String?;
  } finally {
    if (locationClientForTests == null) client.close();
  }
}

@visibleForTesting
LabApiClient? locationClientForTests;

/// Captured before local revocation; never send OFF using a later login/tour.
class RemoteLocationStop {
  const RemoteLocationStop(
    this._token,
    this.tourId,
    this.session, {
    this.ownerId,
  });
  final String _token;
  final int tourId;
  final String session;
  final int? ownerId;
  String get storageKey =>
      '$pendingLocationStopPrefix${Uri.encodeComponent(AppEnvironment.apiUrl)}:$ownerId:$tourId:$session';
}

int? _coordinatorOwner(SharedPreferences prefs) {
  if (prefs.getString('userRole') != 'coordinator') return null;
  try {
    final data = jsonDecode(prefs.getString('coordinatorData') ?? '');
    final id = data is Map ? data['coordinatorId'] : null;
    return id is int && id > 0 ? id : null;
  } catch (_) {
    return null;
  }
}

/// Each intent has its own key: background and UI isolates cannot overwrite
/// each other's pending list. Only origin, account ID, tour and nonce persist.
Future<void> rememberRemoteLocationStop(RemoteLocationStop target) async {
  if (!AppEnvironment.connected || target.ownerId == null) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    target.storageKey,
    jsonEncode({
      'origin': AppEnvironment.apiUrl,
      'ownerId': target.ownerId,
      'tourId': target.tourId,
      'session': target.session,
    }),
  );
}

Future<bool> retryPendingLocationStops(SharedPreferences prefs) async {
  if (!AppEnvironment.connected) return true;
  await prefs.reload();
  final owner = _coordinatorOwner(prefs), token = prefs.getString('token');
  if (owner == null || token == null || token.isEmpty) return true;
  final keys = prefs
      .getKeys()
      .where((key) => key.startsWith(pendingLocationStopPrefix))
      .toList();
  var attempted = 0;
  for (final key in keys) {
    await prefs.reload();
    if (_coordinatorOwner(prefs) != owner || prefs.getString('token') != token)
      return false;
    try {
      final data = jsonDecode(prefs.getString(key) ?? '');
      if (data is! Map ||
          data['origin'] != AppEnvironment.apiUrl ||
          data['ownerId'] != owner)
        continue;
      final tour = data['tourId'], session = data['session'];
      if (tour is! int ||
          tour <= 0 ||
          session is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{16,96}$').hasMatch(session))
        continue;
      final target = RemoteLocationStop(token, tour, session, ownerId: owner);
      if (target.storageKey != key) continue;
      if (++attempted > 32 || !await stopRemoteLocationSharing(target))
        return false;
    } catch (_) {
      /* Invalid recovery metadata never becomes a request. */
    }
  }
  return true;
}

/// Legacy logout clears all preferences; retain only credential-free OFF intents.
Future<void> clearPreferencesPreservingLocationStops(
  SharedPreferences prefs,
) async {
  await prefs.reload();
  for (final key in prefs.getKeys()) {
    if (!key.startsWith(pendingLocationStopPrefix)) await prefs.remove(key);
  }
}

RemoteLocationStop? captureRemoteLocationStop(SharedPreferences prefs) {
  if (!AppEnvironment.connected || prefs.getString('userRole') != 'coordinator')
    return null;
  final token = prefs.getString('token');
  final tour =
      prefs.getInt(nativeTrackingTourKey) ?? prefs.getInt('selectedTourId');
  final session = prefs.getString(nativeTrackingSessionKey);
  if (token == null ||
      token.isEmpty ||
      tour == null ||
      tour <= 0 ||
      session == null ||
      session.isEmpty)
    return null;
  return RemoteLocationStop(
    token,
    tour,
    session,
    ownerId: _coordinatorOwner(prefs),
  );
}

Future<bool> stopRemoteLocationSharing(RemoteLocationStop target) async {
  final client =
      locationClientForTests ?? LabApiClient(invalidateOnUnauthorized: false);
  try {
    await rememberRemoteLocationStop(target);
    await client
        .post(
          LabApi.uri('/app/services/coordinator/location-sharing'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': target._token,
          },
          body: jsonEncode({
            'tourId': target.tourId,
            'session': target.session,
            'enabled': false,
          }),
        )
        .timeout(const Duration(seconds: 5));
    if (target.ownerId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(target.storageKey);
      await prefs.remove('$locationRejectionPrefix${target.session}');
    }
    return true;
  } catch (_) {
    return false;
  } finally {
    if (locationClientForTests == null) client.close();
  }
}

class LocationSendRejected implements Exception {
  const LocationSendRejected(this.statusCode);
  final int statusCode;
  String get message => statusCode == 401
      ? 'La sesión de este teléfono terminó. Vuelve a ingresar.'
      : statusCode == 403
      ? 'Ya no tienes permiso para compartir ubicación en esta gira.'
      : statusCode == 409
      ? 'Esta sesión de ubicación terminó. Activa de nuevo el envío si deseas compartir.'
      : 'No se pudo iniciar el envío de ubicación. Inténtalo de nuevo más tarde.';
  @override
  String toString() => message;
}

LocationSendRejected? rejectedLocationSession(
  SharedPreferences prefs,
  String? session,
) {
  if (session == null) return null;
  final code = prefs.getInt('$locationRejectionPrefix$session');
  return const {400, 401, 403, 404, 409}.contains(code)
      ? LocationSendRejected(code!)
      : null;
}

/// Exact local POST acknowledged by the existing API, without session secrets.
class CoordinatorLocationReceipt {
  const CoordinatorLocationReceipt({
    required this.tourId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });
  final int tourId;
  final double latitude, longitude;
  final DateTime recordedAt;
}

Future<CoordinatorLocationReceipt?> sendCoordinatorLocation({
  required double latitude,
  required double longitude,
  bool Function()? canSend,
  String? expectedTrackingSession,
  LocationQueue queue = LocationQueue.foreground,
  DateTime? recordedAt,
}) {
  final sessionGeneration = LabSession.generation;
  final capturedAt = recordedAt ?? DateTime.now().toUtc();
  final operation = _sendChain.then(
    (_) => _sendCoordinatorLocation(
      latitude: latitude,
      longitude: longitude,
      canSend: canSend,
      sessionGeneration: sessionGeneration,
      expectedTrackingSession: expectedTrackingSession,
      queue: queue,
      recordedAt: capturedAt,
    ),
  );
  _sendChain = operation.then<void>(
    (_) {},
    onError: (Object error, StackTrace stack) {
      // Personal data and exception payloads are intentionally not logged.
    },
  );
  return operation;
}

Future<CoordinatorLocationReceipt?> _sendCoordinatorLocation({
  required double latitude,
  required double longitude,
  bool Function()? canSend,
  required int sessionGeneration,
  String? expectedTrackingSession,
  required LocationQueue queue,
  required DateTime recordedAt,
}) async {
  if (sessionGeneration != LabSession.generation ||
      (canSend != null && !canSend()))
    return null;
  final prefs = await SharedPreferences.getInstance();
  if (AppEnvironment.connected) await prefs.reload();
  if (sessionGeneration != LabSession.generation ||
      (canSend != null && !canSend()))
    return null;
  if (prefs.getString('userRole') != 'coordinator') return null;
  final token = prefs.getString('token');
  final tourId = prefs.getInt('selectedTourId');
  if (token == null || token.isEmpty || tourId == null) return null;
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    throw ArgumentError('Invalid coordinates');
  }
  bool permitted() =>
      sessionGeneration == LabSession.generation &&
      (canSend?.call() ?? true) &&
      prefs.getString('token') == token &&
      (!AppEnvironment.connected ||
          (expectedTrackingSession != null &&
              prefs.getString(nativeTrackingSessionKey) ==
                  expectedTrackingSession &&
              rejectedLocationSession(prefs, expectedTrackingSession) == null &&
              prefs.getBool('coordinatorLocationSharingEnabled') == true &&
              prefs.getInt(nativeTrackingTourKey) == tourId &&
              prefs.getInt('selectedTourId') == tourId)) &&
      prefs.getString('userRole') == 'coordinator';
  Future<bool> stillPermitted() async {
    if (AppEnvironment.connected) await prefs.reload();
    return permitted();
  }

  if (!await stillPermitted()) return null;
  final queueKey = AppEnvironment.connected && queue == LocationQueue.background
      ? pendingBackgroundLocationsKey
      : pendingLocationsKey;
  final pending = prefs.getStringList(queueKey) ?? <String>[];
  CoordinatorLocationReceipt? receipt;
  final remaining = <String>[];
  for (var i = 0; i < pending.length; i++) {
    if (!await stillPermitted()) {
      remaining.addAll(pending.sublist(i));
      break;
    }
    final encoded = pending[i];
    try {
      final location = jsonDecode(encoded) as Map<String, dynamic>;
      if (AppEnvironment.connected && location['tourId'] != tourId) continue;
      if (AppEnvironment.connected &&
          location['trackingSession'] != expectedTrackingSession)
        continue;
      if (!await _postLocation(location, token, stillPermitted, queue)) {
        remaining.addAll(pending.sublist(i));
        break;
      }
    } on LocationSendRejected {
      rethrow;
    } catch (_) {
      // Preserve the original behavior of discarding invalid serialized queue entries.
    }
  }
  if (await stillPermitted()) {
    final location = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'tourId': tourId,
      'recordedAt': recordedAt.toIso8601String(),
      if (AppEnvironment.connected) 'trackingSession': expectedTrackingSession,
    };
    if (!await _postLocation(location, token, stillPermitted, queue)) {
      remaining.add(jsonEncode(location));
    } else if (permitted() && prefs.getInt('selectedTourId') == tourId) {
      receipt = CoordinatorLocationReceipt(
        tourId: tourId,
        latitude: latitude,
        longitude: longitude,
        recordedAt: recordedAt,
      );
    }
  }
  if (remaining.length > maximumPendingLocations) {
    remaining.removeRange(0, remaining.length - maximumPendingLocations);
  }
  if ((!AppEnvironment.connected || await stillPermitted()) &&
      sessionGeneration == LabSession.generation &&
      prefs.getString('token') == token &&
      prefs.getString('userRole') == 'coordinator') {
    await prefs.setStringList(queueKey, remaining);
  }
  return permitted() && prefs.getInt('selectedTourId') == tourId
      ? receipt
      : null;
}

Future<bool> _postLocation(
  Map<String, dynamic> location,
  String token,
  Future<bool> Function() stillPermitted,
  LocationQueue queue,
) async {
  if (LabMode.fixturesForTests && locationClientForTests == null) return true;
  final client =
      locationClientForTests ??
      LabApiClient(invalidateOnUnauthorized: queue != LocationQueue.background);
  final url = LabApi.uri('/app/services/add-position-coordinator', {
    'latitud': location['latitude'].toString(),
    'longitud': location['longitude'].toString(),
    'tourId': location['tourId'].toString(),
    'recordedAt': location['recordedAt'].toString(),
    if (AppEnvironment.connected)
      'trackingSession': location['trackingSession'].toString(),
  });
  try {
    if (AppEnvironment.connected &&
        (_registeredTrackingSession != location['trackingSession'] ||
            _registeredTrackingToken != token)) {
      await claimLocationSharing(
        token,
        location['tourId'] as int,
        location['trackingSession'] as String,
        transport: client,
      );
    }
    if (!await stillPermitted()) return false;
    await client.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': token},
    );
    return true;
  } catch (error) {
    if (AppEnvironment.connected &&
        error is LabApiException &&
        const {400, 401, 403, 404, 409}.contains(error.statusCode)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (prefs.getString('token') == token &&
          prefs.getString(nativeTrackingSessionKey) ==
              location['trackingSession']) {
        // Per-nonce state cannot revoke a newer login or tracking period.
        await prefs.setInt(
          '$locationRejectionPrefix${location['trackingSession']}',
          error.statusCode,
        );
      }
      throw LocationSendRejected(error.statusCode);
    }
    // Personal data and exception payloads are intentionally not logged.
    return false;
  } finally {
    if (locationClientForTests == null) client.close();
  }
}
