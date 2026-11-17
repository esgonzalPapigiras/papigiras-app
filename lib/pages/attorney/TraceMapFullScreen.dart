import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/tour_map_style.dart';

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
  String? _errorMessage;
  TourMapStyle _mapStyle = tourMapStyleNotifier.value;

  @override
  void initState() {
    super.initState();
    tourMapStyleNotifier.addListener(_syncMapStyle);
    _loadBinnacle();
  }

  @override
  void dispose() {
    tourMapStyleNotifier.removeListener(_syncMapStyle);
    super.dispose();
  }

  void _syncMapStyle() {
    if (mounted && _mapStyle != tourMapStyleNotifier.value) {
      setState(() => _mapStyle = tourMapStyleNotifier.value);
    }
  }

  void _changeMapStyle(TourMapStyle style) {
    tourMapStyleNotifier.value = style;
  }

  Future<void> _loadBinnacle() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final service = CoordinatorProviders();
      final data = await service.getBinnacle(widget.tourCode.toString());
      if (!mounted) return;
      setState(() {
        _binnacleData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'No se pudieron cargar los hitos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final entries = _binnacleData
        .map((dto) {
          final latitude =
              double.tryParse(dto.binnacleLatitud.replaceAll(',', '.'));
          final longitude =
              double.tryParse(dto.binnacleLongitud.replaceAll(',', '.'));
          if (latitude == null ||
              longitude == null ||
              latitude < -90 ||
              latitude > 90 ||
              longitude < -180 ||
              longitude > 180) {
            return null;
          }
          return MapEntry(dto, LatLng(latitude, longitude));
        })
        .whereType<MapEntry<ConsolidatedTourSalesDTO, LatLng>>()
        .toList();
    final points = entries.map((entry) => entry.value).toList();
    final markers = entries.map((entry) {
      return Marker(
        point: entry.value,
        width: 34,
        height: 34,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.teal,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 20),
        ),
      );
    }).toList();
    if (points.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: _buildEmptyState(),
      );
    }
    final center = points.first;
    return Scaffold(
      appBar: _buildAppBar(context),
      body: FlutterMap(
        options: MapOptions(
            initialCenter: center,
            initialZoom: 13.0,
            onTap: (_, __) => _popupController.hideAllPopups()),
        children: [
          ...buildTourMapTileLayers(_mapStyle),
          if (points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(points: points, strokeWidth: 4.0, color: Colors.blue),
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
                  final dto = entries[idx].key;
                  return Card(
                    margin: EdgeInsets.zero,
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(dto.binnacleTitulo,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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
          TourMapStyleControl(
            value: _mapStyle,
            onChanged: _changeMapStyle,
          ),
          TourMapAttribution(style: _mapStyle),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.teal,
      title: const Text('Mapa del Recorrido',
          style: TextStyle(color: Colors.white)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _errorMessage == null
                  ? Icons.location_off_outlined
                  : Icons.error_outline,
              size: 56,
              color: Colors.teal,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Aún no hay hitos con ubicación',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage == null
                  ? 'Cuando se registre un hito con ubicación, aparecerá aquí.'
                  : 'Revisa tu conexión e inténtalo nuevamente.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadBinnacle,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
