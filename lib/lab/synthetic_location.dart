import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'preferences.dart';

class LabRoutePoint {
  final double latitude;
  final double longitude;
  final String address;
  const LabRoutePoint(this.latitude, this.longitude, this.address);
  LatLng get latLng => LatLng(latitude, longitude);
}

/// A controllable fictional route. It never reads the device's position or sensors.
class LabSyntheticLocation extends ChangeNotifier {
  static final instance = LabSyntheticLocation();
  static const route = <LabRoutePoint>[
    LabRoutePoint(-33.4460, -70.6530, 'Parada ficticia 1 · Santiago LAB'),
    LabRoutePoint(-33.4440, -70.6510, 'Parada ficticia 2 · Parque LAB'),
    LabRoutePoint(-33.4422, -70.6487, 'Parada ficticia 3 · Museo LAB'),
    LabRoutePoint(-33.4408, -70.6460, 'Parada ficticia 4 · Mirador LAB'),
    LabRoutePoint(-33.4433, -70.6435, 'Parada ficticia 5 · Colegio LAB'),
    LabRoutePoint(-33.4461, -70.6464, 'Parada ficticia 6 · Hotel LAB'),
  ];
  int _index = 0;
  bool _paused = false;
  bool _restored = false;
  int get index => _index;
  bool get paused => _paused;
  LabRoutePoint get current => route[_index];

  Future<void> restore() async {
    if (_restored) return;
    final prefs = await SharedPreferences.getInstance();
    _index = (prefs.getInt('labSyntheticRouteIndex') ?? 0) % route.length;
    _paused = prefs.getBool('labSyntheticRoutePaused') ?? false;
    _restored = true;
    notifyListeners();
  }

  Future<void> select(int index, {bool Function()? shouldApply}) async {
    await restore();
    if (shouldApply != null && !shouldApply()) return;
    _index = index % route.length;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('labSyntheticRouteIndex', _index);
    notifyListeners();
  }

  Future<void> advance({bool Function()? shouldAdvance}) async {
    await restore();
    if (shouldAdvance != null && !shouldAdvance()) return;
    if (!_paused) await select(_index + 1, shouldApply: shouldAdvance);
  }

  Future<void> setPaused(bool paused) async {
    await restore();
    _paused = paused;
    await (await SharedPreferences.getInstance()).setBool(
      'labSyntheticRoutePaused',
      paused,
    );
    notifyListeners();
  }

  @visibleForTesting
  void resetForTests() {
    _index = 0;
    _paused = false;
    _restored = false;
  }
}
