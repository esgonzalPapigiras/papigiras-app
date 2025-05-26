import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocationService extends ChangeNotifier {
  late Timer _locationTimer;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  void startTracking() {
    _isTracking = true;
    notifyListeners();

    _locationTimer = Timer.periodic(Duration(seconds: 6000), (_) async {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _saveLocation(pos);
    });
  }

  void stopTracking() {
    _isTracking = false;
    _locationTimer.cancel();
    notifyListeners();
  }

  Future<void> _saveLocation(Position position) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token != null) {
      final String url =
          'http://tu-servidor-api.com/save-location'; // URL de tu API

      // Realizar la solicitud POST para guardar la ubicación
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body:
            '{"latitude": ${position.latitude}, "longitude": ${position.longitude}}',
      );

      if (response.statusCode == 200) {
        print('Ubicación guardada correctamente');
      } else {
        print('Error al guardar la ubicación');
      }
    }
  }

  @override
  void dispose() {
    _locationTimer.cancel();
    super.dispose();
  }
}
