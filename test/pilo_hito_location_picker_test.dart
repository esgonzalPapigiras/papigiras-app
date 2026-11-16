import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'package:papigiras_app/maps/pilo_hito_location_picker.dart';

import 'support/map_tiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final initial = HitoLocationDraft(
    point: const LatLng(-33.45, -70.66),
    label: 'Plaza de prueba',
  );
  final mapFinder = find.byKey(const ValueKey('hito-location-map'));
  final confirm = find.byKey(const ValueKey('hito-location-confirm'));
  late HitoLocationDraft? result;
  late bool completed;
  late List<MethodCall> haptics;

  setUpAll(() async {
    await Future.wait([
      (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load(),
      (FontLoader(
        'Manjari',
      )..addFont(rootBundle.load('assets/fonts/Manjari-Regular.ttf'))).load(),
      (FontLoader(
        'Inter',
      )..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))).load(),
    ]);
  });

  setUp(() {
    result = null;
    completed = false;
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        });
    final previousHttp = HttpOverrides.current;
    final previousProvider = LabMapTiles.testProvider;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMapTiles.testProvider = TestMapTileProvider.new;
    addTearDown(() {
      HttpOverrides.global = previousHttp;
      LabMapTiles.testProvider = previousProvider;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  Future<void> openPicker(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
    double scale = 1,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: PiloFamilyTheme.theme(ThemeData()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion,
          ),
          child: RepaintBoundary(
            key: const ValueKey('pin-motion-capture'),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showPiloHitoLocationPicker(
                    context,
                    initial: initial,
                  );
                  completed = true;
                },
                child: const Text('Elegir ubicación'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Elegir ubicación'));
    await tester.pumpAndSettle();
  }

  MapController camera(WidgetTester tester) =>
      tester.widget<FlutterMap>(mapFinder).mapController!;

  void expectSamePoint(LatLng actual, LatLng expected) {
    expect(actual.latitude, closeTo(expected.latitude, 1e-8));
    expect(actual.longitude, closeTo(expected.longitude, 1e-8));
  }

  double lift(WidgetTester tester) => tester
      .widget<PiloHitoPlacementPin>(find.byType(PiloHitoPlacementPin))
      .lift;

  Future<void> finishMotion(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // Allow the quiet interval after the map's fling to finish, then the
    // optional visual landing. The camera has already selected its point.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.environment['PILO_PIN_MOTION_CAPTURE'] != '1') return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('pin-motion-capture')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory(
          'registro-local/PILO-HITO-UBICACION-R2/evidencias',
        );
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  test('rejects nonfinite or out-of-world coordinates', () {
    for (final point in [
      const LatLng(double.nan, 0),
      const LatLng(0, double.infinity),
      const LatLng(85.0512, 0),
      const LatLng(-85.0512, 0),
      const LatLng(0, 180.01),
      const LatLng(0, -180.01),
    ]) {
      expect(() => HitoLocationDraft.selectedPoint(point), throwsArgumentError);
    }
    expect(HitoLocationDraft.isValidPoint(const LatLng(85.0511, 180)), isTrue);
  });

  testWidgets('unchanged point preserves its existing label and value', (
    tester,
  ) async {
    await openPicker(tester);
    expect(find.text('Plaza de prueba'), findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(identical(result, initial), isTrue);
  });

  testWidgets('tap centres on that coordinate and only confirms explicitly', (
    tester,
  ) async {
    await openPicker(tester);
    final mapRect = tester.getRect(mapFinder);
    final tap = mapRect.center + const Offset(-65, 60);
    final local = tap - mapRect.topLeft;
    final expected = camera(
      tester,
    ).camera.pointToLatLng(math.Point(local.dx, local.dy));
    await tester.tapAt(tap);
    // Map taps wait briefly to disambiguate the double-tap zoom gesture.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expectSamePoint(camera(tester).camera.center, expected);
    expect(completed, isFalse);
    expect(find.text('Punto seleccionado en el mapa'), findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expectSamePoint(result!.point, expected);
    expect(result!.label, 'Punto seleccionado en el mapa');
  });

  testWidgets('drag keeps pin fixed and returns the actual camera centre', (
    tester,
  ) async {
    await openPicker(tester);
    final pin = find.byKey(const ValueKey('hito-location-fixed-pin'));
    final pinBefore = tester.getRect(pin);
    final mapBefore = tester.getRect(mapFinder);
    expect((pinBefore.bottomCenter - mapBefore.center).distance, lessThan(.1));
    await tester.dragFrom(mapBefore.center, const Offset(85, 50));
    await finishMotion(tester);
    final centre = camera(tester).camera.center;
    expect((centre.longitude - initial.point.longitude).abs(), greaterThan(0));
    expect(tester.getRect(pin), pinBefore);
    expect(completed, isFalse);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expectSamePoint(result!.point, centre);
  });

  testWidgets('cancel after moving returns no change', (tester) async {
    await openPicker(tester);
    await tester.drag(mapFinder, const Offset(60, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hito-location-cancel')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
    expect(initial.label, 'Plaza de prueba');
    expect(initial.point, const LatLng(-33.45, -70.66));
  });

  testWidgets(
    'recenter restores original label; zoom never changes selection',
    (tester) async {
      await openPicker(tester);
      await tester.drag(mapFinder, const Offset(60, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hito-location-original')));
      await tester.pumpAndSettle();
      expect(find.text('Plaza de prueba'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Acercar mapa'));
        await tester.pumpAndSettle();
      }
      expect(camera(tester).camera.zoom, 19);
      expectSamePoint(camera(tester).camera.center, initial.point);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(identical(result, initial), isTrue);
    },
  );

  testWidgets('320px and large text keep map and confirmation usable', (
    tester,
  ) async {
    await openPicker(tester, width: 320, height: 640, scale: 1.6);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(mapFinder).height, greaterThan(160));
    expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(640));
    for (final tooltip in [
      'Cancelar ubicación',
      'Volver al punto original',
      'Acercar mapa',
      'Alejar mapa',
    ]) {
      final size = tester.getSize(find.byTooltip(tooltip));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }
    final pin = tester.getRect(
      find.byKey(const ValueKey('hito-location-fixed-pin')),
    );
    expect(
      (pin.bottomCenter - tester.getRect(mapFinder).center).distance,
      lessThan(.1),
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('held drag lifts pin; landing anchors it and cues exactly once', (
    tester,
  ) async {
    await openPicker(tester);
    expect(haptics, isEmpty);
    final mapCenter = tester.getRect(mapFinder).center;
    final gesture = await tester.startGesture(mapCenter);
    await gesture.moveBy(const Offset(48, 30));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(24, 12));
    await tester.pump(const Duration(milliseconds: 200));
    expect(lift(tester), 1);
    final pin = tester.getRect(
      find.byKey(const ValueKey('hito-location-fixed-pin')),
    );
    expect(pin.bottomCenter.dx, closeTo(mapCenter.dx, .1));
    expect(pin.bottomCenter.dy, closeTo(mapCenter.dy - 12, .1));
    final ground = tester.getRect(
      find.byKey(const ValueKey('hito-location-ground-shadow')),
    );
    expect(ground.center, mapCenter);
    await capture(tester, 'picker-pin-elevado');
    await tester.pump(const Duration(milliseconds: 500));
    expect(lift(tester), 1, reason: 'Finger is still holding the map');
    expect(haptics, isEmpty);
    await gesture.up();
    await finishMotion(tester);
    expect(lift(tester), 0);
    expect(haptics, hasLength(1));
    expect(haptics.single.arguments, 'HapticFeedbackType.selectionClick');
    await capture(tester, 'picker-pin-apoyado');
    final selected = camera(tester).camera.center;
    await tester.pump(const Duration(seconds: 1));
    expect(haptics, hasLength(1));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expectSamePoint(result!.point, selected);
  });

  testWidgets('fling stays lifted until actual camera motion finishes', (
    tester,
  ) async {
    await openPicker(tester);
    await tester.flingFrom(
      tester.getRect(mapFinder).center,
      const Offset(100, 60),
      1200,
    );
    await tester.pump(const Duration(milliseconds: 80));
    final during = camera(tester).camera.center;
    await tester.pump(const Duration(milliseconds: 80));
    expect(camera(tester).camera.center, isNot(during));
    expect(lift(tester), greaterThan(.9));
    expect(haptics, isEmpty);
    await finishMotion(tester);
    expect(lift(tester), 0);
    expect(haptics, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps pin static and preserves map selection', (
    tester,
  ) async {
    await openPicker(tester, reduceMotion: true);
    final pinFinder = find.byKey(const ValueKey('hito-location-fixed-pin'));
    final originalRect = tester.getRect(pinFinder);
    final gesture = await tester.startGesture(tester.getRect(mapFinder).center);
    await gesture.moveBy(const Offset(70, 20));
    await tester.pump(const Duration(milliseconds: 200));
    expect(lift(tester), 0);
    expect(tester.getRect(pinFinder), originalRect);
    await gesture.up();
    await finishMotion(tester);
    expect(haptics, isEmpty);
    final selected = camera(tester).camera.center;
    expect(selected, isNot(initial.point));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expectSamePoint(result!.point, selected);
  });

  testWidgets('cancel interrupts visual feedback with no delayed haptic', (
    tester,
  ) async {
    await openPicker(tester);
    camera(tester).move(const LatLng(-33.451, -70.661), 16);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(lift(tester), greaterThan(0));
    await tester.tap(find.byKey(const ValueKey('hito-location-cancel')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(result, isNull);
    expect(completed, isTrue);
    expect(haptics, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'confirm during lift uses latest point, never visual pin offset',
    (tester) async {
      await openPicker(tester);
      camera(tester).move(const LatLng(-33.451, -70.661), 16);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      const latest = LatLng(-33.452, -70.663);
      camera(tester).move(latest, 16);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expectSamePoint(result!.point, latest);
      expect(haptics, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zoom feedback does not vibrate without a changed coordinate', (
    tester,
  ) async {
    await openPicker(tester);
    await tester.tap(find.byTooltip('Acercar mapa'));
    await finishMotion(tester);
    expect(camera(tester).camera.zoom, 17);
    expectSamePoint(camera(tester).camera.center, initial.point);
    expect(lift(tester), 0);
    expect(haptics, isEmpty);
  });
}
