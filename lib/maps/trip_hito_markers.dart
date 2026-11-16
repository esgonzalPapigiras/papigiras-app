import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';

const tripMapMaxZoom = 19.0;
const _piloUngroupedWidthMeters = 55000.0;

double _piloMapWidthMeters(MapCamera camera, LatLng tripReference) {
  // The Pilo map uses Web Mercator. Its world width in pixels corresponds
  // to the circumference at a fixed trip latitude so a pan cannot change mode.
  return camera.nonRotatedSize.x *
      (2 * math.pi * equatorRadius * math.cos(tripReference.latitudeInRad)) /
      camera.crs.scale(camera.zoom);
}

/// Center the group on its projected geographic extent, independently of
/// which hito was published last.
LatLng tripHitoClusterCenter(MapCamera camera, Iterable<TripMapEntry> entries) {
  final extent = Bounds.containing(
    entries.map((entry) => camera.project(entry.position!)),
  );
  return camera.unproject(extent.center);
}

/// Individual markers and groups use the current map projection.
class TripHitoMarkers extends StatelessWidget {
  const TripHitoMarkers({
    super.key,
    required this.controller,
    required this.onSelectGroup,
    this.pilo = false,
    this.onSelectHito,
  });

  final TripMapController controller;
  final bool pilo;
  final ValueChanged<int>? onSelectHito;
  final ValueChanged<List<TripMapEntry>> onSelectGroup;

  static const _separation = 62.0;
  static const _targetSize = 52.0;
  static const _piloTargetSize = 48.0;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final data = controller.data;
      if (data == null) return const MarkerLayer(markers: []);
      final camera = MapCamera.of(context);
      if (pilo) return _piloLayer(camera, data);
      final projected = <int, math.Point<double>>{
        for (final entry in data.mappedEntries)
          entry.id: camera.latLngToScreenPoint(entry.position!),
      };
      final latest = data.latestId == null
          ? null
          : data.entryById(data.latestId!);
      final latestPixel = latest?.hasLocation == true
          ? projected[latest!.id]
          : null;
      final showLatest =
          latestPixel != null &&
          latestPixel.x.isFinite &&
          latestPixel.y.isFinite;
      final historical = groupTripMapEntries(
        data.mappedEntries.where((entry) => entry.id != data.latestId),
        projected,
        minSeparation: _separation,
      );
      final markers = <Marker>[];
      for (final group in historical) {
        final anchor = group.anchor;
        final pixel = projected[anchor.id]!;
        final nearLatest =
            showLatest &&
            math.pow(pixel.x - latestPixel.x, 2) +
                    math.pow(pixel.y - latestPixel.y, 2) <
                _separation * _separation;
        final selected = group.entries.any(
          (entry) => entry.id == controller.selectedId,
        );
        final target = group.isCluster
            ? _groupTarget(group, selected: selected)
            : _pinTarget(anchor, latest: false, selected: selected);
        if (nearLatest) {
          // Only the callout moves, never the geographic position. Placing its
          // actual touch target below the yellow pin prevents overlapping
          // events from blocking each other, even at identical coordinates.
          final gap = math.max(8.0, latestPixel.y - pixel.y + 8.0);
          markers.add(
            Marker(
              point: group.position,
              width: _targetSize,
              height: gap + _targetSize,
              alignment: Alignment.bottomCenter,
              child: Column(
                children: [
                  IgnorePointer(
                    child: ExcludeSemantics(
                      child: SizedBox(
                        height: gap,
                        child: Center(
                          child: ColoredBox(
                            color: tripMuted.withValues(alpha: .45),
                            child: SizedBox(width: 1.5, height: gap),
                          ),
                        ),
                      ),
                    ),
                  ),
                  target,
                ],
              ),
            ),
          );
        } else {
          markers.add(
            Marker(
              point: group.position,
              width: _targetSize,
              height: _targetSize,
              alignment: group.isCluster
                  ? Alignment.center
                  : Alignment.topCenter,
              child: target,
            ),
          );
        }
      }
      if (showLatest) {
        // Paint last so the latest pin remains visible over map decorations.
        // It stays yellow when any other event is selected.
        markers.add(
          Marker(
            point: latest!.position!,
            width: _targetSize,
            height: _targetSize,
            alignment: Alignment.topCenter,
            child: _pinTarget(
              latest,
              latest: true,
              selected: latest.id == controller.selectedId,
            ),
          ),
        );
      }
      return MarkerLayer(markers: markers);
    },
  );

  MarkerLayer _piloLayer(MapCamera camera, TripMapData data) {
    final entries = data.mappedEntries;
    if (entries.isEmpty) return const MarkerLayer(markers: []);
    final selectedId = controller.selectionRevision > 0
        ? controller.selectedId
        : null;
    final widthMeters = _piloMapWidthMeters(camera, entries.first.position!);
    final individual =
        widthMeters > 0 && widthMeters <= _piloUngroupedWidthMeters;
    final displayPoints = individual
        ? _piloDisplayPoints(entries)
        : const <int, LatLng>{};
    final groups = individual
        ? entries.map((entry) => TripMapCluster([entry]))
        : _piloClusters(camera, entries);
    final markers = <Marker>[];
    Marker? selectedMarker;

    for (final group in groups) {
      final anchor = group.anchor;
      final selected = group.entries.any((entry) => entry.id == selectedId);
      final marker = Marker(
        key: ValueKey(
          group.isCluster
              ? 'pilo-group-${anchor.id}'
              : 'pilo-hito-${anchor.id}',
        ),
        point: group.isCluster
            ? tripHitoClusterCenter(camera, group.entries)
            : displayPoints[anchor.id] ?? group.position,
        width: _piloTargetSize,
        height: _piloTargetSize,
        alignment: group.isCluster ? Alignment.center : Alignment.topCenter,
        child: group.isCluster
            ? _groupTarget(group, selected: selected)
            : _pinTarget(
                anchor,
                latest: anchor.id == data.latestId,
                selected: selected,
              ),
      );
      if (selected) {
        selectedMarker = marker;
      } else {
        markers.add(marker);
      }
    }
    if (selectedMarker != null) markers.add(selectedMarker);
    return MarkerLayer(markers: markers);
  }

  static List<TripMapCluster> _piloClusters(
    MapCamera camera,
    List<TripMapEntry> entries,
  ) {
    // World pixels keep regional grouping stable when the map is dragged.
    const horizontalSeparation = 78.0;
    const verticalSeparation = 27.0;
    final projected = <int, math.Point<double>>{};
    for (final entry in entries) {
      final point = camera.project(entry.position!);
      projected[entry.id] = math.Point(
        point.x / horizontalSeparation,
        point.y / verticalSeparation,
      );
    }
    return groupTripMapEntries(entries, projected, minSeparation: 1);
  }

  // Only exact GPS duplicates need separate geographic anchors. The display
  // points are deterministic for this trip and stay within 8 m of the source.
  // The saved positions themselves are still used for counts and navigation.
  static Map<int, LatLng> _piloDisplayPoints(List<TripMapEntry> entries) {
    final byPosition = <LatLng, List<int>>{};
    for (final entry in entries) {
      byPosition.putIfAbsent(entry.position!, () => []).add(entry.id);
    }

    const distance = Distance(calculator: Haversine());
    final shifted = <int, LatLng>{};
    for (final item in byPosition.entries) {
      final ids = item.value;
      if (ids.length < 2) continue;
      ids.sort();
      for (var i = 1; i < ids.length; i++) {
        final bearing = (i * 137.507764 + 180) % 360 - 180;
        final radius = 8 * math.sqrt(i / (ids.length - 1));
        final point = distance.offset(item.key, radius, bearing);
        shifted[ids[i]] = LatLng(
          point.latitude,
          (point.longitude + 180) % 360 - 180,
        );
      }
    }
    return shifted;
  }

  Widget _pinTarget(
    TripMapEntry entry, {
    required bool latest,
    required bool selected,
  }) => Semantics(
    button: true,
    selected: selected,
    label:
        'Hito: ${entry.source.binnacleTitulo}.'
        '${pilo ? '' : ' ${tripMoment(entry)}.'}'
        '${latest ? ' El más reciente.' : ''}',
    child: GestureDetector(
      key: ValueKey('trip-pin-${entry.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => (pilo
          ? onSelectHito ?? controller.select
          : controller.select)(entry.id),
      child: SizedBox.square(
        dimension: pilo ? _piloTargetSize : _targetSize,
        child: ExcludeSemantics(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (selected && !pilo)
                Icon(
                  Icons.location_on,
                  size: 52,
                  color: tripInk.withValues(alpha: .23),
                ),
              if (!pilo)
                const Icon(
                  Icons.location_on,
                  size: 48,
                  color: tripSurface,
                  shadows: [
                    Shadow(
                      color: Color(0x3017332F),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              Icon(
                key: ValueKey('trip-marker-fill-${entry.id}'),
                Icons.location_on,
                size: pilo ? 36 : 44,
                color: pilo
                    ? (selected ? PiloFamilyTheme.ink : PiloFamilyTheme.mint)
                    : (latest ? tripYellow : tripMint),
                shadows: pilo
                    ? const [
                        Shadow(
                          color: Color(0x3017332F),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _groupTarget(
    TripMapCluster group, {
    required bool selected,
  }) => Semantics(
    button: true,
    selected: selected,
    label:
        '${group.count} hitos en esta zona. Toca para ${pilo ? 'acercar' : 'elegir'}.',
    child: GestureDetector(
      key: ValueKey('trip-cluster-${group.anchor.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelectGroup(group.entries),
      child: SizedBox.square(
        dimension: pilo ? _piloTargetSize : _targetSize,
        child: Center(
          child: Container(
            key: ValueKey('trip-marker-fill-${group.anchor.id}'),
            width: pilo ? _piloTargetSize : 44,
            height: pilo ? 34 : 44,
            decoration: BoxDecoration(
              color: pilo
                  ? (selected ? PiloFamilyTheme.ink : PiloFamilyTheme.paper)
                  : tripMint,
              borderRadius: BorderRadius.circular(pilo ? 17 : 22),
              border: pilo
                  ? Border.all(
                      color: selected
                          ? PiloFamilyTheme.ink
                          : PiloFamilyTheme.hairline,
                    )
                  : Border.all(color: tripSurface, width: 2),
              boxShadow: [
                if (selected)
                  const BoxShadow(color: Color(0x3017332F), spreadRadius: 3),
                const BoxShadow(
                  color: Color(0x25183B35),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${group.count}',
                      style: TextStyle(
                        color: pilo
                            ? (selected
                                  ? PiloFamilyTheme.paper
                                  : PiloFamilyTheme.ink)
                            : tripInk,
                        fontFamily: pilo ? 'Inter' : null,
                        fontSize: pilo ? 13 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
