import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/maps/trip_hito_markers.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

import 'support/map_tiles.dart';

class _MarkersProvider extends CoordinatorProviders {
  List<ConsolidatedTourSalesDTO> rows = [];

  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourCode) async =>
      rows;
}

ConsolidatedTourSalesDTO _hito(
  int id, {
  String time = '09:00',
  String date = '2026-11-05',
  String latitude = '0',
  String longitude = '0',
}) => ConsolidatedTourSalesDTO(
  binnacleDetailId: id,
  binnacleTitulo: 'Hito ficticio $id',
  binnacleDescripcion: 'Contenido de prueba',
  binnacleUbicacion: 'Lugar de prueba',
  binnacleNotaCierre: '',
  binnacleLatitud: latitude,
  binnacleLongitud: longitude,
  binnacleHora: time,
  binnacleFecha: date,
  author: null,
  canModify: false,
);

void main() {
  late _MarkersProvider provider;
  late TripMapController controller;
  late MapController camera;
  late List<List<TripMapEntry>> selectedGroups;

  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    provider = _MarkersProvider();
    controller = TripMapController(tourCode: 910001, provider: provider);
    camera = MapController();
    selectedGroups = [];
    addTearDown(() {
      controller.dispose();
      provider.dispose();
      camera.dispose();
      HttpOverrides.global = previous;
      LabMode.useFixturesForTests(false);
      LabFixtures.reset();
    });
  });

  Future<void> showMarkers(
    WidgetTester tester, {
    double zoom = 11,
    double width = 740,
    double textScale = 1,
    LatLng center = const LatLng(0, .005),
    bool pilo = false,
  }) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await controller.refresh();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => FlutterMap(
              mapController: camera,
              options: MapOptions(initialCenter: center, initialZoom: zoom),
              children: [
                TileLayer(tileProvider: TestMapTileProvider()),
                TripHitoMarkers(
                  controller: controller,
                  pilo: pilo,
                  onSelectGroup: selectedGroups.add,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color? fill(WidgetTester tester, int id) {
    final value = tester.widget(find.byKey(ValueKey('trip-marker-fill-$id')));
    if (value is Icon) return value.color;
    return ((value as Container).decoration! as BoxDecoration).color;
  }

  void expectPinWithoutNumber(int id) {
    final pin = find.byKey(ValueKey('trip-pin-$id'));
    expect(pin, findsOneWidget);
    expect(
      find.descendant(of: pin, matching: find.byIcon(Icons.location_on)),
      findsWidgets,
    );
    expect(find.descendant(of: pin, matching: find.byType(Text)), findsNothing);
  }

  testWidgets('el grupo muestra cantidad y excluye el último pin amarillo', (
    tester,
  ) async {
    provider.rows = [
      _hito(1, time: '18:30', latitude: '.004', longitude: '.005'),
      _hito(2, time: '12:00'),
      _hito(3, time: '10:00', longitude: '.001'),
      _hito(4, longitude: '.002'),
    ];
    await showMarkers(tester);
    final cluster = find.byKey(const ValueKey('trip-cluster-2'));
    expect(cluster, findsOneWidget);
    expect(
      find.bySemanticsLabel('3 hitos en esta zona. Toca para elegir.'),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cluster, matching: find.text('3')),
      findsOneWidget,
    );
    expect(fill(tester, 2), tripMint);
    expect(fill(tester, 1), tripYellow);
    expectPinWithoutNumber(1);
    await tester.tap(cluster);
    expect(selectedGroups, hasLength(1));
    expect(selectedGroups.single.map((entry) => entry.id), [4, 3, 2]);
    expect(selectedGroups.single.any((entry) => entry.id == 1), isFalse);
    controller.select(3);
    await tester.pumpAndSettle();
    expect(fill(tester, 1), tripYellow);
    expect(fill(tester, 2), tripMint);
    await tester.tap(find.byKey(const ValueKey('trip-pin-1')));
    await tester.pumpAndSettle();
    expect(controller.selectedId, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'acercar el mapa separa el grupo en pines verdes sin numeración',
    (tester) async {
      provider.rows = [
        _hito(1, time: '18:30', latitude: '.004', longitude: '.005'),
        _hito(2, time: '12:00'),
        _hito(3, longitude: '.01'),
      ];
      await showMarkers(tester);
      final originalPositions = {
        for (final entry in controller.data!.entries) entry.id: entry.position,
      };
      expect(find.byKey(const ValueKey('trip-cluster-2')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      camera.move(const LatLng(0, .005), 16);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-cluster-2')), findsNothing);
      for (final id in [1, 2, 3]) {
        expectPinWithoutNumber(id);
        expect(fill(tester, id), id == 1 ? tripYellow : tripMint);
      }
      await tester.tap(find.byKey(const ValueKey('trip-pin-3')));
      await tester.pumpAndSettle();
      expect(controller.selectedId, 3);
      expect(fill(tester, 1), tripYellow);
      expect({
        for (final entry in controller.data!.entries) entry.id: entry.position,
      }, originalPositions);
      camera.move(const LatLng(0, .005), 11);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-cluster-2')), findsOneWidget);
      expectPinWithoutNumber(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'coincidentes conservan coordenadas y ambos controles se pueden tocar',
    (tester) async {
      provider.rows = [
        _hito(1, time: '18:30'),
        _hito(2, time: '12:00'),
        _hito(3),
      ];
      await showMarkers(
        tester,
        width: 320,
        textScale: 1.6,
        center: const LatLng(0, 0),
      );
      final cluster = find.byKey(const ValueKey('trip-cluster-2'));
      final latest = find.byKey(const ValueKey('trip-pin-1'));
      expect(
        find.descendant(of: cluster, matching: find.text('2')),
        findsOneWidget,
      );
      expect(tester.getSize(cluster).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(latest).width, greaterThanOrEqualTo(44));
      expect(tester.getRect(cluster).overlaps(tester.getRect(latest)), isFalse);
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(markers, hasLength(2));
      expect(
        markers.every((marker) => marker.point == const LatLng(0, 0)),
        isTrue,
      );
      await tester.tap(cluster);
      expect(selectedGroups, hasLength(1));
      expect(selectedGroups.single.map((entry) => entry.id), [3, 2]);
      controller.select(3);
      await tester.pumpAndSettle();
      await tester.tap(latest);
      await tester.pumpAndSettle();
      expect(controller.selectedId, 1);
      expect(selectedGroups, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fechas desconocidas no generan un último amarillo ni números en pines',
    (tester) async {
      provider.rows = [
        _hito(1, date: '', latitude: '.004', longitude: '.005'),
        _hito(2, date: ''),
        _hito(3, date: '', longitude: '.01'),
      ];
      await showMarkers(tester, zoom: 16);
      expect(controller.data!.latestId, isNull);
      for (final id in [1, 2, 3]) {
        expectPinWithoutNumber(id);
        expect(fill(tester, id), tripMint);
      }
      expect(find.text('?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('último sin coordenadas no colorea amarillo otro hito anterior', (
    tester,
  ) async {
    provider.rows = [
      _hito(1, time: '18:30', latitude: ''),
      _hito(2, time: '12:00'),
      _hito(3, longitude: '.01'),
    ];
    await showMarkers(tester, zoom: 16);
    expect(controller.data!.latestId, 1);
    expect(find.byKey(const ValueKey('trip-pin-1')), findsNothing);
    for (final id in [2, 3]) {
      expectPinWithoutNumber(id);
      expect(fill(tester, id), tripMint);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pilo conserva las ubicaciones y el total de un grupo al seleccionar un hito',
    (tester) async {
      provider.rows = [
        _hito(1, time: '18:30', longitude: '.006'),
        _hito(2, time: '12:00', longitude: '.005'),
        _hito(3, longitude: '.004'),
      ];
      await showMarkers(
        tester,
        zoom: 9,
        width: 320,
        textScale: 1.6,
        pilo: true,
      );
      final cluster = find.byKey(const ValueKey('trip-cluster-1'));
      expect(cluster, findsOneWidget);
      expect(fill(tester, 1), PiloFamilyTheme.paper);
      expect(
        find.descendant(of: cluster, matching: find.text('3')),
        findsOneWidget,
      );
      final position = tester.getCenter(cluster);
      await tester.tap(cluster);
      expect(selectedGroups.single.map((entry) => entry.id), [3, 2, 1]);

      controller.select(1);
      await tester.pumpAndSettle();
      expect(cluster, findsOneWidget);
      expect(fill(tester, 1), PiloFamilyTheme.ink);
      expect(
        find.descendant(of: cluster, matching: find.text('3')),
        findsOneWidget,
      );
      expect(tester.getCenter(cluster), position);

      controller.clearSelection();
      await tester.pumpAndSettle();
      expect(fill(tester, 1), PiloFamilyTheme.paper);
      expect(tester.getCenter(cluster), position);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pilo muestra pines sin fecha ni hora sobre el mapa', (
    tester,
  ) async {
    provider.rows = [
      _hito(1, date: '2026-11-06T23:30:00-03:00', time: ''),
      _hito(2, date: '2026-11-07', time: '', longitude: '.0075'),
      _hito(3, date: '', time: '', longitude: '.015'),
    ];
    await showMarkers(
      tester,
      zoom: 16,
      width: 1000,
      center: const LatLng(0, .0075),
      pilo: true,
    );
    for (final id in [1, 2, 3]) {
      expectPinWithoutNumber(id);
      expect(
        find.bySemanticsLabel(RegExp('Hito: Hito ficticio $id\\.')),
        findsOneWidget,
      );
    }
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('Pilo conserva los pines y sus anclajes al acercar o arrastrar', (
    tester,
  ) async {
    const positions = {
      1: LatLng(0, 0),
      2: LatLng(.018, 0),
      3: LatLng(.0455, 0),
      4: LatLng(.0635, 0),
    };
    const center = LatLng(.03175, 0);
    provider.rows = [
      for (final entry in positions.entries)
        _hito(
          entry.key,
          time: '09:0${entry.key}',
          latitude: entry.value.latitude.toString(),
        ),
    ];
    await showMarkers(tester, zoom: 10, width: 320, center: center, pilo: true);

    Finder pin(int id) => find.byKey(ValueKey('trip-pin-$id'));
    void expectAnchored() {
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .map((marker) => marker.point),
        unorderedEquals(positions.values),
      );
      for (final entry in positions.entries) {
        expectPinWithoutNumber(entry.key);
        final expected = camera.camera.latLngToScreenPoint(entry.value);
        final center = tester.getCenter(pin(entry.key));
        expect(center.dx, closeTo(expected.x, 1));
        expect(tester.getRect(pin(entry.key)).bottom, closeTo(expected.y, 1));
      }
    }

    expectAnchored();
    camera.move(center, 11);
    await tester.pumpAndSettle();
    expectAnchored();

    final beforeDrag = camera.camera.center;
    await tester.dragFrom(const Offset(70, 330), const Offset(48, -42));
    await tester.pumpAndSettle();
    expect(camera.camera.center, isNot(beforeDrag));
    expect(camera.camera.zoom, 11);
    expectAnchored();

    camera.move(center, 13);
    await tester.pumpAndSettle();
    expectAnchored();
    const id = 1;
    final position = tester.getCenter(pin(id));
    await tester.tap(pin(id));
    await tester.pumpAndSettle();
    expect(controller.selectedId, id);
    expect(fill(tester, id), PiloFamilyTheme.ink);
    expect(tester.getCenter(pin(id)), position);
    expectAnchored();

    camera.move(center, 10);
    await tester.pumpAndSettle();
    expectAnchored();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pilo conserva los anclajes al seleccionar pines cercanos', (
    tester,
  ) async {
    const first = LatLng(0, 0);
    const second = LatLng(.00011, .0002);
    provider.rows = [
      _hito(1, time: '09:00'),
      _hito(2, time: '09:10', latitude: '.00011', longitude: '.0002'),
    ];
    await showMarkers(tester, zoom: 19, width: 320, center: first, pilo: true);
    final firstPin = find.byKey(const ValueKey('trip-pin-1'));
    final secondPin = find.byKey(const ValueKey('trip-pin-2'));
    expect(firstPin, findsOneWidget);
    expect(secondPin, findsOneWidget);
    expect(fill(tester, 1), PiloFamilyTheme.mint);
    expect(fill(tester, 2), PiloFamilyTheme.mint);
    final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(
      layer.markers.map((marker) => marker.point),
      unorderedEquals([first, second]),
    );
    final firstPosition = tester.getCenter(firstPin);
    final secondPosition = tester.getCenter(secondPin);
    controller.select(2);
    await tester.pumpAndSettle();
    expect(fill(tester, 1), PiloFamilyTheme.mint);
    expect(fill(tester, 2), PiloFamilyTheme.ink);
    expect(tester.getCenter(firstPin), firstPosition);
    expect(tester.getCenter(secondPin), secondPosition);
    expect(tester.takeException(), isNull);
  });
}
