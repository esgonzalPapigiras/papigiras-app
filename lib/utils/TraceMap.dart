import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/dto/binnacle.dart';

import 'package:papigiras_app/provider/coordinatorProvider.dart';

class TraceMap extends StatefulWidget {
  final int tourCode;
  const TraceMap({required this.tourCode, super.key});

  @override
  _TraceMapState createState() => _TraceMapState();
}

class _TraceMapState extends State<TraceMap> {
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
      return Container(
        height: 250,
        alignment: Alignment.center,
        child: CircularProgressIndicator(),
      );
    }

    // 1) Genera tu lista de LatLng
    final points = _binnacleData
        .map((e) => LatLng(
              double.parse(e.binnacleLatitud),
              double.parse(e.binnacleLongitud),
            ))
        .toList();

// 2) Mapea DTOs → Marker usando `child:`
    final markers = _binnacleData.asMap().entries.map((entry) {
      final idx = entry.key;
      final dto = entry.value;
      final pt = points[idx];

      return Marker(
        point: pt,
        width: 30.0,
        height: 30.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
        // opcional: si quieres ajustar el "ancla" del icono,
        // puedes usar algo como `anchor: Anchor(0.5, 0.5)`
      );
    }).toList();

    // Centro inicial
    final center = points.isNotEmpty ? points.first : LatLng(-33.45, -70.66);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 250,
        margin: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.0,
            // al tap fuera de cualquier marker ocultamos el popup
            onTap: (_, __) => _popupController.hideAllPopups(),
          ),
          children: [
            // ─── Mosaico base ──────────────────────
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: ['a', 'b', 'c'],
            ),

            // ─── Traza azul ────────────────────────
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

            // ─── Marcadores (círculos azules) ─────
            MarkerLayer(markers: markers),

            // ─── Popups ────────────────────────────
            PopupMarkerLayer(
              options: PopupMarkerLayerOptions(
                markers: markers,
                popupController: _popupController,
                markerTapBehavior: MarkerTapBehavior.togglePopup(),
                popupDisplayOptions: PopupDisplayOptions(
                  // Aquí construyes el popup, no el marker
                  builder: (BuildContext context, Marker marker) {
                    final idx = markers.indexOf(marker);
                    final dto = _binnacleData[idx];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Container(
                        width: 200,
                        padding: EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(dto.binnacleTitulo,
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text(dto.binnacleDescripcion),
                          ],
                        ),
                      ),
                    );
                  },
                  // Fuerza a que el popup aparezca justo encima del marker
                  snap: PopupSnap.markerTop,
                ),
              ),
            ),

            // ─── Ubicación en tiempo real ─────────
            CurrentLocationLayer(),
          ],
        ),
      ),
    );
  }
}
