import 'package:papigiras_app/pages/attorney/loginFather.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'support/map_tiles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/main.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/attorney/documentsfather.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/attorney/tripulationbusfather.dart';
import 'package:papigiras_app/pages/attorney/viewmedicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/activities.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';

void main() {
  setUp(() => LabMode.useFixturesForTests(true));
  tearDown(() => LabMode.useFixturesForTests(false));
  setUp(() async {
    LabMapTiles.testProvider = TestMapTileProvider.new;
    LabFixtures.reset();
    await (await SharedPreferences.getInstance()).clear();
  });
  testWidgets(
    'original apoderado form and medical onboarding work with fictional credentials',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(PapigirasLab(startScreen: LoginFather()));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).first, '99.000.011-5');
      await tester.enterText(find.byType(TextField).last, '990000');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pilo-password-reminder')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('pilo-password-reminder-continue')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bienvenidos a bordo'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Estudiante Demo'), findsOneWidget);
      expect(find.text('LAB · COPIA RECUPERADA · 03/11/2026'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Pilo medical sheet closes over Home and protects edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      PapigirasLab(
        startScreen: TravelFatherDashboard(login: LabFixtures.passenger),
      ),
    );
    await tester.pumpAndSettle();
    final homeAction = find.byKey(const ValueKey('family-medical'));
    final header = find.byKey(const ValueKey('medical-sheet-header'));
    final close = find.byTooltip('Cerrar ficha médica');

    Future<void> open() async {
      await tester.ensureVisible(homeAction);
      await tester.tap(homeAction);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('family-medical-preview')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('family-medical-preview-open')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(homeAction, findsOneWidget);
      expect(close.hitTestable(), findsOneWidget);
    }

    Future<void> dragHeader() async {
      await tester.dragFrom(
        tester.getTopLeft(header) + const Offset(100, 18),
        const Offset(0, 124),
      );
      await tester.pumpAndSettle();
    }

    await open();
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(homeAction.hitTestable(), findsOneWidget);

    await open();
    await dragHeader();
    expect(find.byType(BottomSheet), findsNothing);

    await open();
    final edit = find.byKey(const ValueKey('medical-edit'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    final field = find.byType(TextFormField).first;
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Contacto de prueba');
    tester.view.viewInsets = const FakeViewPadding(bottom: 305);
    await tester.pumpAndSettle();
    expect(close.hitTestable(), findsOneWidget);
    expect(find.text('Contacto de prueba').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    await dragHeader();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Contacto de prueba'), findsOneWidget);

    await tester.tap(close);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(homeAction.hitTestable(), findsOneWidget);
    await open();
    expect(find.text('Contacto de prueba'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  tearDown(() {
    LabMapTiles.testProvider = null;
  });
  final t = TourSales.fromCoordinatorTour(
    coordinator: LabFixtures.coordinator,
    tour: LabFixtures.tour,
  );
  final screens = <String, Widget Function()>{
    'bitacora': () => BitacoraFatherScreen(login: LabFixtures.passenger),
    'documentos': () => DocumentFatherScreen(login: LabFixtures.passenger),
    'tripulacion': () => BusCrewFatherScreen(login: LabFixtures.passenger),
    'ficha': () => ViewMedicalRecordScreen(login: LabFixtures.passenger),
    'coordinador': () => TravelCoordinatorDashboard(login: t),
    'actividades': () => ActivitiesCoordScreen(login: t),
    'nuevo hito': () => HitoAddCoordScreen(login: t),
    'fichas coordinador': () => MedicalCoordScreen(login: t),
    'documentos coordinador': () => DocumentCoordScreen(login: t),
    'contador': () => CountDownCoordScreen(login: t),
    'alumno': () => TravelPassengerDashboard(login: LabFixtures.passenger),
  };
  for (final entry in screens.entries) {
    testWidgets(
      '${entry.key}: original screen accepts LAB fixtures at phone size',
      (tester) async {
        tester.view.physicalSize = const Size(393, 814);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => LocationService(),
            child: MaterialApp(home: entry.value()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
