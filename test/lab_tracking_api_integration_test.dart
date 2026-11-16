import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/location_callback.dart';

void main() {
  const enabled = bool.fromEnvironment('LAB_API_INTEGRATION');
  test(
    'synthetic coordinator position persists through the original local API',
    () async {
      expect(LabMode.fixturesForTests, isFalse);
      final provider = CoordinatorProviders();
      addTearDown(provider.dispose);
      final login = await provider.loginCoordinator(
        '990000018',
        'PapigirasLAB-2026!',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', login.token);
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      );
      await prefs.setString('userRole', 'coordinator');
      final tours = await provider.getCoordinatorTours();
      await prefs.setInt('selectedTourId', tours.first.tourId);
      await sendCoordinatorLocation(latitude: -33.4408, longitude: -70.6460);
      expect(prefs.getStringList(pendingLocationsKey), isEmpty);
      final positions = await provider.uniqueID(tours.first.tourId.toString());
      final saved = positions.firstWhere(
        (p) => p.coordinatorId == login.coordinatorId,
      );
      expect(saved.latitude, closeTo(-33.4408, .000001));
      expect(saved.longitude, closeTo(-70.6460, .000001));
    },
    skip: !enabled,
  );
}
