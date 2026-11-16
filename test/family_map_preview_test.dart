import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math show Point, atan2, pi;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/maps/pilo_map_area_carousel.dart';
import 'package:papigiras_app/maps/trip_hito_detail.dart';
import 'package:papigiras_app/maps/trip_hito_sheet.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/utils/page_navigation.dart';
import 'package:papigiras_app/voice/voice_note_metadata.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'support/map_tiles.dart';
import 'trip_map_nearby_navigation_test.dart' show row;

class _Provider extends CoordinatorProviders {
  bool empty = false, fail = false, separateHitos = false;
  List<ConsolidatedTourSalesDTO>? mapRows;
  List<String> photos = [];
  VoiceNoteMetadata? firstHitoVoice;
  int reads = 0, details = 0;
  Future<List<PositionCoordinator>> Function()? readPositions;

  @override
  Future<List<PositionCoordinator>> uniqueID(String code) async =>
      await readPositions?.call() ?? [];
  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String code) async {
    reads++;
    if (fail) throw StateError('synthetic failure');
    if (empty) return [];
    return mapRows ??
        [
          row(1, '-33.45', '-70.65'),
          row(2, '-33.451', separateHitos ? '-70.675' : '-70.651'),
        ];
  }

  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tour) async {
    details++;
    return DetailHitoList(
      titulo: 'Hito ficticio LAB',
      descripcion: 'Prueba',
      images: photos,
      voiceNote: hito == '1' ? firstHitoVoice : null,
    );
  }
}

void main() {
  late _Provider provider;
  late TripMapController controller;
  setUp(() {
    provider = _Provider();
    controller = TripMapController(tourCode: 910001, provider: provider);
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMapTiles.testProvider = TestMapTileProvider.new;
    addTearDown(() {
      controller.dispose();
      provider.dispose();
      HttpOverrides.global = previous;
      LabMapTiles.testProvider = null;
    });
  });
  Future<void> show(
    WidgetTester tester, {
    bool edgeToEdge = false,
    bool disableAnimations = true,
    Size phoneSize = const Size(402, 874),
    EdgeInsets safePadding = EdgeInsets.zero,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await controller.refresh();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            padding: safePadding,
            viewPadding: safePadding,
            textScaler: textScaler,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: SizedBox(
                width: 362,
                height: 300,
                child: TripMapView(
                  controller: controller,
                  preview: true,
                  onExpand: () => Navigator.of(context).push(
                    buildPapiRoute(
                      TraceMapFullScreen(
                        tourCode: 910001,
                        controller: controller,
                        edgeToEdge: edgeToEdge,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'preview fills bounds, hides map chrome and details, opens same controller and keeps selection',
    (tester) async {
      await show(tester);
      expect(tester.getSize(find.byType(FlutterMap)), const Size(362, 300));
      expect(find.byType(TripMapActions), findsNothing);
      expect(find.byTooltip('Ampliar mapa'), findsNothing);
      expect(find.byTooltip('Ver lista de hitos'), findsNothing);
      expect(provider.details, 0);
      expect(provider.reads, 1);
      final before = controller.selectedId;
      final target = find.bySemanticsLabel(
        'Mapa del viaje. Abrir mapa completo',
      );
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byType(TraceMapFullScreen), findsOneWidget);
      expect(find.byTooltip('Ver lista de hitos'), findsNothing);
      expect(
        tester
            .widget<TraceMapFullScreen>(find.byType(TraceMapFullScreen))
            .controller,
        same(controller),
      );
      expect(controller.selectedId, before);
      expect(provider.reads, 1);
      controller.select(1);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Volver al inicio'));
      await tester.pumpAndSettle();
      expect(controller.selectedId, 1);
      expect(provider.reads, 1);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final panBeforeBus in [false, true]) {
    testWidgets(
      'Pilo keeps bus location and heading when reports stop, pan before: $panBeforeBus',
      (tester) async {
        final pending = Completer<List<PositionCoordinator>>();
        provider.readPositions = () => pending.future;
        await show(tester, edgeToEdge: true);
        await tester.tap(
          find.bySemanticsLabel('Mapa del viaje. Abrir mapa completo'),
        );
        await tester.pumpAndSettle();
        final map = find.byType(FlutterMap);
        final camera = tester.widget<FlutterMap>(map).mapController!;
        final busMarker = find.byKey(const ValueKey('trip-bus-marker'));
        final halo = find.byKey(const ValueKey('trip-bus-pulse'));
        final heading = find.byKey(const ValueKey('trip-bus-heading'));
        final illustration = find.byKey(
          const ValueKey('trip-bus-illustration'),
        );
        final lastLocation = find.byKey(
          const ValueKey('pilo-bus-last-location'),
        );
        final lastLocationChip = find.byKey(
          const ValueKey('pilo-bus-last-location-chip'),
        );
        final grayscale = find.ancestor(
          of: illustration,
          matching: find.byType(ColorFiltered),
        );
        LatLng busAnchor() => tester
            .widget<MarkerLayer>(
              find.ancestor(of: busMarker, matching: find.byType(MarkerLayer)),
            )
            .markers
            .single
            .point;
        double busRotation() {
          final transform = tester.widget<Transform>(heading).transform;
          return math.atan2(transform.storage[1], transform.storage[0]);
        }

        PositionCoordinator report(LatLng position, DateTime time) =>
            PositionCoordinator(
              coordinatorId: 1,
              coordinatorName: 'Coordinador de prueba',
              coordinatorLastname: 'Ejemplo',
              latitude: position.latitude,
              longitude: position.longitude,
              recordedAt: time.toUtc(),
            );

        const latestHito = LatLng(-33.45, -70.65);
        const bus = LatLng(-33.458, -70.664);
        expect(camera.camera.center, latestHito);
        expect(camera.camera.zoom, 13.25);
        expect(busMarker, findsNothing);

        if (panBeforeBus) {
          await tester.drag(map, const Offset(72, 0));
          await tester.pumpAndSettle();
          expect(camera.camera.center, isNot(latestHito));
        }
        final previousCenter = camera.camera.center;
        final recentReport = DateTime.now().subtract(
          const Duration(seconds: 10),
        );
        pending.complete([
          report(bus, recentReport.subtract(const Duration(seconds: 20))),
        ]);
        await tester.pumpAndSettle();
        expect(camera.camera.center, panBeforeBus ? previousCenter : bus);
        expect(busMarker, findsOneWidget);
        expect(halo, findsOneWidget);
        expect(heading, findsNothing);
        expect(lastLocation, findsNothing);
        expect(grayscale, findsNothing);
        final image = tester.widget<Image>(illustration).image;
        final imageProvider = image is ResizeImage
            ? image.imageProvider
            : image;
        expect(
          imageProvider,
          isA<AssetImage>().having(
            (asset) => asset.assetName,
            'assetName',
            'assets/maps/pilo-minibus.png',
          ),
        );
        expect(busAnchor(), bus);

        final onlineCenter = camera.camera.center;
        final onlineZoom = camera.camera.zoom;
        const movedBus = LatLng(-33.458, -70.661);
        provider.readPositions = () async => [report(movedBus, recentReport)];
        await controller.bus.refresh();
        await tester.pumpAndSettle();
        expect(busAnchor(), movedBus);
        expect(camera.camera.center, onlineCenter);
        expect(camera.camera.zoom, onlineZoom);
        final lastRotation = busRotation();
        expect(lastRotation, closeTo(math.pi / 2, .01));
        final onlineIconCenter = tester.getCenter(illustration);

        // A temporary failure makes the same observation stale. Neither the
        // artwork nor its geographic anchor may jump when the label appears.
        provider.readPositions = () async =>
            throw StateError('Fallo de ubicación ficticio');
        await controller.bus.refresh();
        await tester.pumpAndSettle();
        expect(busMarker, findsOneWidget);
        expect(halo, findsNothing);
        expect(grayscale, findsOneWidget);
        expect(busAnchor(), movedBus);
        expect(busRotation(), lastRotation);
        expect(camera.camera.center, onlineCenter);
        expect(camera.camera.zoom, onlineZoom);
        expect(
          (tester.getCenter(illustration) - onlineIconCenter).distance,
          lessThan(.01),
        );
        expect(
          tester.widget<Text>(lastLocation).data,
          anyOf('Hace <1 min', 'Ayer'),
        );
        expect(
          find.descendant(
            of: lastLocationChip,
            matching: find.byIcon(Icons.schedule_rounded),
          ),
          findsOneWidget,
        );

        final mapRect = tester.getRect(map);
        final labelGap =
            tester.getTopLeft(lastLocationChip).dy -
            tester.getBottomLeft(busMarker).dy;
        void expectLabelAttached() {
          final iconCenter = tester.getCenter(illustration);
          final chipRect = tester.getRect(lastLocationChip);
          final coordinateOnScreen = camera.camera.latLngToScreenPoint(
            movedBus,
          );
          expect(busAnchor(), movedBus);
          expect(
            iconCenter.dx,
            closeTo(mapRect.left + coordinateOnScreen.x, .01),
          );
          expect(
            iconCenter.dy,
            closeTo(mapRect.top + coordinateOnScreen.y, .01),
          );
          expect(chipRect.center.dx, closeTo(iconCenter.dx, .01));
          expect(
            chipRect.top - tester.getBottomLeft(busMarker).dy,
            closeTo(labelGap, .01),
          );
          expect(chipRect.width, lessThanOrEqualTo(136));
        }

        expect(labelGap, inInclusiveRange(0, 12));
        expectLabelAttached();
        camera.move(movedBus, onlineZoom + 1);
        await tester.pumpAndSettle();
        expectLabelAttached();

        final widerViewZoom = onlineZoom - 3;
        camera.move(
          movedBus,
          widerViewZoom,
          offset: Offset(mapRect.width / 2 - 65, 0),
        );
        await tester.pumpAndSettle();
        expectLabelAttached();
        await tester.dragFrom(
          mapRect.center - const Offset(80, 80),
          const Offset(44, 0),
        );
        await tester.pumpAndSettle();
        expect(camera.camera.zoom, widerViewZoom);
        final distanceToEdge =
            mapRect.right - tester.getCenter(illustration).dx;
        expect(distanceToEdge, inInclusiveRange(0, 55));
        expectLabelAttached();

        final olderReport = DateTime(2020, 3, 4, 16, 20);
        provider.readPositions = () async => [report(bus, olderReport)];
        await controller.bus.refresh();
        await tester.pumpAndSettle();
        expect(busAnchor(), movedBus);
        expect(busRotation(), lastRotation);

        // An empty response clears the current observation. An older report
        // can still be shown when it is the only known one.
        provider.readPositions = () async => [];
        await controller.bus.refresh();
        await tester.pumpAndSettle();
        expect(busMarker, findsNothing);
        provider.readPositions = () async => [report(bus, olderReport)];
        await controller.bus.refresh();
        await tester.pumpAndSettle();
        expect(busMarker, findsOneWidget);
        expect(halo, findsNothing);
        final olderLabel = tester.widget<Text>(lastLocation).data;
        final locale = MaterialLocalizations.of(tester.element(lastLocation));
        expect(olderLabel, locale.formatCompactDate(olderReport));
        await tester.tap(lastLocationChip);
        await tester.pumpAndSettle();
        expect(find.text('Última ubicación conocida'), findsOneWidget);
        expect(find.text('04/03/2020 a las 16:20'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsLabel('Mapa del viaje. Abrir mapa completo'),
        );
        await tester.pumpAndSettle();
        final reopened = tester.widget<FlutterMap>(map).mapController!.camera;
        expect(reopened.center, latestHito);
        expect(reopened.zoom, 13.25);
        expect(busMarker, findsOneWidget);
        expect(busAnchor(), bus);
        expect(tester.widget<Text>(lastLocation).data, olderLabel);
      },
    );
  }

  Finder pin(int id) => find.byKey(ValueKey('trip-pin-$id'));
  Finder pinIcon(int id) => find.byKey(ValueKey('trip-marker-fill-$id'));

  Map<String, LatLng> renderedAnchors(WidgetTester tester) => {
    for (final layer in tester.widgetList<MarkerLayer>(
      find.byType(MarkerLayer),
    ))
      for (final marker in layer.markers)
        if (marker.child is Semantics)
          ((marker.child as Semantics).child!.key! as ValueKey<String>).value:
              marker.point,
  };

  Finder cluster(int count) => find.ancestor(
    of: find.text('$count'),
    matching: find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('trip-cluster-');
    }),
  );

  Future<MapController> openPiloMap(
    WidgetTester tester, {
    bool disableAnimations = true,
    Size phoneSize = const Size(402, 874),
    EdgeInsets safePadding = EdgeInsets.zero,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await show(
      tester,
      edgeToEdge: true,
      disableAnimations: disableAnimations,
      phoneSize: phoneSize,
      safePadding: safePadding,
      textScaler: textScaler,
    );
    await tester.tap(
      find.bySemanticsLabel('Mapa del viaje. Abrir mapa completo'),
    );
    await tester.pumpAndSettle();
    return tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
  }

  testWidgets(
    'Pilo cluster taps zoom and split a large geographic group in stages',
    (tester) async {
      const origin = LatLng(-33.45, -70.65);
      const distance = DistanceHaversine(roundResult: false);
      final northOuter = distance.offset(origin, 24960, 0);
      final northInner = distance.offset(origin, 16640, 0);
      final south = distance.offset(origin, 20800, 180);
      provider.mapRows = [
        for (var id = 1; id <= 35; id++)
          row(
            id,
            (id <= 9
                    ? northOuter
                    : id <= 18
                    ? northInner
                    : south)
                .latitude
                .toString(),
            (origin.longitude + (id == 2 ? 1 : id) * .000001).toString(),
          ),
      ];
      final camera = await openPiloMap(tester, disableAnimations: false);
      camera.move(origin, 6);
      await tester.pumpAndSettle();
      expect(cluster(35), findsOneWidget);
      expect(pin(1), findsNothing);

      await tester.tap(cluster(35));
      await tester.pumpAndSettle();
      expect(camera.camera.zoom, 7);
      expect(cluster(35), findsNothing);
      expect(cluster(18), findsOneWidget);
      expect(cluster(17), findsOneWidget);
      expect(pin(1), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(cluster(18));
      await tester.pumpAndSettle();
      expect(camera.camera.zoom, 8);
      expect(cluster(18), findsOneWidget);
      await tester.tap(cluster(18));
      await tester.pumpAndSettle();
      expect(camera.camera.zoom, 9);
      expect(cluster(18), findsNothing);
      expect(cluster(9), findsNWidgets(2));
      expect(cluster(17), findsOneWidget);

      camera.move(origin, 9.875);
      await tester.pumpAndSettle();
      expect(cluster(9), findsNWidgets(2));
      expect(cluster(17), findsOneWidget);
      double visibleWidthMeters() {
        final viewport = camera.camera.nonRotatedSize;
        return distance(
          camera.camera.pointToLatLng(math.Point(0, viewport.y / 2)),
          camera.camera.pointToLatLng(math.Point(viewport.x, viewport.y / 2)),
        );
      }

      expect(visibleWidthMeters(), greaterThan(55000));
      const detailZoom = 10.0;
      camera.move(origin, detailZoom);
      await tester.pumpAndSettle();
      expect(visibleWidthMeters(), inExclusiveRange(50000, 55000));
      final anchoredPositions = renderedAnchors(tester);
      final allIds = [for (var id = 1; id <= 35; id++) id];
      expect(
        anchoredPositions.keys,
        unorderedEquals(allIds.map((id) => 'trip-pin-$id')),
      );
      for (final id in allIds.skip(2)) {
        expect(
          anchoredPositions['trip-pin-$id'],
          controller.data!.entryById(id)!.position,
        );
      }
      expect(cluster(9), findsNothing);
      expect(cluster(17), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MarkerLayer),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        controller.data!.entryById(1)!.position,
        controller.data!.entryById(2)!.position,
      );
      final separation = tester.getCenter(pin(2)) - tester.getCenter(pin(1));
      final count = find.byKey(const ValueKey('pilo-map-area-count'));
      expect(tester.widget<Text>(count).data, '35 hitos en esta zona');
      await tester.tap(count);
      await tester.pumpAndSettle();
      final carousel = find.byType(PiloMapAreaCarousel);
      expect(
        tester
            .widget<PiloMapAreaCarousel>(carousel)
            .entries
            .map((entry) => entry.id),
        unorderedEquals(allIds),
      );
      final initialSelection = controller.selectedId;
      await tester.tap(find.byKey(const ValueKey('pilo-map-area-next')));
      await tester.pumpAndSettle();
      expect(controller.selectedId, isNot(initialSelection));
      expect(renderedAnchors(tester), anchoredPositions);
      expect(
        tester.widget<Icon>(pinIcon(controller.selectedId!)).color,
        PiloFamilyTheme.ink,
      );

      await tester.drag(
        find.byKey(const ValueKey('pilo-map-area-handle')),
        const Offset(0, 90),
      );
      await tester.pumpAndSettle();
      camera.move(distance.offset(origin, 1000, 90), detailZoom);
      await tester.pumpAndSettle();
      expect(renderedAnchors(tester), anchoredPositions);
      expect(
        (tester.getCenter(pin(2)) - tester.getCenter(pin(1)) - separation)
            .distance,
        lessThan(.01),
      );

      for (final zoom in [11.0, 14.0, 17.0, 19.0]) {
        camera.move(origin, zoom);
        await tester.pumpAndSettle();
        expect(renderedAnchors(tester), anchoredPositions);
      }

      camera.move(origin, 6);
      await tester.pumpAndSettle();
      expect(cluster(35), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final longitude in ['-70.65', '-70.650001']) {
    testWidgets(
      'Pilo keeps overlapping GPS markers anchored and accessible in the carousel ($longitude)',
      (tester) async {
        const origin = LatLng(-33.45, -70.65);
        final second = LatLng(-33.45, double.parse(longitude));
        provider.mapRows = [
          row(1, '-33.45', '-70.65'),
          row(2, '-33.45', longitude),
        ];
        final camera = await openPiloMap(tester);
        camera.move(origin, 9);
        await tester.pumpAndSettle();
        expect(cluster(2), findsOneWidget);

        await tester.tap(cluster(2));
        await tester.pumpAndSettle();
        expect(camera.camera.zoom, 10);
        expect(cluster(2), findsNothing);
        expect(pin(1), findsOneWidget);
        expect(pin(2), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        final anchors = renderedAnchors(tester);
        expect(controller.data!.entryById(1)!.position, origin);
        expect(controller.data!.entryById(2)!.position, second);
        if (origin == second) {
          const distance = DistanceHaversine(roundResult: false);
          expect(anchors.values.toSet(), hasLength(2));
          for (final anchor in anchors.values) {
            expect(distance(anchor, origin), lessThanOrEqualTo(15));
          }
        } else {
          expect(anchors, {'trip-pin-1': origin, 'trip-pin-2': second});
        }

        final initialSeparation =
            tester.getCenter(pin(1)) - tester.getCenter(pin(2));
        await tester.tap(find.byKey(const ValueKey('pilo-map-area-count')));
        await tester.pumpAndSettle();
        final carousel = find.byType(PiloMapAreaCarousel);
        final cards = tester.widget<PiloMapAreaCarousel>(carousel).entries;
        expect(cards.map((entry) => entry.id), unorderedEquals([1, 2]));
        final selected = controller.selectedId!;
        final other = cards.singleWhere((entry) => entry.id != selected).id;
        expect(
          tester.widget<Icon>(pinIcon(selected)).color,
          PiloFamilyTheme.ink,
        );
        expect(tester.widget<Icon>(pinIcon(other)).color, PiloFamilyTheme.mint);
        final nextOrPrevious = cards.first.id == selected ? 'next' : 'previous';
        await tester.tap(find.byKey(ValueKey('pilo-map-area-$nextOrPrevious')));
        await tester.pumpAndSettle();
        expect(controller.selectedId, other);
        expect(carousel, findsOneWidget);
        expect(tester.widget<Icon>(pinIcon(other)).color, PiloFamilyTheme.ink);
        expect(
          tester.widget<Icon>(pinIcon(selected)).color,
          PiloFamilyTheme.mint,
        );
        final separation = tester.getCenter(pin(1)) - tester.getCenter(pin(2));
        expect((separation - initialSeparation).distance, lessThan(.01));

        expect(renderedAnchors(tester), anchors);

        camera.move(const LatLng(-33.4505, -70.6505), 10);
        await tester.pumpAndSettle();
        expect(renderedAnchors(tester), anchors);
        expect(
          ((tester.getCenter(pin(1)) - tester.getCenter(pin(2))) - separation)
              .distance,
          lessThan(.01),
        );
        camera.move(origin, 19);
        await tester.pumpAndSettle();
        expect(renderedAnchors(tester), anchors);

        camera.move(origin, 9);
        await tester.pumpAndSettle();
        expect(cluster(2), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Pilo counts individual hitos in the visible area', (
    tester,
  ) async {
    await show(tester, edgeToEdge: true);
    await tester.tap(
      find.bySemanticsLabel('Mapa del viaje. Abrir mapa completo'),
    );
    await tester.pumpAndSettle();
    const countKey = ValueKey('pilo-map-area-count');
    expect(
      tester.widget<Text>(find.byKey(countKey)).data,
      '2 hitos en esta zona',
    );

    final camera = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    camera.move(const LatLng(-33.45, -70.65), 19);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(countKey)).data,
      '1 hito en esta zona',
    );
    expect(find.text('12 nov · 10:00'), findsNothing);
    camera.move(const LatLng(-33.46, -70.65), 19);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(countKey)).data,
      '0 hitos en esta zona',
    );

    camera.move(const LatLng(-33.45, -70.65), 19);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(countKey));
    await tester.pumpAndSettle();
    const carouselKey = ValueKey('pilo-map-area-carousel');
    const handleKey = ValueKey('pilo-map-area-handle');
    expect(find.byKey(carouselKey), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Hito ficticio 1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(carouselKey),
        matching: find.text('12 nov · 10:00'),
      ),
      findsOneWidget,
    );
    expect(find.text('Hito ficticio 2'), findsNothing);
    expect(find.byKey(countKey), findsNothing);
    await tester.drag(find.byKey(handleKey), const Offset(0, 90));
    await tester.pumpAndSettle();
    expect(find.byKey(countKey), findsOneWidget);

    camera.move(const LatLng(-33.45, -70.65), 14);
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(countKey), const Offset(0, -66));
    await tester.pumpAndSettle();
    expect(find.byKey(carouselKey), findsOneWidget);
    expect(controller.selectedId, 1);
    final centerBeforePaging = camera.camera.center;
    final zoomBeforePaging = camera.camera.zoom;
    final pages = find.byKey(const ValueKey('pilo-map-area-pages'));
    await tester.drag(pages, const Offset(-308, 0));
    await tester.pumpAndSettle();
    expect(controller.selectedId, 2);
    expect(find.text('Hito ficticio 2'), findsOneWidget);
    expect(tester.widget<Icon>(pinIcon(2)).color, PiloFamilyTheme.ink);
    expect(camera.camera.center, centerBeforePaging);
    expect(camera.camera.zoom, zoomBeforePaging);
    await tester.tap(find.byKey(const ValueKey('pilo-map-area-previous')));
    await tester.pumpAndSettle();
    expect(controller.selectedId, 1);
    expect(tester.widget<Icon>(pinIcon(1)).color, PiloFamilyTheme.ink);
    expect(camera.camera.center, centerBeforePaging);
    expect(camera.camera.zoom, zoomBeforePaging);
    await tester.tapAt(
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(32, 320),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(carouselKey), findsNothing);
    expect(find.byKey(countKey), findsOneWidget);
    expect(controller.selectedId, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final fromPin in [true, false]) {
    testWidgets(
      'Pilo opens the same compact carousel from ${fromPin ? 'a pin' : 'the area count'}',
      (tester) async {
        const first = LatLng(-33.45, -70.65);
        const phoneSize = Size(393, 852);
        const safePadding = EdgeInsets.only(top: 59, bottom: 34);
        provider.mapRows = [
          row(1, '-33.45', '-70.65'),
          row(2, '-33.451', '-70.654'),
        ];
        provider.photos = List.filled(
          2,
          base64Encode(TileProvider.transparentImage),
        );
        provider.firstHitoVoice = const VoiceNoteMetadata(
          id: 'nota-prueba',
          durationMs: 12000,
          sizeBytes: 25000,
        );
        final camera = await openPiloMap(
          tester,
          phoneSize: phoneSize,
          safePadding: safePadding,
        );
        camera.move(first, 16);
        await tester.pumpAndSettle();

        final map = find.byType(FlutterMap);
        final carousel = find.byType(PiloMapAreaCarousel);
        final handle = find.byKey(const ValueKey('pilo-map-area-handle'));
        final detail = find.byKey(const ValueKey('pilo-map-area-detail'));
        final count = find.byKey(const ValueKey('pilo-map-area-count'));
        final initialId = fromPin ? 2 : 1;
        final secondId = fromPin ? 1 : 2;

        void expectDetailAction() {
          expect(find.text('Ver hito').hitTestable(), findsOneWidget);
          expect(
            tester.getBottomRight(detail).dy,
            lessThanOrEqualTo(tester.getBottomRight(carousel).dy),
          );
        }

        expect(tester.getSize(map), phoneSize);
        expect(carousel, findsNothing);
        expect(find.byTooltip('Ver lista de hitos'), findsNothing);
        expect(find.byTooltip('Acercar mapa'), findsOneWidget);
        expect(provider.details, 0);
        expect(pin(1).hitTestable(), findsOneWidget);
        expect(pin(2).hitTestable(), findsOneWidget);

        Future<void> open() async {
          final center = camera.camera.center;
          await tester.tap(fromPin ? pin(initialId) : count);
          await tester.pumpAndSettle();
          expect(carousel, findsOneWidget);
          expect(find.byType(TripHitoSheet), findsNothing);
          expect(find.byType(BottomSheet), findsNothing);
          expect(controller.selectedId, initialId);
          expect(
            tester.widget<PiloMapAreaCarousel>(carousel).selectedId,
            initialId,
          );
          expect(
            tester
                .widget<PiloMapAreaCarousel>(carousel)
                .entries
                .map((entry) => entry.id),
            unorderedEquals([1, 2]),
          );
          if (fromPin) expect(camera.camera.center, center);
          expectDetailAction();
        }

        await open();
        final compact = tester.getSize(carousel).height;
        expect(compact, lessThanOrEqualTo(phoneSize.height / 4));
        final card = find.byKey(ValueKey('pilo-map-area-hito-$initialId'));
        final photo = find.descendant(
          of: card,
          matching: find.byType(TripPhoto),
        );
        final title = find.descendant(
          of: card,
          matching: find.text('Hito ficticio $initialId'),
        );
        final date = find.descendant(
          of: card,
          matching: find.text('${initialId == 1 ? 12 : 11} nov · 10:00'),
        );
        final bounds = tester.getRect(card);
        for (final content in [photo, title, date]) {
          final rect = tester.getRect(content);
          expect(rect.isEmpty, isFalse);
          expect(rect.intersect(bounds), rect);
        }
        expect(
          tester.getBottomRight(detail).dy,
          lessThanOrEqualTo(phoneSize.height - safePadding.bottom),
        );
        expect(provider.details, 1);

        final centerBeforePaging = camera.camera.center;
        final zoomBeforePaging = camera.camera.zoom;
        await tester.drag(handle, const Offset(0, -100));
        await tester.pumpAndSettle();
        final expanded = tester.getSize(carousel).height;
        expect(expanded, greaterThan(compact * 1.5));
        expect(expanded, lessThan(phoneSize.height * .6));
        expectDetailAction();
        final expandedCard = find.byKey(
          ValueKey('pilo-map-area-hito-$initialId'),
        );
        final photoPages = find.descendant(
          of: expandedCard,
          matching: find.byKey(const ValueKey('pilo-map-expanded-photos')),
        );
        final expandedDescription = find.byKey(
          ValueKey('pilo-map-expanded-description-$initialId'),
        );
        final voice = find.byKey(
          const ValueKey('pilo-map-expanded-voice-1-nota-prueba'),
        );
        expect(tester.getSize(photoPages).height, greaterThan(120));
        await tester.drag(photoPages, const Offset(-260, 0));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: expandedCard, matching: find.text('2/2')),
          findsOneWidget,
        );
        expect(expandedDescription, findsOneWidget);
        expect(voice, initialId == 1 ? findsOneWidget : findsNothing);
        expect(controller.selectedId, initialId);

        await tester.tap(
          find.byKey(
            ValueKey('pilo-map-area-${fromPin ? 'previous' : 'next'}'),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.selectedId, secondId);
        expect(voice, secondId == 1 ? findsOneWidget : findsNothing);
        expect(tester.getSize(carousel).height, expanded);
        expect(camera.camera.center, centerBeforePaging);
        expect(camera.camera.zoom, zoomBeforePaging);

        await tester.tap(detail);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TripHitoDetail>(find.byType(TripHitoDetail)).entry.id,
          secondId,
        );
        await tester.tap(find.byTooltip('Volver al mapa'));
        await tester.pumpAndSettle();
        expect(tester.getSize(carousel).height, expanded);

        expectDetailAction();
        await tester.drag(handle, const Offset(0, 90));
        await tester.pumpAndSettle();
        expect(tester.getSize(carousel).height, compact);
        await tester.drag(handle, const Offset(0, 90));
        await tester.pumpAndSettle();
        expect(carousel, findsNothing);
        expect(controller.selectedId, isNull);

        camera.move(first, 16);
        await tester.pumpAndSettle();
        await open();
        expect(tester.getSize(carousel).height, compact);
        await tester.tap(handle);
        await tester.pumpAndSettle();
        expect(tester.getSize(carousel).height, expanded);
        await tester.tap(handle);
        await tester.pumpAndSettle();
        expect(tester.getSize(carousel).height, compact);
        await tester.drag(handle, const Offset(0, 90));
        await tester.pumpAndSettle();
        expect(carousel, findsNothing);
        expect(count, findsOneWidget);
        expect(controller.selectedId, isNull);

        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();
        expect(tester.getSize(map), const Size(362, 300));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Pilo keeps the carousel action reachable with larger text', (
    tester,
  ) async {
    const longTitle =
        'Encuentro ficticio con todas las familias al terminar el recorrido';
    final first = row(1, '-33.45', '-70.65');
    provider.mapRows = [
      ConsolidatedTourSalesDTO.fromJson({
        ...first.toJson(),
        'binnacleTitulo': longTitle,
        'binnacleUbicacion': 'Entrada norte del parque ficticio',
      }),
    ];
    provider.photos = [base64Encode(TileProvider.transparentImage)];
    await openPiloMap(
      tester,
      phoneSize: const Size(393, 852),
      safePadding: const EdgeInsets.only(top: 59, bottom: 34),
      textScaler: const TextScaler.linear(1.6),
    );
    await tester.tap(pin(1));
    await tester.pumpAndSettle();

    final carousel = find.byType(PiloMapAreaCarousel);
    final action = find.byKey(const ValueKey('pilo-map-area-detail'));
    final mapHeight = tester.getSize(find.byType(FlutterMap)).height;
    expect(tester.getSize(carousel).height, lessThanOrEqualTo(mapHeight / 3));
    expect(
      find.descendant(of: carousel, matching: find.text(longTitle)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: carousel, matching: find.byType(TripPhoto)),
      findsOneWidget,
    );
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(TripHitoDetail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  PositionCoordinator homeReport(LatLng point, {bool offline = false}) =>
      PositionCoordinator(
        coordinatorId: 910001,
        coordinatorName: 'Coordinador',
        coordinatorLastname: 'Demo',
        latitude: point.latitude,
        longitude: point.longitude,
        recordedAt: DateTime.now().toUtc().subtract(
          offline ? const Duration(days: 1) : const Duration(seconds: 10),
        ),
      );

  Future<MapController> showHomePreview(
    WidgetTester tester,
    double width,
  ) async {
    await controller.refresh();
    await tester.pumpWidget(
      MaterialApp(
        theme: PiloFamilyTheme.theme(ThemeData()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: 150,
              child: TripMapView(controller: controller, preview: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
  }

  double visibleWidth(MapController map) {
    final center = map.camera.center;
    final bounds = map.camera.visibleBounds;
    return const DistanceHaversine(roundResult: false)(
      LatLng(center.latitude, bounds.west),
      LatLng(center.latitude, bounds.east),
    );
  }

  for (final latitude in [-27.0, -33.45, -41.0]) {
    for (final offline in [false, true]) {
      testWidgets(
        'home opens a regional view centered on the ${offline ? 'offline' : 'online'} bus at latitude $latitude',
        (tester) async {
          final bus = LatLng(latitude, -70.65);
          provider.readPositions = () async => [
            homeReport(bus, offline: offline),
          ];
          final width = offline ? 362.0 : 720.0;
          final camera = await showHomePreview(tester, width);
          expect(tester.getSize(find.byType(FlutterMap)).width, width);
          expect(camera.camera.center, bus);
          // Measure rendered geographic bounds, not the zoom formula.
          expect(visibleWidth(camera), closeTo(300000, 2000));
          expect(find.byKey(const ValueKey('trip-bus-marker')), findsOneWidget);
          expect(provider.details, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final panBeforeBus in [false, true]) {
    testWidgets(
      'home late offline bus read respects user camera: $panBeforeBus',
      (tester) async {
        final pending = Completer<List<PositionCoordinator>>();
        provider.readPositions = () => pending.future;
        final camera = await showHomePreview(tester, 362);
        // With no reported bus yet, use the most recent geolocated hito.
        expect(camera.camera.center, const LatLng(-33.45, -70.65));
        expect(visibleWidth(camera), closeTo(300000, 2000));
        if (panBeforeBus) {
          await tester.drag(find.byType(FlutterMap), const Offset(70, 0));
          await tester.pumpAndSettle();
        }
        final previous = camera.camera.center;
        const bus = LatLng(-41.0, -71.3);
        pending.complete([homeReport(bus, offline: true)]);
        await tester.pumpAndSettle();
        expect(camera.camera.center, panBeforeBus ? previous : bus);
        if (!panBeforeBus) expect(visibleWidth(camera), closeTo(300000, 2000));

        final settled = camera.camera.center;
        final zoom = camera.camera.zoom;
        provider.readPositions = () async => [
          homeReport(const LatLng(-41.1, -71.4)),
        ];
        await controller.bus.refresh();
        await tester.pumpAndSettle();
        await controller.refresh();
        await tester.pumpAndSettle();
        expect(camera.camera.center, settled);
        expect(camera.camera.zoom, zoom);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'home without bus keeps regional fallback after empty first read',
    (tester) async {
      final camera = await showHomePreview(tester, 320);
      expect(camera.camera.center, const LatLng(-33.45, -70.65));
      expect(visibleWidth(camera), closeTo(300000, 2000));
      expect(find.byKey(const ValueKey('trip-bus-marker')), findsNothing);
    },
  );

  testWidgets(
    'Pilo preview pans and zooms inside Home without an information button',
    (tester) async {
      await controller.refresh();
      await tester.pumpWidget(
        MaterialApp(
          theme: PiloFamilyTheme.theme(ThemeData()),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 260,
                    child: TripMapView(controller: controller, preview: true),
                  ),
                  const SizedBox(height: 700),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = find.byType(FlutterMap);
      final camera = tester.widget<FlutterMap>(map).mapController!;
      final home = tester.state<ScrollableState>(find.byType(Scrollable).first);
      final start = camera.camera.center;
      await tester.drag(map, const Offset(64, 0));
      await tester.pumpAndSettle();
      expect(camera.camera.center.longitude, isNot(start.longitude));
      await tester.drag(map, const Offset(0, -54));
      await tester.pumpAndSettle();
      expect(camera.camera.center.latitude, isNot(start.latitude));
      expect(home.position.pixels, 0);
      expect(provider.details, 0);
      final center = tester.getCenter(map);
      final zoom = camera.camera.zoom;
      final left = await tester.startGesture(center - const Offset(30, 0));
      final right = await tester.startGesture(center + const Offset(30, 0));
      for (var i = 1; i <= 3; i++) {
        await left.moveTo(center - Offset(30 + i * 20, 0));
        await right.moveTo(center + Offset(30 + i * 20, 0));
        await tester.pump();
      }
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      expect(camera.camera.zoom, greaterThan(zoom));

      expect(find.byTooltip('Fuentes del mapa'), findsNothing);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
      expect(find.textContaining('OpenStreetMap'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'bounded ${fail ? 'error' : 'empty'} preview opens full map for refresh',
      (tester) async {
        provider.empty = true;
        provider.fail = fail;
        await show(tester);
        expect(find.byType(FlutterMap), findsNothing);
        expect(provider.details, 0);
        await tester.tap(
          find.text(
            fail
                ? 'No pudimos cargar el mapa'
                : 'Aún no hay ubicaciones registradas',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TraceMapFullScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
