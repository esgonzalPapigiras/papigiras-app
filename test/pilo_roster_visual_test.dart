import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/coordinator/listPassenger.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';

import 'passenger_roster_data_test.dart' show person;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Manjari',
    )..addFont(rootBundle.load('assets/fonts/Manjari-Regular.ttf'))).load();
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
        .load();
  });

  testWidgets('nómina Pilo con fuentes reales y fixtures; sin red ni PII', (
    tester,
  ) async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    SharedPreferences.setMockInitialValues({});
    LabFixtures.reset();
    final location = LocationService();
    addTearDown(() {
      location.dispose();
      LabMode.useFixturesForTests(false);
      HttpOverrides.global = previous;
      LabFixtures.reset();
    });
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: location,
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: papiTheme(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 48, bottom: 28)),
              child: child!,
            ),
            home: ListPassengerCoordScreen(
              login: TourSales.fromCoordinatorTour(
                coordinator: LabFixtures.coordinator,
                tour: LabFixtures.tour,
              ),
              photoLoader: (_, _) async => null,
              passengerLoader: (_) async => [
                person(
                  910011,
                  'F',
                  name: 'ANTONIA EJEMPLO',
                  medical: 'Lleno',
                  diet: 'Vegetariana',
                  rut: 'LAB-910011',
                ),
                person(
                  910012,
                  'AF',
                  name: 'CAMILA DEMO',
                  medical: '',
                  diet: 'Sin gluten',
                  rut: 'LAB-910012',
                ),
                person(
                  910013,
                  'M',
                  name: 'TOMÁS EJEMPLO',
                  medical: 'Lleno',
                  diet: 'Tradicional',
                  rut: 'LAB-910013',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Acompañante'), findsOneWidget);
    if (const bool.fromEnvironment('PILO_ROSTER_CAPTURE')) {
      await tester.runAsync(() async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/private/tmp/pilo-roster-fixture.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
