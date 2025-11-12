import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class TraceMapFullScreen extends StatefulWidget {
  final int tourCode;
  const TraceMapFullScreen({required this.tourCode, super.key});

  @override
  _TraceMapFullScreenState createState() => _TraceMapFullScreenState();
}

class _TraceMapFullScreenState extends State<TraceMapFullScreen> {
  final PopupController _popupController = PopupController();
  List<ConsolidatedTourSalesDTO> _binnacleData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBinnacle();
  }

  Future<void> _loadBinnacle() async {
    try {
      final service = CoordinatorProviders();
      final data = await service.getBinnacle(widget.tourCode.toString());
      setState(() {
        _binnacleData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error cargando puntos: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final points = _binnacleData
        .map((e) => LatLng(
              double.parse(e.binnacleLatitud),
              double.parse(e.binnacleLongitud),
            ))
        .toList();

    final markers = _binnacleData.asMap().entries.map((entry) {
      final idx = entry.key;
      final dto = entry.value;
      final pt = points[idx];

      return Marker(
        point: pt,
        width: 30.0,
        height: 30.0,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
      );
    }).toList();

    final center = points.isNotEmpty ? points.first : LatLng(-33.45, -70.66);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text(
          'Mapa del Recorrido',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13.0,
          onTap: (_, __) => _popupController.hideAllPopups(),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          if (points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 4.0,
                  color: Colors.blue,
                ),
              ],
            ),
          MarkerLayer(markers: markers),
          PopupMarkerLayer(
            options: PopupMarkerLayerOptions(
              markers: markers,
              popupController: _popupController,
              markerTapBehavior: MarkerTapBehavior.togglePopup(),
              popupDisplayOptions: PopupDisplayOptions(
                builder: (BuildContext context, Marker marker) {
                  final idx = markers.indexOf(marker);
                  final dto = _binnacleData[idx];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(dto.binnacleTitulo,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(dto.binnacleDescripcion),
                          Text(dto.binnacleFecha),
                        ],
                      ),
                    ),
                  );
                },
                snap: PopupSnap.markerTop,
              ),
            ),
          ),
          CurrentLocationLayer(),
        ],
      ),
    );
  }
}
