import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/maps/live_bus_motion.dart';
import 'package:papigiras_app/maps/trip_bus_controller.dart';

void main() {
  testWidgets(
    'moves between fixes, stops at the fix, snaps on OFF and on a sender change',
    (tester) async {
      late LatLng drawn;
      Future<void> show(
        double lon,
        int sec, {
        bool recent = true,
        int sender = 1,
        bool reduce = false,
      }) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: LiveBusMotion(
              recent: recent,
              position: TripBusPosition(
                coordinatorId: sender,
                coordinate: LatLng(0, lon),
                recordedAt: DateTime.utc(2026).add(Duration(seconds: sec)),
              ),
              builder: (point) {
                drawn = point;
                return const SizedBox();
              },
            ),
          ),
        );
      }

      await show(0, 0);
      await show(.001, 5);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(drawn.longitude, closeTo(.0005, .00001));
      await show(.0015, 8);
      expect(drawn.longitude, closeTo(.0005, .00001));
      await tester.pump(const Duration(seconds: 5));
      expect(drawn.longitude, .0015);
      await show(.002, 12);
      await show(.002, 12, recent: false);
      expect(drawn.longitude, .002);
      await show(.003, 16, sender: 2);
      expect(drawn.longitude, .003);
      await show(.004, 20, sender: 2, reduce: true);
      expect(drawn.longitude, .004);
      await show(.005, 80, sender: 2);
      expect(drawn.longitude, .005);
    },
  );
}
