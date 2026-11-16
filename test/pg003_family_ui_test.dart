import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'package:papigiras_app/navigation/family_navigation.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/attorney/fatherWelcome.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/attorney/binnacledetailFather.dart';
import 'package:papigiras_app/pages/attorney/documentsfather.dart';
import 'package:papigiras_app/pages/attorney/tripulationbusfather.dart';
import 'package:papigiras_app/pages/attorney/viewProgram.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'support/map_tiles.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    LabMapTiles.testProvider = TestMapTileProvider.new;
    LabFixtures.reset();
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      HttpOverrides.global = previous;
      LabMode.useFixturesForTests(false);
      LabMapTiles.testProvider = null;
      LabFixtures.reset();
    });
  });

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    double scale = 1.6,
  }) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: papiTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  final screens = <String, Widget Function()>{
    'inicio': () => TravelFatherDashboard(login: LabFixtures.passenger),
    'bienvenida': () => WelcomeFatherScreen(login: LabFixtures.passenger),
    'bitácora': () => BitacoraFatherScreen(login: LabFixtures.passenger),
    'detalle': () =>
        DetalleBitacoraFatherScreen(idHito: '1', login: LabFixtures.passenger),
    'documentos': () => DocumentFatherScreen(login: LabFixtures.passenger),
    'equipo': () => BusCrewFatherScreen(login: LabFixtures.passenger),
    'programa': () => ViewProgramScreen(login: LabFixtures.passenger),
    'pase alumno': () => TravelPassengerDashboard(login: LabFixtures.passenger),
  };
  for (final entry in screens.entries) {
    testWidgets('${entry.key}: readable family layout at320 and text1.6', (
      tester,
    ) async {
      await mount(tester, entry.value());
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'family tabs keep home and selected destination without duplicate stacks',
    (tester) async {
      await mount(
        tester,
        TravelFatherDashboard(login: LabFixtures.passenger),
        scale: 1,
      );
      await tester.tap(find.text('Bitácora'));
      await tester.pumpAndSettle();
      expect(find.byType(BitacoraFatherScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('family-tab-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('family-trip-details')));
      await tester.pumpAndSettle();
      final crew = find.byKey(const ValueKey('family-action-crew'));
      await tester.ensureVisible(crew);
      await tester.tap(crew);
      await tester.pumpAndSettle();
      expect(find.byType(BusCrewFatherScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('family-tab-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('family-trip-details')));
      await tester.pumpAndSettle();
      final documents = find.byKey(const ValueKey('family-action-documents'));
      await tester.ensureVisible(documents);
      await tester.tap(documents);
      await tester.pumpAndSettle();
      expect(find.byType(DocumentFatherScreen), findsOneWidget);
      expect(find.text('Nomina alumnos'), findsNothing);
      expect(find.text('Programa gira.pdf'), findsOneWidget);
      expect(find.text('Nómina de prueba.pdf'), findsNothing);
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.byType(TravelFatherDashboard), findsOneWidget);
      expect(find.byType(FamilyNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('student retains accessible QR and no family tabs', (
    tester,
  ) async {
    await mount(tester, TravelPassengerDashboard(login: LabFixtures.passenger));
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.backgroundColor, Colors.white);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byType(FamilyNavigationBar), findsNothing);
    await tester.tap(find.byTooltip('Abrir menú del alumno'));
    await tester.pumpAndSettle();
    expect(find.text('Contactar agencia'), findsOneWidget);
    expect(find.text('Desactivar cuenta'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
