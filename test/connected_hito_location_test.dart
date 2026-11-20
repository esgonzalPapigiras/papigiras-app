import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/maps/hito_location_source.dart';
import 'package:papigiras_app/runtime/api_destination.dart';
import 'support/map_tiles.dart';

void main() {
  group(
    'connected hito location',
    () {
      test('uses the device coordinate without a fictional address', () async {
        final location = await HitoLocationSource.current(
          readDevice: () async => const LatLng(-36.8, -73),
        );
        expect(location.point, const LatLng(-36.8, -73));
        expect(location.label, 'Ubicación actual');
      });
      test(
        'permission or sensor failure never falls back to a synthetic point',
        () async {
          await expectLater(
            HitoLocationSource.current(
              readDevice: () async {
                throw StateError('Permission denied');
              },
            ),
            throwsStateError,
          );
        },
      );
      test(
        'unmappable sensor coordinates cannot become a publishable draft',
        () async {
          await expectLater(
            HitoLocationSource.current(
              readDevice: () async => const LatLng(86, 0),
            ),
            throwsArgumentError,
          );
        },
      );

      testWidgets(
        'denied GPS keeps publishing disabled until an explicit map point is confirmed',
        (tester) async {
          const channel = MethodChannel('flutter.baseflow.com/geolocator');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (_) async => false,
          );
          final previousTiles = LabMapTiles.testProvider;
          LabMapTiles.testProvider = TestMapTileProvider.new;
          tester.view.physicalSize = const Size(402, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel,
              null,
            );
            LabMapTiles.testProvider = previousTiles;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          await tester.pumpWidget(
            MaterialApp(
              home: HitoAddCoordScreen(
                login: TourSales.fromCoordinatorTour(
                  coordinator: LabFixtures.coordinator,
                  tour: LabFixtures.tour,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final publish = find.byKey(const ValueKey('hito-add-publish'));
          expect(tester.widget<FilledButton>(publish).onPressed, isNull);
          final adjust = find.byKey(const ValueKey('hito-adjust-location'));
          await tester.ensureVisible(adjust);
          await tester.tap(adjust);
          await tester.pumpAndSettle();
          final confirm = find.byKey(const ValueKey('hito-location-confirm'));
          await tester.ensureVisible(confirm);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(tester.widget<FilledButton>(publish).onPressed, isNotNull);
          expect(find.text('Punto seleccionado en el mapa'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    },
    skip: !AppEnvironment.connected
        ? 'Requires connected-mode build configuration'
        : false,
  );
}
