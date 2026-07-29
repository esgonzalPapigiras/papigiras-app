import 'dart:convert';

import 'package:background_locator_2/location_dto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
}) async {
  final prefs = await SharedPreferences.getInstance();
  final userRole = prefs.getString('userRole');
  if (userRole == null || userRole.toLowerCase() != 'coordinator') {
    return;
  }

  final token = prefs.getString('token');
  final tourSales = prefs.getString('loginData');
  if (tourSales == null) return;

  final body = json.decode(tourSales);
  final url = Uri.https(
    'stingray-app-9tqd9-djh6d.ondigitalocean.app',
    '/app/services/add-position-coordinator',
    {
      'latitud': latitude.toString(),
      'longitud': longitude.toString(),
      'idCoordinator': body['tourSalesId'].toString(),
    },
  );

  debugPrint('Location callback: $latitude, $longitude');
  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (response.statusCode == 200) {
      debugPrint('Ubicación guardada');
    } else {
      debugPrint('Error al guardar ubicación (${response.statusCode})');
    }
  } catch (error) {
    debugPrint('Excepción enviando ubicación: $error');
  }
}
