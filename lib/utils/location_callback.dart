import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';

// Same original serialized queue, tour context and recordedAt API contract.
const pendingLocationsKey = 'pendingCoordinatorLocations';
const maximumPendingLocations = 200;
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
}) {
  final sessionGeneration = LabSession.generation;
  final operation = _sendChain.then(
    (_) => _sendCoordinatorLocation(
      latitude: latitude,
      longitude: longitude,
      canSend: canSend,
      sessionGeneration: sessionGeneration,
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
}) async {
  if (sessionGeneration != LabSession.generation ||
      (canSend != null && !canSend()))
    return null;
  final prefs = await SharedPreferences.getInstance();
  if (sessionGeneration != LabSession.generation ||
      (canSend != null && !canSend()))
    return null;
  if (prefs.getString('userRole') != 'coordinator') return null;
  final token = prefs.getString('token');
  final tourId = prefs.getInt('selectedTourId');
  if (token == null || token.isEmpty || tourId == null) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw ArgumentError('Invalid synthetic coordinates');
  }
  bool permitted() =>
      sessionGeneration == LabSession.generation &&
      (canSend?.call() ?? true) &&
      prefs.getString('token') == token &&
      prefs.getString('userRole') == 'coordinator';
  final pending = prefs.getStringList(pendingLocationsKey) ?? <String>[];
  CoordinatorLocationReceipt? receipt;
  final remaining = <String>[];
  for (var i = 0; i < pending.length; i++) {
    if (!permitted()) {
      remaining.addAll(pending.sublist(i));
      break;
    }
    final encoded = pending[i];
    try {
      final location = jsonDecode(encoded) as Map<String, dynamic>;
      if (!await _postLocation(location, token)) {
        remaining.addAll(pending.sublist(i));
        break;
      }
    } catch (_) {
      // Preserve the original behavior of discarding invalid serialized queue entries.
    }
  }
  if (permitted()) {
    final recordedAt = DateTime.now().toUtc();
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
  if (sessionGeneration == LabSession.generation &&
      prefs.getString('token') == token &&
      prefs.getString('userRole') == 'coordinator') {
    await prefs.setStringList(pendingLocationsKey, remaining);
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
