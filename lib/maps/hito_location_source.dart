import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../lab/synthetic_location.dart';
import '../runtime/api_destination.dart';
import 'hito_location_draft.dart';

/// One-shot location for composing a hito. This does not enable bus sharing or
/// request background permission. A failed device read never uses a LAB point.
abstract final class HitoLocationSource {
  // An empty picker's viewport, not a detected position. It can only be saved
  // after the coordinator explicitly selects/confirms a point on the map.
  static LatLng get initialMapCenter => AppEnvironment.connected
      ? const LatLng(-33.4489, -70.6693)
      : LabSyntheticLocation.instance.current.latLng;

  static Future<HitoLocationDraft> current({
    Future<LatLng> Function()? readDevice,
  }) async {
    if (!AppEnvironment.connected) {
      final source = LabSyntheticLocation.instance;
      await source.restore();
      return HitoLocationDraft(
        point: source.current.latLng,
        label: source.current.address,
      );
    }
    final point = await (readDevice ?? _readDevice)();
    return HitoLocationDraft(point: point, label: 'Ubicación actual');
  }

  static Future<LatLng> _readDevice() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Activa la ubicación o selecciona un punto en el mapa.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'Permite usar tu ubicación o selecciona un punto en el mapa.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }
}
