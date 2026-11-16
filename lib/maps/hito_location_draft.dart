import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A location chosen for this hito only. It never changes the shared bus/GPS
/// source and does not claim that a map coordinate has a geocoded address.
@immutable
class HitoLocationDraft {
  factory HitoLocationDraft({required LatLng point, required String label}) {
    if (!isValidPoint(point)) {
      throw ArgumentError.value(point, 'point', 'Ubicación fuera del mapa');
    }
    return HitoLocationDraft._(point, label);
  }

  const HitoLocationDraft._(this.point, this.label);

  factory HitoLocationDraft.selectedPoint(LatLng point) =>
      HitoLocationDraft(point: point, label: 'Punto seleccionado en el mapa');

  static const maximumLatitude = 85.0511;

  static bool isValidPoint(LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude.abs() <= maximumLatitude &&
      point.longitude.abs() <= 180;

  final LatLng point;
  final String label;
}
