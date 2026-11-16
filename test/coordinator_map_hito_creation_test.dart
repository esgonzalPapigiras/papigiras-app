import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/synthetic_location.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/maps/trip_hito_detail.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

import 'support/map_tiles.dart';
import 'trip_map_nearby_navigation_test.dart' show row;

class _Provider extends CoordinatorProviders {
  bool empty = false;

  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tour) async =>
      DetailHitoList(
        titulo: 'Hito ficticio',
        descripcion: 'Resumen ficticio',
        images: [],
      );

  @override
  Future<List<PositionCoordinator>> uniqueID(String code) async => [];

  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String code) async =>
      empty ? [] : [row(910021, '-33.45', '-70.65')];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inlineCaptureEnabled =
      Platform.environment['PILO_INLINE_MAP_CAPTURE'] == '1';
  final actionsCaptureEnabled =
      Platform.environment['PILO_MAP_ACTIONS_CAPTURE'] == '1';
  final captureEnabled = inlineCaptureEnabled || actionsCaptureEnabled;
  late _Provider provider;
  late TripMapController controller;
  late List<HitoLocationDraft> chosen;

  setUpAll(() async {
    if (!captureEnabled) return;
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    provider = _Provider();
    controller = TripMapController(tourCode: 910001, provider: provider);
    chosen = [];
    LabSyntheticLocation.instance.resetForTests();
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMapTiles.testProvider = TestMapTileProvider.new;
    addTearDown(() {
      controller.dispose();
      provider.dispose();
      HttpOverrides.global = previous;
      LabMapTiles.testProvider = null;
      LabSyntheticLocation.instance.resetForTests();
    });
  });

  Future<void> show(
    WidgetTester tester, {
    bool coordinator = true,
    bool edgeToEdge = true,
    double width = 402,
    double scale = 1,
    EdgeInsets safeArea = EdgeInsets.zero,
    Future<void> Function(TripMapEntry)? onOpenHito,
    bool owned = false,
    Future<void> Function(HitoLocationDraft)? onCreateHito,
  }) async {
    tester.view.physicalSize = Size(width, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await controller.refresh();
    await tester.pumpWidget(
      MaterialApp(
        theme: captureEnabled ? PiloFamilyTheme.theme(ThemeData()) : null,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
            padding: safeArea,
          ),
          child: RepaintBoundary(
            key: const ValueKey('inline-map-capture'),
            child: child!,
          ),
        ),
        home: TraceMapFullScreen(
          tourCode: 910001,
          coordinatorId: coordinator ? 910001 : null,
          controller: owned ? null : controller,
          edgeToEdge: edgeToEdge,
          onOpenHito: onOpenHito,
          onCreateHito: coordinator
              ? onCreateHito ?? (location) async => chosen.add(location)
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder action() => find.byKey(const ValueKey('coordinator-map-create-hito'));
  Finder pickerMap() => find.byKey(const ValueKey('hito-location-map'));
  Finder placementCard() =>
      find.byKey(const ValueKey('coordinator-map-placement-card'));
  Finder placementPin() =>
      find.byKey(const ValueKey('coordinator-map-placement-pin'));
  Marker draftMarker(WidgetTester tester) => tester
      .widgetList<MarkerLayer>(find.byType(MarkerLayer))
      .expand((layer) => layer.markers)
      .singleWhere(
        (marker) =>
            marker.child.key == const ValueKey('coordinator-map-placement-pin'),
      );
  MapCamera camera(WidgetTester tester, Finder map) =>
      tester.widget<FlutterMap>(map).mapController!.camera;

  Future<void> capture(WidgetTester tester, {String? actionState}) async {
    if (actionState == null ? !inlineCaptureEnabled : !actionsCaptureEnabled) {
      return;
    }
    final previousDisableShadows = debugDisableShadows;
    debugDisableShadows = false;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(
      tester.renderObject(find.byKey(const ValueKey('inline-map-capture'))),
    );
    await tester.pump();
    try {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('inline-map-capture')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory(
            actionState == null
                ? 'registro-local/PILO-HITO-UBICACION-R2/evidencias'
                : 'registro-local/PILO-MAPA-ACCIONES/evidencias',
          );
          await directory.create(recursive: true);
          await File(
            '${directory.path}/${actionState ?? 'mapa-pin-inline-fixture'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    } finally {
      debugDisableShadows = previousDisableShadows;
    }
  }

  testWidgets('new hito is centered near bottom above the area count', (
    tester,
  ) async {
    await show(tester, safeArea: const EdgeInsets.only(top: 59, bottom: 34));
    final actionRect = tester.getRect(action());
    final mapRect = tester.getRect(find.byType(FlutterMap));
    final countRect = tester.getRect(
      find.byKey(const ValueKey('pilo-map-area-count')),
    );
    final summarySurface = find
        .ancestor(
          of: find.byKey(const ValueKey('pilo-map-area-count')),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getRect(summarySurface).width, closeTo(mapRect.width, 1));
    expect(action().hitTestable(), findsOneWidget);
    expect(actionRect.center.dx, closeTo(mapRect.center.dx, 1));
    expect(actionRect.top, greaterThan(mapRect.top + mapRect.height * .7));
    expect(actionRect.bottom, lessThan(countRect.top));
    expect(actionRect.height, greaterThanOrEqualTo(44));
    for (final tooltip in [
      'Volver',
      'Ver lista de hitos',
      'Actualizar hitos',
    ]) {
      final control = find.byTooltip(tooltip);
      expect(control.hitTestable(), findsOneWidget);
      expect(tester.getRect(control).overlaps(actionRect), isFalse);
    }
    expect(tester.takeException(), isNull);
    await capture(tester, actionState: 'mapa-nuevo-hito-abajo');
  });

  testWidgets(
    'bottom creation action stays above selected and expanded cards',
    (tester) async {
      await show(tester, safeArea: const EdgeInsets.only(top: 59, bottom: 34));
      await tester.tap(find.byKey(const ValueKey('trip-pin-910021')));
      await tester.pumpAndSettle();
      final carousel = find.byKey(const ValueKey('pilo-map-area-carousel'));
      expect(carousel, findsOneWidget);
      expect(action().hitTestable(), findsOneWidget);
      expect(
        tester.getRect(action()).bottom,
        lessThanOrEqualTo(tester.getRect(carousel).top - 8),
      );
      expect(
        tester.getRect(action()).center.dx,
        closeTo(tester.getRect(carousel).center.dx, 1),
      );
      expect(find.text('Ver hito').hitTestable(), findsOneWidget);
      await capture(tester, actionState: 'mapa-nuevo-hito-con-tarjeta');
      await tester.tap(find.byKey(const ValueKey('pilo-map-area-handle')));
      await tester.pumpAndSettle();
      expect(action().hitTestable(), findsOneWidget);
      expect(
        tester.getRect(action()).bottom,
        lessThanOrEqualTo(tester.getRect(carousel).top - 8),
      );
      expect(find.text('Ver hito').hitTestable(), findsOneWidget);
      await tester.tap(action());
      await tester.pumpAndSettle();
      expect(chosen, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inline placement replaces the normal bottom create action', (
    tester,
  ) async {
    await show(tester);
    await tester.longPressAt(
      tester.getCenter(find.byType(FlutterMap)) + const Offset(-70, -80),
    );
    await tester.pumpAndSettle();
    expect(action(), findsNothing);
    expect(find.text('Crear hito aquí').hitTestable(), findsOneWidget);
    expect(find.text('Descartar').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(action().hitTestable(), findsOneWidget);
    expect(chosen, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non immersive create action is also centered below the map', (
    tester,
  ) async {
    await show(tester, edgeToEdge: false);
    final mapRect = tester.getRect(find.byType(FlutterMap));
    final actionRect = tester.getRect(action());
    expect(action().hitTestable(), findsOneWidget);
    expect(actionRect.center.dx, closeTo(mapRect.center.dx, 1));
    expect(actionRect.center.dy, greaterThan(mapRect.center.dy));
    await tester.tap(action());
    await tester.pumpAndSettle();
    expect(chosen, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'normal creation uses current coordinator source after panning elsewhere',
    (tester) async {
      await show(tester);
      final map = find.byType(FlutterMap);
      await tester.drag(map, const Offset(80, 100));
      await tester.pumpAndSettle();
      final viewport = camera(tester, map).center;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('labSyntheticRouteIndex', 4);
      await tester.tap(action());
      await tester.pumpAndSettle();
      final source = LabSyntheticLocation.instance.current;
      expect(source, LabSyntheticLocation.route[4]);
      expect(chosen.single.point, source.latLng);
      expect(chosen.single.label, source.address);
      expect(chosen.single.point, isNot(viewport));
      expect(pickerMap(), findsNothing);
      expect(camera(tester, map).center, viewport);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discard inline placement restores selected carousel without creating',
    (tester) async {
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('trip-pin-910021')));
      await tester.pumpAndSettle();
      final map = find.byType(FlutterMap);
      final viewport = camera(tester, map).center;
      final selected = controller.selectedId;
      await tester.longPressAt(tester.getCenter(map) + const Offset(-70, -80));
      await tester.pumpAndSettle();
      expect(placementCard(), findsOneWidget);
      expect(pickerMap(), findsNothing);
      expect(chosen, isEmpty);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(placementPin(), findsNothing);
      expect(chosen, isEmpty);
      expect(controller.selectedId, selected);
      expect(find.text('Ver hito'), findsOneWidget);
      expect(camera(tester, map).center, viewport);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long press selects inline and confirmation alone opens composer callback',
    (tester) async {
      await show(tester);
      final map = find.byType(FlutterMap);
      final touch = tester.getCenter(map) + const Offset(-70, -80);
      await tester.tapAt(touch);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(controller.selectedId, isNull);
      expect(placementCard(), findsNothing);
      final bounds = tester.getRect(map);
      final expected = camera(tester, map).pointToLatLng(
        math.Point(touch.dx - bounds.left, touch.dy - bounds.top),
      );
      await tester.longPressAt(touch);
      await tester.pumpAndSettle();
      expect(placementCard(), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(pickerMap(), findsNothing);
      expect(
        draftMarker(tester).point.latitude,
        closeTo(expected.latitude, 1e-8),
      );
      expect(
        draftMarker(tester).point.longitude,
        closeTo(expected.longitude, 1e-8),
      );
      expect(chosen, isEmpty);
      await capture(tester);
      await tester.tap(find.text('Crear hito aquí'));
      await tester.pumpAndSettle();
      expect(chosen.single.point, expected);
      expect(chosen.single.label, 'Punto seleccionado en el mapa');
      expect(placementCard(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inline point adjusts by tap and drag on same map', (
    tester,
  ) async {
    await show(tester);
    final map = find.byType(FlutterMap);
    final viewport = camera(tester, map).center;
    await tester.longPressAt(tester.getCenter(map) + const Offset(-70, -80));
    await tester.pumpAndSettle();
    final first = draftMarker(tester).point;
    final next = tester.getCenter(map) + const Offset(20, -140);
    await tester.tapAt(next);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(draftMarker(tester).point, isNot(first));
    final atStart = draftMarker(tester).point;
    final gesture = await tester.startGesture(tester.getCenter(placementPin()));
    await gesture.moveBy(const Offset(25, 0));
    await tester.pump();
    final dragStart = draftMarker(tester).point;
    final pixelStart = camera(tester, map).latLngToScreenPoint(dragStart);
    await gesture.moveBy(const Offset(12, 10));
    await gesture.moveBy(const Offset(14, 10));
    await gesture.up();
    await tester.pumpAndSettle();
    final finalPixel = camera(
      tester,
      map,
    ).latLngToScreenPoint(draftMarker(tester).point);
    expect(finalPixel.x - pixelStart.x, closeTo(26, 1));
    expect(finalPixel.y - pixelStart.y, closeTo(20, 1));
    expect(draftMarker(tester).point, isNot(atStart));
    expect(camera(tester, map).center, viewport);
    expect(chosen, isEmpty);
    expect(pickerMap(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing markers do not steal taps during inline placement', (
    tester,
  ) async {
    await show(tester);
    controller.clearSelection();
    await tester.pumpAndSettle();
    await tester.longPressAt(
      tester.getCenter(find.byType(FlutterMap)) + const Offset(-70, -80),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('trip-pin-910021'))),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(controller.selectedId, isNull);
    expect(placementCard(), findsOneWidget);
    expect(chosen, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('family map offers no creation action or long press creation', (
    tester,
  ) async {
    await show(tester, coordinator: false);
    expect(action(), findsNothing);
    expect(find.byTooltip('Mi ubicación'), findsNothing);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.onLongPress, isNull);
    await tester.longPressAt(
      tester.getCenter(find.byType(FlutterMap)) + const Offset(-70, -80),
    );
    await tester.pumpAndSettle();
    expect(pickerMap(), findsNothing);
    expect(chosen, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tour without hitos can create its first map point', (
    tester,
  ) async {
    provider.empty = true;
    await show(tester);
    expect(action(), findsOneWidget);
    await tester.tap(action());
    await tester.pumpAndSettle();
    expect(pickerMap(), findsNothing);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(chosen.single.point, LabSyntheticLocation.instance.current.latLng);
    expect(find.byTooltip('Mi ubicación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map creation remains reachable at 320px and large text', (
    tester,
  ) async {
    await show(tester, width: 320, scale: 1.6);
    expect(action().hitTestable(), findsOneWidget);
    expect(tester.getSize(action()).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
    await tester.tap(action());
    await tester.pumpAndSettle();
    expect(chosen, hasLength(1));
    expect(pickerMap(), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('coordinator detail callback receives selected entry', (
    tester,
  ) async {
    final opened = <TripMapEntry>[];
    await show(tester, onOpenHito: (entry) async => opened.add(entry));
    await tester.tap(find.byKey(const ValueKey('trip-pin-910021')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver hito'));
    await tester.pumpAndSettle();
    expect(opened.single.id, 910021);
    expect(find.byType(TripHitoDetail), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('standalone map refreshes owned list after a new hito', (
    tester,
  ) async {
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    LabFixtures.hitos = [];
    addTearDown(() {
      LabMode.useFixturesForTests(false);
      LabFixtures.reset();
    });
    await show(
      tester,
      owned: true,
      onCreateHito: (location) async {
        LabFixtures.hitos = [
          row(
            910022,
            location.point.latitude.toString(),
            location.point.longitude.toString(),
          ),
        ];
      },
    );
    final owned = tester
        .widget<TripMapView>(find.byType(TripMapView))
        .controller;
    expect(owned.data!.entries, isEmpty);
    await tester.tap(action());
    await tester.pumpAndSettle();
    expect(owned.data!.entries.single.id, 910022);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone map refreshes edited location without recentering', (
    tester,
  ) async {
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    LabFixtures.hitos = [row(910023, '-33.45', '-70.65')];
    addTearDown(() {
      LabMode.useFixturesForTests(false);
      LabFixtures.reset();
    });
    await show(
      tester,
      owned: true,
      onOpenHito: (entry) async {
        LabFixtures.hitos = [row(910023, '-33.46', '-70.64')];
      },
    );
    final owned = tester
        .widget<TripMapView>(find.byType(TripMapView))
        .controller;
    final before = camera(tester, find.byType(FlutterMap)).center;
    await tester.tap(find.byKey(const ValueKey('trip-pin-910023')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver hito'));
    await tester.pumpAndSettle();
    expect(owned.data!.entries.single.position!.latitude, -33.46);
    expect(camera(tester, find.byType(FlutterMap)).center, before);
    expect(tester.takeException(), isNull);
  });
  for (final sharing in [false, true]) {
    testWidgets(
      'Mi ubicación recenters once and preserves sharing $sharing and selection',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('coordinatorLocationSharingEnabled', sharing);
        await show(tester);
        await tester.tap(find.byKey(const ValueKey('trip-pin-910021')));
        await tester.pumpAndSettle();
        final selected = controller.selectedId;
        final revision = controller.selectionRevision;
        await LabSyntheticLocation.instance.select(2);
        final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
        await tester.tap(find.byTooltip('Mi ubicación'));
        await tester.pumpAndSettle();
        final map = find.byType(FlutterMap);
        expect(
          camera(tester, map).center,
          LabSyntheticLocation.route[2].latLng,
        );
        expect(controller.selectedId, selected);
        expect(controller.selectionRevision, revision);
        expect(find.text('Ver hito'), findsOneWidget);
        expect({
          for (final key in prefs.getKeys()) key: prefs.get(key),
        }, before);
        await LabSyntheticLocation.instance.select(3);
        await tester.pumpAndSettle();
        expect(
          camera(tester, map).center,
          LabSyntheticLocation.route[2].latLng,
        );
        await tester.drag(map, const Offset(-80, -60));
        await tester.pumpAndSettle();
        expect(
          camera(tester, map).center,
          isNot(LabSyntheticLocation.route[2].latLng),
        );
        await tester.tap(find.byTooltip('Mi ubicación'));
        await tester.pumpAndSettle();
        expect(
          camera(tester, map).center,
          LabSyntheticLocation.route[3].latLng,
        );
        expect(prefs.getBool('coordinatorLocationSharingEnabled'), sharing);
        expect(LabSyntheticLocation.instance.index, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Mi ubicación works before the first hito', (tester) async {
    provider.empty = true;
    await show(tester);
    await LabSyntheticLocation.instance.select(5);
    await tester.tap(find.byTooltip('Mi ubicación'));
    await tester.pumpAndSettle();
    expect(
      camera(tester, find.byType(FlutterMap)).center,
      LabSyntheticLocation.route[5].latLng,
    );
    expect(chosen, isEmpty);
    expect(controller.data!.entries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inline placement fits 320px and large text with pin above card',
    (tester) async {
      await show(tester, width: 320, scale: 1.6);
      final map = find.byType(FlutterMap);
      // The old fixed point is now covered by the bottom creation button.
      // Long-press the lowest unobstructed map area instead of a control.
      await tester.longPressAt(
        Offset(tester.getRect(map).left + 28, tester.getRect(action()).top - 8),
      );
      await tester.pumpAndSettle();
      expect(placementCard(), findsOneWidget);
      expect(find.text('Crear hito aquí').hitTestable(), findsOneWidget);
      expect(
        tester.getCenter(placementPin()).dy,
        lessThan(tester.getTopLeft(placementCard()).dy),
      );
      expect(pickerMap(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'non immersive coordinator map also confirms or discards placement',
    (tester) async {
      await show(tester, edgeToEdge: false);
      await tester.longPressAt(
        tester.getCenter(find.byType(FlutterMap)) + const Offset(-80, -30),
      );
      await tester.pumpAndSettle();
      expect(placementCard(), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(placementPin(), findsNothing);
      expect(chosen, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
