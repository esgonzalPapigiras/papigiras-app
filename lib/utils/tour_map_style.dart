import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

enum TourMapStyle { streets, satellite, terrain }

final ValueNotifier<TourMapStyle> tourMapStyleNotifier =
    ValueNotifier(TourMapStyle.streets);

extension TourMapStyleDetails on TourMapStyle {
  String get label {
    switch (this) {
      case TourMapStyle.streets:
        return 'Calles';
      case TourMapStyle.satellite:
        return 'Satélite';
      case TourMapStyle.terrain:
        return 'Terreno';
    }
  }

  IconData get icon {
    switch (this) {
      case TourMapStyle.streets:
        return Icons.map_outlined;
      case TourMapStyle.satellite:
        return Icons.satellite_alt_outlined;
      case TourMapStyle.terrain:
        return Icons.terrain_outlined;
    }
  }

  String get attribution {
    switch (this) {
      case TourMapStyle.streets:
        return '© OpenStreetMap contributors';
      case TourMapStyle.satellite:
        return 'Tiles © Esri';
      case TourMapStyle.terrain:
        return '© OpenStreetMap contributors · SRTM';
    }
  }
}

List<Widget> buildTourMapTileLayers(TourMapStyle style) {
  switch (style) {
    case TourMapStyle.streets:
      return [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.papigiras',
        ),
      ];
    case TourMapStyle.satellite:
      return [
        TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.papigiras',
        ),
        TileLayer(
          urlTemplate:
              'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.papigiras',
        ),
      ];
    case TourMapStyle.terrain:
      return [
        TileLayer(
          urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.papigiras',
        ),
      ];
  }
}

class TourMapStyleControl extends StatelessWidget {
  final TourMapStyle value;
  final ValueChanged<TourMapStyle> onChanged;

  const TourMapStyleControl({
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: PopupMenuButton<TourMapStyle>(
          tooltip: 'Cambiar vista del mapa',
          initialValue: value,
          onSelected: onChanged,
          icon: Icon(value.icon),
          itemBuilder: (context) => TourMapStyle.values
              .map(
                (style) => PopupMenuItem(
                  value: style,
                  child: Row(
                    children: [
                      Icon(style.icon, size: 20),
                      const SizedBox(width: 10),
                      Text(style.label),
                      if (style == value) ...[
                        const Spacer(),
                        const Icon(Icons.check, size: 18),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class TourMapAttribution extends StatelessWidget {
  final TourMapStyle style;

  const TourMapAttribution({required this.style, super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 4,
      bottom: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(style.attribution, style: const TextStyle(fontSize: 9)),
        ),
      ),
    );
  }
}
