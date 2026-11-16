import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:papigiras_app/crew/crew_avatar.dart';
import 'package:papigiras_app/crew/crew_coordinator.dart';
import 'package:papigiras_app/crew/trip_crew_controller.dart';
import 'package:papigiras_app/crew/trip_crew_view.dart';
import 'package:papigiras_app/design/apple_design_trial.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

TourTripulation row({
  int type = 31,
  String name = 'Conductor Ejemplo LAB',
  String patent = 'LAB-001',
  int tour = 910001,
}) => TourTripulation(
  tourSalesId: tour,
  tourTripulationIdentificationId: 'LAB-910003',
  tourTripulationNameId: name,
  tourTripulationPhoneId: '',
  tourTripulationDateId: '',
  tourTripulationBusBrand: 'Bus LAB',
  tourTripulationBusPatent: patent,
  tourTripulationBusYear: '2026',
  tourTripulationBusModel: 'Turismo',
  tourTripulationBusEnterprise: 'Transportes LAB',
  tourTripulationTypeId: type,
);

class CrewProvider extends CoordinatorProviders {
  List<TourTripulation> rows = [row(), row(type: 32, name: 'No usar snapshot')];
  List<CrewCoordinator> crew = const [
    CrewCoordinator(id: 910001, name: 'Alex Ejemplo LAB', rut: 'LAB-910001'),
    CrewCoordinator(id: 910002, name: 'Camila Ejemplo LAB', rut: 'LAB-910002'),
  ];
  final requests = <int>[];
  final photos = <int, Uint8List?>{};
  bool failCrew = false, failTransport = false, failPhoto = false;
  Completer<List<TourTripulation>>? pending;
  @override
  Future<List<TourTripulation>> getTripulation(String tourCode) async {
    expect(tourCode, '910001');
    if (failTransport) throw StateError('fixture');
    return pending == null ? rows : pending!.future;
  }

  @override
  Future<List<CrewCoordinator>> getCrewCoordinators(int tourId) async {
    expect(tourId, 910001);
    if (failCrew) throw StateError('fixture');
    return crew;
  }

  @override
  Future<Uint8List?> getCrewCoordinatorPicture(int tourId, int id) async {
    expect(tourId, 910001);
    requests.add(id);
    if (failPhoto) throw StateError('fixture');
    return photos[id];
  }

  @override
  Future<Uint8List?> getCoordinatorPicture() =>
      throw StateError('Must never use the current session photo');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'multiple coordinators retain their identity; repeated join rows do not duplicate bus or drivers',
    () async {
      final p = CrewProvider();
      p.rows.add(row());
      final c = TripCrewController(tourId: 910001, provider: p);
      await c.refresh();
      expect(c.buses.length, 1);
      expect(c.drivers.length, 1);
      expect(c.coordinators.map((x) => x.id), [910001, 910002]);
      expect(c.crewError, false);
      c.dispose();
      p.dispose();
    },
  );
  test('two distinct buses remain visible', () async {
    final p = CrewProvider()..rows.add(row(patent: 'LAB-002'));
    final c = TripCrewController(tourId: 910001, provider: p);
    await c.refresh();
    expect(c.buses.length, 2);
    c.dispose();
    p.dispose();
  });
  test(
    'photo cache is keyed by identity, refreshed after an updated profile',
    () async {
      final p = CrewProvider()
        ..photos[910001] = Uint8List.fromList([1])
        ..photos[910002] = Uint8List.fromList([2]);
      final c = TripCrewController(tourId: 910001, provider: p);
      await c.refresh();
      expect(await c.photo(910001), [1]);
      expect(await c.photo(910002), [2]);
      await c.photo(910001);
      expect(p.requests, [910001, 910002]);
      p.photos[910001] = Uint8List.fromList([9]);
      await c.refresh();
      expect(await c.photo(910001), [9]);
      c.dispose();
      p.dispose();
    },
  );
  test(
    'crew error does not remove available transport; retry recovers',
    () async {
      final p = CrewProvider()..failCrew = true;
      final c = TripCrewController(tourId: 910001, provider: p);
      await c.refresh();
      expect(c.buses.length, 1);
      expect(c.crewError, true);
      p.failCrew = false;
      await c.refresh();
      expect(c.coordinators.length, 2);
      expect(c.crewError, false);
      c.dispose();
      p.dispose();
    },
  );
  test('foreign-tour transport response is rejected', () async {
    final p = CrewProvider()..rows = [row(tour: 910099)];
    final c = TripCrewController(tourId: 910001, provider: p);
    await c.refresh();
    expect(c.transportError, true);
    expect(c.buses, isEmpty);
    c.dispose();
    p.dispose();
  });
  test(
    'late response after leaving cannot notify disposed controller',
    () async {
      final p = CrewProvider()..pending = Completer();
      final c = TripCrewController(tourId: 910001, provider: p);
      final f = c.refresh();
      c.dispose();
      p.pending!.complete([row()]);
      await f;
      p.dispose();
    },
  );
  test('legacy unlinked identity has no fabricated photo ID', () {
    final p = CrewCoordinator.fromJson({'name': 'Equipo LAB', 'rut': 'LAB'});
    expect(p.id, isNull);
    expect(
      () => CrewCoordinator.fromJson({'coordinatorId': 0}),
      throwsFormatException,
    );
  });

  Future<void> show(
    WidgetTester tester,
    CrewProvider provider, {
    Size size = const Size(402, 874),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: AppleDesignTrialScope(
            child: Scaffold(
              body: TripCrewView(tourId: 910001, provider: provider),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('all crew visible with appropriate avatars and every bus field', (
    tester,
  ) async {
    final p = CrewProvider();
    await show(tester, p);
    for (final text in [
      'Tripulación',
      'LAB-001',
      'Bus LAB · Turismo',
      '2026',
      'Transportes LAB',
      'Coordinación',
      'Alex Ejemplo LAB',
      'Camila Ejemplo LAB',
      'Conductor Ejemplo LAB',
    ])
      expect(find.text(text), findsOneWidget);
    expect(find.byType(CrewAvatar), findsNWidgets(2));
    expect(p.requests, [910001, 910002]);
    expect(find.text('No usar snapshot'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });
  testWidgets(
    'profile bytes correspond to correct coordinator and update after refresh',
    (tester) async {
      final bytes = (await rootBundle.load(
        'assets/profile.jpg',
      )).buffer.asUint8List();
      final p = CrewProvider()..photos[910002] = bytes;
      await show(tester, p);
      final image = find.descendant(
        of: find.byKey(const ValueKey('crew-photo-910002')),
        matching: find.byType(Image),
      );
      expect(image, findsOneWidget);
      expect(
        ((tester.widget<Image>(image).image as ResizeImage).imageProvider
                as MemoryImage)
            .bytes,
        bytes,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('crew-photo-910001')),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      p.photos[910002] = null;
      await tester.tap(find.byTooltip('Actualizar tripulación'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('crew-photo-910002')),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
  testWidgets('missing or failed photos show initials without a stock face', (
    tester,
  ) async {
    final p = CrewProvider()..failPhoto = true;
    await show(tester, p);
    expect(find.text('AE'), findsOneWidget);
    expect(find.text('CE'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });
  testWidgets('empty and error states remain distinct; retry available', (
    tester,
  ) async {
    final p = CrewProvider()
      ..rows = []
      ..crew = [];
    await show(tester, p);
    expect(find.text('Bus por confirmar'), findsOneWidget);
    expect(find.text('Aún no hay coordinadores asignados.'), findsOneWidget);
    p.failCrew = true;
    await tester.tap(find.byTooltip('Actualizar tripulación'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos actualizar los coordinadores.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });
  testWidgets(
    '320px and 200% type preserve names, scrolling and controls without overflow',
    (tester) async {
      final p = CrewProvider()
        ..crew = const [
          CrewCoordinator(
            id: null,
            name: 'Nombre muy extenso de Coordinación Ejemplo LAB',
            rut: 'LAB-910001',
          ),
        ];
      await show(tester, p, size: const Size(320, 568), scale: 2);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
