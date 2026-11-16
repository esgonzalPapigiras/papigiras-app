import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/maps/trip_hito_sheet.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'support/map_tiles.dart';
import 'trip_map_nearby_navigation_test.dart' show row;

class _Provider extends CoordinatorProviders {
  final requests = <int>[];
  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourCode) async => [
    row(1, '-33.45', '-70.65'),
    row(2, '-33.451', '-70.651'),
    row(3, '-33.452', '-70.652'),
  ];
  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tourId) async {
    requests.add(int.parse(hito));
    return DetailHitoList(
      titulo: 'Hito ficticio $hito',
      descripcion: 'Texto ficticio para probar el mapa.',
      images: List.filled(3, base64Encode(TileProvider.transparentImage)),
    );
  }
}

void main() {
  late _Provider provider;
  late TripMapController controller;
  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    LabMapTiles.testProvider = TestMapTileProvider.new;
    provider = _Provider();
    controller = TripMapController(tourCode: 910001, provider: provider);
    addTearDown(() {
      controller.dispose();
      provider.dispose();
      HttpOverrides.global = previous;
      LabMode.useFixturesForTests(false);
      LabMapTiles.testProvider = null;
    });
  });
  final card = find.byKey(const ValueKey('trip-hito-card-tap'));
  final handle = find.byKey(const ValueKey('trip-hito-handle'));
  final sheet = find.byKey(const ValueKey('trip-hito-sheet'));
  Future<void> show(
    WidgetTester tester, {
    bool expanded = true,
    double width = 393,
    double textScale = 1,
    bool reduced = false,
  }) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await controller.refresh();
    controller.select(1);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: expanded
              ? TripMapView(controller: controller, expanded: true)
              : SingleChildScrollView(
                  child: TripMapView(controller: controller),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  MapCamera camera(WidgetTester tester) =>
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;
  Future<void> swipe(WidgetTester tester, {bool forward = true}) async {
    final point = tester.getTopLeft(card) + const Offset(155, 30);
    await tester.dragFrom(point, Offset(forward ? -110 : 110, 0));
    await tester.pumpAndSettle();
  }

  for (final expanded in [false, true]) {
    testWidgets(
      'swipe centers selected nearby hito in ${expanded ? 'expanded' : 'compact'} map; no prefetch',
      (tester) async {
        await show(tester, expanded: expanded);
        expect(provider.requests, [1]);
        await swipe(tester);
        expect(controller.selectedId, 2);
        expect(camera(tester).center, controller.selected!.position);
        expect(provider.requests, [1, 2]);
        await swipe(tester, forward: false);
        expect(controller.selectedId, 1);
        expect(camera(tester).center, controller.selected!.position);
        expect(provider.requests, [1, 2]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'photo swipe stays in hito, vertical handle still expands/hides; new hito collapses',
    (tester) async {
      await show(tester);
      final compactHeight = tester.getSize(sheet).height;
      await tester.tap(handle);
      await tester.pumpAndSettle();
      expect(tester.getSize(sheet).height, greaterThan(compactHeight));
      await tester.drag(
        find.byKey(const ValueKey('trip-inline-photos')),
        const Offset(-145, 0),
      );
      await tester.pumpAndSettle();
      expect(controller.selectedId, 1);
      expect(find.text('2/3'), findsOneWidget);
      await swipe(tester);
      expect(controller.selectedId, 2);
      expect(tester.getSize(sheet).height, compactHeight);
      expect(find.text('1/3'), findsOneWidget);
      await tester.drag(handle, const Offset(0, 90));
      await tester.pumpAndSettle();
      expect(tester.getSize(sheet).height, 0);
      controller.select(3);
      await tester.pumpAndSettle();
      expect(tester.getSize(sheet).height, compactHeight);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'buttons expose same navigation with large text, narrow width and reduced motion',
    (tester) async {
      await show(tester, width: 320, textScale: 2, reduced: true);
      final next = find.byKey(const ValueKey('trip-next-nearby'));
      expect(tester.getSize(next).width, greaterThanOrEqualTo(44));
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(controller.selectedId, 2);
      expect(camera(tester).center, controller.selected!.position);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'camera zoom excludes offscreen pins and does not pick unrelated locations',
    (tester) async {
      await show(tester);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      map.mapController!.move(const LatLng(0, 0), 19);
      map.options.onPositionChanged!(map.mapController!.camera, true);
      await tester.pumpAndSettle();
      final next = tester.widget<IconButton>(
        find.byKey(const ValueKey('trip-next-nearby')),
      );
      expect(next.onPressed, isNull);
      await swipe(tester);
      expect(controller.selectedId, 1);
      expect(camera(tester).center, const LatLng(0, 0));
    },
  );
  testWidgets('rapid changes then back do not queue stale camera targets', (
    tester,
  ) async {
    await show(tester);
    controller.select(2);
    controller.select(3);
    controller.select(1);
    await tester.pumpAndSettle();
    expect(controller.selectedId, 1);
    // Last selection may equal the initial pin: no stale callback may move it.
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<TripHitoSheet>(find.byType(TripHitoSheet)).entry.id,
      1,
    );
  });
}
