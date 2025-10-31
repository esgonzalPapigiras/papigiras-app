import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService extends ChangeNotifier {
  Timer? _locationTimer;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  void startTracking() {
    _isTracking = true;
    notifyListeners();

    _locationTimer = Timer.periodic(Duration(seconds: 60), (_) async {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _saveLocation(pos);
    });
  }

  void stopTracking() {
    _isTracking = false;
    _locationTimer?.cancel();
    notifyListeners();
  }

  Future<void> _saveLocation(Position position) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? userRole = prefs.getString('userRole');
    if (userRole == null || userRole.toLowerCase() != 'coordinator') {
      print('Skipped saving location: user is not a coordinator');
      return;
    }
    String? tourSales = prefs.getString('loginData');
    final body = json.decode(tourSales!);

    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/add-position-coordinator', {
      'latitud': position.latitude.toString(),
      'longitud': position.longitude.toString(),
      'idCoordinator': body['tourSalesId'].toString()
    });
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      print('Ubicación guardada correctamente');
    } else {
      print('Error al guardar la ubicación');
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }
}
