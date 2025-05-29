import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class MapScreen extends StatefulWidget {
  final ResponseAttorney login;

  MapScreen({required this.login, required List locations});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _coordinatorPosition;
  Timer? _updateTimer;
  final usuarioProvider = new CoordinatorProviders();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _startUpdatingGPS();
  }

  @override
  void dispose() {
    _updateTimer?.cancel(); // Cancela el timer al cerrar la pantalla
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permiso denegado permanentemente')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      // Centra el mapa en la posición actual
      _mapController.move(
        _currentPosition!,
        15.0,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener ubicación: $e')),
      );
    }
  }

  void _startUpdatingGPS() {
    _updateTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      await _updateCoordinatorPosition();
    });
  }

  Future<void> _updateCoordinatorPosition() async {
    try {
      PositionCoordinator result =
          await usuarioProvider.uniqueID(widget.login.tourId.toString());
      LatLng newPosition = LatLng(result.positionCoordinatorLatitud,
          result.positionCoordinatorLongitud);

      setState(() {
        _coordinatorPosition = newPosition;
      });

      // Centra el mapa en la nueva posición del coordinador
      _mapController.move(newPosition, 15.0);
    } catch (e) {
      print('Error updating coordinator position: $e');
    }
  }

  Future<String?> _loadToken() async {
    // Simulación de carga de token. Reemplazar con la lógica real.
    return 'your-token-here';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentPosition ?? LatLng(0, 0), // Default position
          initialZoom: 13.0,
          maxZoom: 40.0,
          minZoom: 5.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          if (_currentPosition != null)
            LocationMarkerLayer(
              position: LocationMarkerPosition(
                latitude: _currentPosition!.latitude,
                longitude: _currentPosition!.longitude,
                accuracy: 50.0,
              ),
              style: LocationMarkerStyle(
                marker: DefaultLocationMarker(
                  color: Colors.blue,
                  child: Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                accuracyCircleColor: Colors.blue.withOpacity(0.1),
              ),
            ),
          if (_coordinatorPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _coordinatorPosition!,
                  width: 100,
                  height: 100,
                  child: Column(
                    children: [
                      Text(
                        'Coordinador',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            backgroundColor: Colors.white),
                      ),
                      Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 30,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
