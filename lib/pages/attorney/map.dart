import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
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
  List<PositionCoordinator> _coordinatorPositions = [];
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
    _updateTimer?.cancel();
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
      _mapController.move(_currentPosition!, 15.0);
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
      final results =
          await usuarioProvider.uniqueID(widget.login.tourId.toString());
      setState(() {
        _coordinatorPositions = results;
      });
      if (results.isNotEmpty) {
        _mapController.move(
          LatLng(results.first.latitude, results.first.longitude),
          15.0,
        );
      }
    } catch (e) {
      print('Error updating coordinator position: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text('Ubicación en tiempo real',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                  initialCenter: _currentPosition ?? LatLng(0, 0),
                  initialZoom: 13.0,
                  maxZoom: 40.0,
                  minZoom: 5.0),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png?api_key=14a3454b-2487-40e7-b692-e4a001b9abbd',
                  userAgentPackageName: 'com.papigiras',
                ),
                if (_currentPosition != null)
                  LocationMarkerLayer(
                    position: LocationMarkerPosition(
                        latitude: _currentPosition!.latitude,
                        longitude: _currentPosition!.longitude,
                        accuracy: 50.0),
                    style: LocationMarkerStyle(
                      marker: DefaultLocationMarker(
                          color: Colors.blue,
                          child: Icon(Icons.my_location,
                              color: Colors.white, size: 20)),
                      accuracyCircleColor: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                if (_coordinatorPositions.isNotEmpty)
                  MarkerLayer(
                    markers: _coordinatorPositions
                        .map(
                          (coordinator) => Marker(
                            point: LatLng(
                                coordinator.latitude, coordinator.longitude),
                            width: 100,
                            height: 100,
                            child: Column(
                              children: [
                                Text(
                                  coordinator.fullName,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                Icon(Icons.location_on,
                                    color: Colors.red, size: 30)
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
