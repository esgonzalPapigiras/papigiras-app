import 'dart:convert';

import 'package:background_locator_2/location_dto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _pendingLocationsKey = 'pendingCoordinatorLocations';
const _maximumPendingLocations = 200;
Future<void> _sendChain = Future<void>.value();

@pragma('vm:entry-point')
void locationCallback(LocationDto locationDto) async {
  await sendCoordinatorLocation(
    latitude: locationDto.latitude,
    longitude: locationDto.longitude,
  );
}

Future<void> sendCoordinatorLocation({
  required double latitude,
  required double longitude,
}) {
  final operation = _sendChain.then((_) => _sendCoordinatorLocation(
        latitude: latitude,
        longitude: longitude,
      ));
  _sendChain = operation.catchError((Object error) {
    debugPrint('Location send queue error: $error');
  });
  return operation;
}

Future<void> _sendCoordinatorLocation({
  required double latitude,
  required double longitude,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final userRole = prefs.getString('userRole');
  if (userRole == null || userRole.toLowerCase() != 'coordinator') return;

  final token = prefs.getString('token');
  final selectedTourId = prefs.getInt('selectedTourId');
  if (token == null || token.isEmpty || selectedTourId == null) return;

  await _flushPendingLocations(prefs, token);

  final location = <String, dynamic>{
    'latitude': latitude,
    'longitude': longitude,
    'tourId': selectedTourId,
    'recordedAt': DateTime.now().toUtc().toIso8601String(),
  };

  if (!await _postLocation(location, token)) {
    await _queueLocation(prefs, location);
  }
}

Future<bool> _postLocation(Map<String, dynamic> location, String token) async {
  final url = Uri.https(
    'stingray-app-9tqd9-djh6d.ondigitalocean.app',
    '/app/services/add-position-coordinator',
    {
      'latitud': location['latitude'].toString(),
      'longitud': location['longitude'].toString(),
      'tourId': location['tourId'].toString(),
      'recordedAt': location['recordedAt'].toString(),
    },
  );

  try {
    final response = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': token,
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint(
          'Coordinator location saved: ${location['latitude']}, ${location['longitude']}');
      return true;
    }
    debugPrint('Location upload failed (${response.statusCode})');
  } catch (error) {
    debugPrint('Location upload exception: $error');
  }
  return false;
}

Future<void> _flushPendingLocations(
    SharedPreferences prefs, String token) async {
  final encoded = prefs.getStringList(_pendingLocationsKey) ?? const [];
  if (encoded.isEmpty) return;

  final remaining = <String>[];
  for (final item in encoded) {
    try {
      final location = jsonDecode(item) as Map<String, dynamic>;
      if (!await _postLocation(location, token)) remaining.add(item);
    } catch (error) {
      debugPrint('Discarding invalid queued location: $error');
    }
  }
  await prefs.setStringList(_pendingLocationsKey, remaining);
}

Future<void> _queueLocation(
    SharedPreferences prefs, Map<String, dynamic> location) async {
  final pending = prefs.getStringList(_pendingLocationsKey) ?? <String>[];
  pending.add(jsonEncode(location));
  if (pending.length > _maximumPendingLocations) {
    pending.removeRange(0, pending.length - _maximumPendingLocations);
  }
  await prefs.setStringList(_pendingLocationsKey, pending);
  debugPrint('Location queued for retry (${pending.length} pending)');
}
