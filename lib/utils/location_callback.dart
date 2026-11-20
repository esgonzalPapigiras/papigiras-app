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
Future<void> _sendChain = Future<void>.value();

@visibleForTesting
LabApiClient? locationClientForTests;

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
              prefs.getBool('coordinatorLocationSharingEnabled') == true &&
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
      if (!await _postLocation(location, token)) {
        remaining.addAll(pending.sublist(i));
        break;
      }
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
    };
    if (!await _postLocation(location, token)) {
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

Future<bool> _postLocation(Map<String, dynamic> location, String token) async {
  if (LabMode.fixturesForTests && locationClientForTests == null) return true;
  final client = locationClientForTests ?? LabApiClient();
  final url = LabApi.uri('/app/services/add-position-coordinator', {
    'latitud': location['latitude'].toString(),
    'longitud': location['longitude'].toString(),
    'tourId': location['tourId'].toString(),
    'recordedAt': location['recordedAt'].toString(),
  });
  try {
    await client.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': token},
    );
    return true;
  } catch (error) {
    // Personal data and exception payloads are intentionally not logged.
    return false;
  } finally {
    if (locationClientForTests == null) client.close();
  }
}
