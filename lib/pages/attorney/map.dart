import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
// Para manejar permisos

class MapScreen extends StatefulWidget {
  final ResponseAttorney login;
  MapScreen({required this.login});
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Map Example'),
      ),
      body: FlutterMap(
        options: MapOptions(
          center:
              LatLng(51.509865, -0.118092), // Coordenadas del centro del mapa
          zoom: 13.0, // Nivel de zoom
        ),
        layers: [
          TileLayerOptions(
            urlTemplate:
                "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", // Mapa de OpenStreetMap
            subdomains: ['a', 'b', 'c'], // Subdominios
          ),
          MarkerLayerOptions(
            markers: [
              Marker(
                point: LatLng(51.509865, -0.118092), // Ubicación del marcador
                builder: (ctx) => Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Función para solicitar permisos de ubicación
  Future<void> requestLocationPermission() async {
    permisos.PermissionStatus status =
        await permisos.Permission.location.request();
    if (status.isGranted) {
      print('Permiso de ubicación concedido');
    } else {
      print('Permiso de ubicación denegado');
    }
  }*/
}
