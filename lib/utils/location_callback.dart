import 'dart:convert';
import 'package:background_locator_2/location_dto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
void locationCallback(LocationDto locationDto) async {
  final prefs = await SharedPreferences.getInstance();
  String? userRole = prefs.getString('userRole');
  if (userRole == null || userRole.toLowerCase() != 'coordinator') {
    return;
  }
  String? token = prefs.getString('token');
  String? tourSales = prefs.getString('loginData');
  if (tourSales == null) return;
  final body = json.decode(tourSales);
  var url = Uri.https(
    'stingray-app-9tqd9-djh6d.ondigitalocean.app',
    '/app/services/add-position-coordinator',
    {
      'latitud': locationDto.latitude.toString(),
      'longitud': locationDto.longitude.toString(),
      'idCoordinator': body['tourSalesId'].toString()
    },
  );
  print("🔥 CALLBACK TRIGGERED: ${locationDto.latitude}, ${locationDto.longitude}");
  try {
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': token ?? ''
    });
    if (resp.statusCode == 200) {
      print('Ubicación guardada (background)');
    } else {
      print('Error al guardar ubicación (background)');
    }
  } catch (e) {
    print('Exception enviando ubicación: $e');
  }
}
