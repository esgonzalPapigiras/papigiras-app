import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/tour_map_style.dart';

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
      return Container(
        height: 250,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PapigirasColors.soft,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const CircularProgressIndicator(),
      );
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
            color: PapigirasColors.teal,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 20),
        ),
      );
    }).toList();
    if (points.isEmpty) {
      return _buildEmptyState();
    }
    final center = points.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 250,
        decoration: const BoxDecoration(color: PapigirasColors.soft),
        child: FlutterMap(
          options: MapOptions(
              initialCenter: center,
              initialZoom: 13.0,
              onTap: (_, __) => _popupController.hideAllPopups()),
          children: [
            ...buildTourMapTileLayers(_mapStyle),
            if (points.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 4.0,
                    color: PapigirasColors.teal,
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
                    final dto = entries[idx].key;
                    return Card(
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dto.binnacleTitulo,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(dto.binnacleDescripcion),
                            const SizedBox(height: 6),
                            Text(
                              dto.binnacleFecha,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 38,
                color: PapigirasColors.teal,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Aún no hay hitos con ubicación',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (_errorMessage != null)
                TextButton(
                  onPressed: _loadBinnacle,
                  child: const Text('Reintentar'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
