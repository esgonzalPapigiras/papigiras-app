import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';

class MapScreen extends StatefulWidget {
  final ResponseAttorney login;
  MapScreen({required this.login});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  Location _location = Location();
  Set<Marker> _markers = {};
  List<LatLng> _polylineCoordinates = [];
  Set<Polyline> _polylines = {};

  // Para almacenar la ubicación actual
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();

    // Verificar permisos y escuchar la ubicación en tiempo real
    _location.requestPermission().then((permissionStatus) {
      if (permissionStatus == PermissionStatus.granted) {
        // Escuchar la ubicación en tiempo real
        _location.onLocationChanged.listen((LocationData currentLocation) {
          setState(() {
            _currentLocation = LatLng(
              currentLocation.latitude ?? 0.0,
              currentLocation.longitude ?? 0.0,
            );
          });

          // Mover el mapa a la ubicación en tiempo real
          if (_currentLocation != null) {
            mapController
                ?.animateCamera(CameraUpdate.newLatLng(_currentLocation!));

            // Actualizar el marcador de la ubicación
            _updateMarker(_currentLocation!);
          }
        });
      } else {
        // Manejo de error si no se tienen permisos
        print("Permiso de ubicación no concedido");
      }
    });
  }

  void _updateMarker(LatLng location) {
    final markerId = MarkerId('current_location_marker');
    _markers.add(
      Marker(
        markerId: markerId,
        position: location,
        infoWindow: InfoWindow(title: 'Ubicación Actual'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(0.0, 0.0), // Establecer una ubicación inicial
          zoom: 15.0,
        ),
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        onTap: _onMapTapped, // Agregar marcador en el mapa
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }

  // Función para agregar un marcador y una línea entre ellos
  void _onMapTapped(LatLng tappedPoint) {
    setState(() {
      final markerId = MarkerId('marker_${_markers.length}');
      _markers.add(
        Marker(
          markerId: markerId,
          position: tappedPoint,
          infoWindow: InfoWindow(title: 'Marcador ${_markers.length + 1}'),
        ),
      );
      _polylineCoordinates.add(tappedPoint);
      if (_polylineCoordinates.length > 1) {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('polyline_1'),
            points: _polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ),
        );
      }
    });
  }
}
