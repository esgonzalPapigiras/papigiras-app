import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/dto/positionMap.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class MapScreen extends StatefulWidget {
  final ResponseAttorney login;
  final List<Map<String, String>> locations;

  MapScreen({required this.locations, required this.login});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  List<LatLng> _locationPoints = [];
  final usuarioProvider = CoordinatorProviders();

  Future<void> _loadTripulations(String tourCode) async {
    try {
      // Llamar al método del proveedor para obtener los datos
      final List<PositionMap> positionMaps =
          await usuarioProvider.positionMap(tourCode);

      // Convertir PositionMap a LatLng
      setState(() {
        _locationPoints = positionMaps.map((position) {
          return LatLng(position.latitud, position.longitud);
        }).toList();
      });
    } catch (e) {
      print('Error al cargar las posiciones del mapa: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTripulations(widget.login.tourId.toString());
    _initializeLocation();
    _loadMarkersAndPolyline();
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

  void _loadMarkersAndPolyline() {
    // Convierte las coordenadas del arreglo en una lista de LatLng
    _locationPoints = widget.locations
        .map((location) => LatLng(double.parse(location["latitud"]!),
            double.parse(location["longitud"]!)))
        .toList();
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
          // Capa del mapa base
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          // Capa para mostrar la ubicación actual
          if (_currentPosition != null)
            LocationMarkerLayer(
              position: LocationMarkerPosition(
                latitude: _currentPosition!.latitude,
                longitude: _currentPosition!.longitude,
                accuracy: 50.0, // Puedes ajustar el valor según tus necesidades
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
          // Capa de marcadores
          MarkerLayer(
            markers: _locationPoints.map((point) {
              return Marker(
                point: point,
                width: 50,
                height: 50,
                child: Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 30,
                ),
              );
            }).toList(),
          ),
          // Capa de polilínea
          if (_locationPoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _locationPoints,
                  strokeWidth: 4.0,
                  color: Colors.blue,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
