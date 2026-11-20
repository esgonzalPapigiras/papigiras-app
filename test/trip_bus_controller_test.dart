import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/maps/trip_bus_controller.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/location_callback.dart';

class _PositionProvider extends CoordinatorProviders {
  final tours = <String>[];
  List<PositionCoordinator> rows = [];
  Future<List<PositionCoordinator>> Function(String)? read;
  int disposeCount = 0;

  @override
  Future<List<PositionCoordinator>> uniqueID(String tourId) {
    tours.add(tourId);
    return read?.call(tourId) ?? Future.value(rows);
  }

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

PositionCoordinator _point(
  int id,
  DateTime? date, {
  double latitude = -33.45,
  double longitude = -70.65,
  bool? sharingEnabled,
}) => PositionCoordinator(
  coordinatorId: id,
  coordinatorName: 'Demo',
  coordinatorLastname: 'LAB',
  latitude: latitude,
  longitude: longitude,
  recordedAt: date,
  sharingEnabled: sharingEnabled,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _PositionProvider provider;
  late TripBusController controller;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 11, 5, 12);
    provider = _PositionProvider();
    controller = TripBusController(
      tourId: 910001,
      provider: provider,
      now: () => now,
    );
  });

  tearDown(() {
    controller.dispose();
    provider.dispose();
  });

  void testController(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        // Cancel controller timers before Flutter verifies widget invariants.
        controller.dispose();
      }
    });
  }

  testController('consulta sólo al mostrar; repetir visibilidad no duplica', (
    tester,
  ) async {
    provider.rows = [
      _point(910001, DateTime.parse('2026-11-05T08:59:30-03:00')),
    ];
    await controller.refresh();
    expect(provider.tours, isEmpty);
    expect(controller.position, isNull);
    controller.setVisible(true);
    controller.setVisible(true);
    await tester.pump();
    expect(provider.tours, ['910001']);
    expect(controller.position?.coordinatorId, 910001);
    expect(
      controller.position?.recordedAt,
      DateTime.utc(2026, 11, 5, 11, 59, 30),
    );
    expect(controller.position?.recordedAt?.isUtc, isTrue);
    expect(controller.position?.coordinate.latitude, -33.45);
    expect(controller.isRecent, isTrue);
    expect(controller.loading, isFalse);
    expect(controller.error, isNull);
  });

  testController('elige la fecha más reciente con coordenadas válidas', (
    tester,
  ) async {
    provider.rows = [
      _point(1, now.subtract(const Duration(minutes: 5))),
      _point(4, null),
      _point(3, now.subtract(const Duration(seconds: 30))),
      _point(2, now, latitude: double.nan),
      _point(5, now, longitude: 181),
      _point(6, now, latitude: -91),
      _point(7, now.add(const Duration(hours: 1))),
    ];
    controller.setVisible(true);
    await tester.pump();
    expect(controller.position?.coordinatorId, 3);
    expect(controller.isRecent, isTrue);
  });

  testController(
    'remote OFF overrides a fresh repeated position without hiding history',
    (tester) async {
      provider.rows = [_point(1, now, sharingEnabled: true)];
      controller.setVisible(true);
      await tester.pump();
      expect(controller.isRecent, isTrue);
      final coordinate = controller.position!.coordinate;
      provider.rows = [_point(1, now, sharingEnabled: false)];
      await controller.refresh();
      expect(controller.position!.coordinate, coordinate);
      expect(controller.position!.sharingEnabled, isFalse);
      expect(controller.isRecent, isFalse);
      provider.rows = [_point(1, now, sharingEnabled: true)];
      await controller.refresh();
      expect(controller.isRecent, isTrue);
    },
  );

  testController(
    'another active coordinator wins over a newer stopped sender',
    (tester) async {
      provider.rows = [_point(1, now, sharingEnabled: false)];
      controller.setVisible(true);
      await tester.pump();
      provider.rows = [
        _point(1, now, sharingEnabled: false),
        _point(
          2,
          now.subtract(const Duration(seconds: 15)),
          sharingEnabled: true,
        ),
      ];
      await controller.refresh();
      expect(controller.position!.coordinatorId, 2);
      expect(controller.isRecent, isTrue);
    },
  );

  test('position contract preserves explicit OFF and unknown legacy state', () {
    final payload = _point(1, now).toJson();
    expect(PositionCoordinator.fromJson(payload).sharingEnabled, isNull);
    expect(
      PositionCoordinator.fromJson({
        ...payload,
        'sharingEnabled': false,
      }).sharingEnabled,
      isFalse,
    );
    expect(
      PositionCoordinator.fromJson({
        ...payload,
        'sharingEnabled': true,
      }).sharingEnabled,
      isTrue,
    );
  });

  testController(
    'authoritative OFF overrides an earlier local position acknowledgement',
    (tester) async {
      controller.setVisible(true);
      await tester.pump();
      controller.setLocalSharing(
        coordinatorId: 1,
        enabled: true,
        confirmed: CoordinatorLocationReceipt(
          tourId: 910001,
          latitude: -33.45,
          longitude: -70.65,
          recordedAt: now,
        ),
      );
      expect(controller.isRecent, isTrue);
      provider.rows = [
        _point(
          1,
          now.subtract(const Duration(seconds: 5)),
          sharingEnabled: false,
        ),
      ];
      await controller.refresh();
      expect(controller.position!.recordedAt, now);
      expect(controller.position!.sharingEnabled, isFalse);
      expect(controller.isRecent, isFalse);
    },
  );

  testController('fecha futura o ausente nunca se presenta como reciente', (
    tester,
  ) async {
    provider.rows = [_point(1, now.add(const Duration(seconds: 1)))];
    controller.setVisible(true);
    await tester.pump();
    expect(controller.position, isNotNull);
    expect(controller.isRecent, isFalse);
    provider.rows = [_point(2, null)];
    await controller.refresh();
    expect(controller.position?.coordinatorId, 2);
    expect(controller.position?.recordedAt, isNull);
    expect(controller.isRecent, isFalse);
  });

  testController(
    'infers a clockwise heading from movement and preserves it through GPS noise',
    (tester) async {
      provider.rows = [_point(1, now)];
      controller.setVisible(true);
      await tester.pump();
      expect(controller.position?.headingDegrees, isNull);

      Future<void> report({
        double latitude = -33.45,
        double longitude = -70.65,
      }) async {
        now = now.add(const Duration(seconds: 10));
        provider.rows = [
          _point(1, now, latitude: latitude, longitude: longitude),
        ];
        await controller.refresh();
      }

      // Two 8 m changes are useful together, but either alone may be GPS noise.
      await report(longitude: -70.64991);
      expect(controller.position?.headingDegrees, isNull);
      await report(longitude: -70.64982);
      expect(controller.position?.headingDegrees, closeTo(90, .2));

      await report(latitude: -33.45003, longitude: -70.64982);
      expect(controller.position?.headingDegrees, closeTo(90, .2));
      await report(latitude: -33.4502, longitude: -70.64982);
      expect(controller.position?.headingDegrees, closeTo(180, .2));

      final last = controller.position;
      for (final date in [
        now,
        now.subtract(const Duration(seconds: 10)),
        null,
        now.add(const Duration(seconds: 10)),
      ]) {
        provider.rows = [_point(1, date, longitude: -70.66)];
        await controller.refresh();
        expect(controller.position, same(last));
      }

      provider.rows = [
        _point(1, last!.recordedAt, latitude: -33.4502, longitude: -70.64982),
      ];
      now = now.add(const Duration(minutes: 3));
      await tester.pump(const Duration(minutes: 3));
      expect(controller.isRecent, isFalse);
      expect(controller.position, same(last));

      // A gap in reporting does not create a straight-line heading.
      await report(latitude: -33.4502, longitude: -70.66);
      expect(controller.position?.headingDegrees, closeTo(180, .2));
      await report(latitude: -33.4502, longitude: -70.6602);
      expect(controller.position?.headingDegrees, closeTo(270, .2));
    },
  );

  testController(
    'resets the movement reference when coordinator or tour changes',
    (tester) async {
      provider.rows = [_point(1, now)];
      controller.setVisible(true);
      await tester.pump();
      now = now.add(const Duration(seconds: 10));
      provider.rows = [_point(1, now, longitude: -70.6495)];
      await controller.refresh();
      expect(controller.position?.headingDegrees, closeTo(90, .2));

      // If the first coordinator is no longer in the response, continue with
      // the next coordinator's own fixes, even at the same clock time.
      provider.rows = [_point(2, now, longitude: -70.66)];
      await controller.refresh();
      expect(controller.position?.coordinatorId, 2);
      expect(controller.position?.headingDegrees, isNull);
      now = now.add(const Duration(seconds: 10));
      provider.rows = [_point(2, now, longitude: -70.6605)];
      await controller.refresh();
      expect(controller.position?.headingDegrees, closeTo(270, .2));

      controller.setTour(910002);
      expect(controller.position, isNull);
      await tester.pump();
      expect(controller.position?.headingDegrees, isNull);
    },
  );

  testController('no solapa polling ni refresh manual con petición pendiente', (
    tester,
  ) async {
    final pending = Completer<List<PositionCoordinator>>();
    provider.read = (_) => pending.future;
    controller.setVisible(true);
    final first = controller.refresh();
    expect(identical(first, controller.refresh()), isTrue);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(provider.tours, ['910001']);
    pending.complete([_point(1, now)]);
    await tester.pump();
    await first;
    expect(controller.isRecent, isTrue);
    now = now.add(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 20));
    expect(provider.tours, ['910001', '910001']);
  });

  testController('el pulso vence aunque una nueva petición siga pendiente', (
    tester,
  ) async {
    provider.rows = [_point(1, now.subtract(const Duration(seconds: 110)))];
    final states = <bool>[];
    controller.addListener(() => states.add(controller.isRecent));
    controller.setVisible(true);
    await tester.pump();
    expect(controller.isRecent, isTrue);
    final pending = Completer<List<PositionCoordinator>>();
    provider.read = (_) => pending.future;
    final refresh = controller.refresh();
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(controller.isRecent, isTrue); // Inclusive two-minute boundary.
    now = now.add(const Duration(microseconds: 1));
    await tester.pump(const Duration(microseconds: 1));
    expect(controller.isRecent, isFalse);
    expect(states.last, isFalse);
    expect(controller.loading, isTrue);
    pending.complete(provider.rows);
    await tester.pump();
    await refresh;
  });

  testController(
    'un error conserva el punto y apaga el pulso hasta recuperar',
    (tester) async {
      provider.rows = [_point(1, now)];
      controller.setVisible(true);
      await tester.pump();
      final previous = controller.position;
      provider.read = (_) => Future.error(StateError('Fixture failure'));
      await controller.refresh();
      expect(identical(controller.position, previous), isTrue);
      expect(controller.error, isNotNull);
      expect(controller.isRecent, isFalse);
      provider.read = null;
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.isRecent, isTrue);
    },
  );

  testController(
    'cambiar gira ignora el resultado anterior sin solapar lecturas',
    (tester) async {
      final old = Completer<List<PositionCoordinator>>();
      final current = Completer<List<PositionCoordinator>>();
      provider.read = (id) => id == '910001' ? old.future : current.future;
      controller.setVisible(true);
      controller.setTour(910002);
      expect(controller.tourId, 910002);
      expect(controller.position, isNull);
      expect(provider.tours, ['910001']);
      old.complete([_point(1, now)]);
      await tester.pump();
      expect(controller.position, isNull);
      expect(provider.tours, ['910001', '910002']);
      current.complete([_point(2, now)]);
      await tester.pump();
      expect(controller.position?.coordinatorId, 2);
      expect(controller.isRecent, isTrue);
      controller.setTour(910002);
      controller.setTour(-1);
      expect(provider.tours.length, 2);
    },
  );

  testController('background pausa polling e ignora respuestas anteriores', (
    tester,
  ) async {
    final old = Completer<List<PositionCoordinator>>();
    provider.read = (_) => old.future;
    controller.setVisible(true);
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await controller.refresh();
    expect(provider.tours.length, 1);
    provider.read = null;
    provider.rows = [_point(2, now)];
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(provider.tours.length, 1);
    old.complete([_point(1, now)]);
    await tester.pump();
    expect(provider.tours.length, 2);
    expect(controller.position?.coordinatorId, 2);
    expect(controller.isRecent, isTrue);
  });

  testController('mapa oculto no consulta; resume no lo vuelve visible', (
    tester,
  ) async {
    provider.rows = [_point(1, now)];
    controller.setVisible(true);
    await tester.pump();
    controller.setVisible(false);
    expect(controller.isRecent, isFalse);
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(provider.tours.length, 1);
    controller.setVisible(true);
    await tester.pump();
    expect(provider.tours.length, 2);
    expect(controller.isRecent, isTrue);
  });

  testController('respuesta vacía o inválida retira una posición anterior', (
    tester,
  ) async {
    provider.rows = [_point(1, now)];
    controller.setVisible(true);
    await tester.pump();
    expect(controller.position, isNotNull);
    provider.rows = [];
    await controller.refresh();
    expect(controller.position, isNull);
    expect(controller.error, isNull);
    provider.rows = [_point(2, now, longitude: double.infinity)];
    await controller.refresh();
    expect(controller.position, isNull);
    expect(controller.isRecent, isFalse);
  });

  testController(
    'logout descarta la respuesta incluso con token ficticio reutilizado',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      const fixtureToken = 'fixture-session-token';
      await prefs.setString('token', fixtureToken);
      provider.rows = [_point(1, now)];
      controller.setVisible(true);
      await tester.pump();
      expect(controller.position, isNotNull);
      final pending = Completer<List<PositionCoordinator>>();
      provider.read = (_) => pending.future;
      final refresh = controller.refresh();
      final cleared = LabSession.clear(prefs);
      // Revoked synchronously, before preferences and route teardown finish.
      expect(controller.position, isNull);
      expect(controller.isRecent, isFalse);
      expect(controller.loading, isFalse);
      await cleared;
      await prefs.setString('token', fixtureToken);
      pending.complete([_point(2, now)]);
      await tester.pump();
      await refresh;
      expect(controller.position, isNull);
      expect(controller.error, isNull);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      controller.setVisible(false);
      controller.setVisible(true);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await controller.refresh();
      expect(provider.tours.length, 2);
      provider.read = null;
      final nextSession = TripBusController(
        tourId: 910001,
        provider: provider,
        now: () => now,
      );
      try {
        nextSession.setVisible(true);
        await tester.pump();
        expect(nextSession.position, isNotNull);
        expect(provider.tours.length, 3);
        expect(controller.position, isNull);
      } finally {
        nextSession.dispose();
      }
    },
  );

  testController('logout sin petición pendiente detiene el próximo polling', (
    tester,
  ) async {
    provider.rows = [_point(1, now)];
    controller.setVisible(true);
    await tester.pump();
    await LabSession.clear(await SharedPreferences.getInstance());
    expect(controller.position, isNull);
    expect(controller.isRecent, isFalse);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(provider.tours.length, 1);
    expect(controller.error, isNull);
  });

  testController(
    'dispose ignora respuestas y conserva el proveedor inyectado',
    (tester) async {
      final pending = Completer<List<PositionCoordinator>>();
      provider.read = (_) => pending.future;
      var notices = 0;
      controller.addListener(() => notices++);
      controller.setVisible(true);
      final before = notices;
      controller.dispose();
      pending.complete([_point(1, now)]);
      await tester.pump(const Duration(minutes: 1));
      expect(controller.position, isNull);
      expect(controller.isRecent, isFalse);
      expect(notices, before);
      expect(provider.disposeCount, 0);
      controller.setVisible(true);
      controller.setTour(910002);
      await controller.refresh();
      expect(provider.tours.length, 1);
    },
  );
}
