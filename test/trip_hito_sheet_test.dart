import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/maps/trip_hito_detail.dart';
import 'package:papigiras_app/maps/trip_hito_sheet.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

import 'support/map_tiles.dart';

class _SheetProvider extends CoordinatorProviders {
  List<ConsolidatedTourSalesDTO> rows = List.of(LabFixtures.hitos);
  final calls = <int, int>{};
  Future<DetailHitoList> Function(int id)? load;

  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourCode) async =>
      rows;

  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tourId) {
    final id = int.parse(hito);
    calls[id] = (calls[id] ?? 0) + 1;
    return load?.call(id) ?? Future.value(DetailHitoList());
  }
}

void main() {
  late _SheetProvider provider;
  late TripMapController controller;
  final photo = base64Encode(TileProvider.transparentImage);
  final sheet = find.byKey(const ValueKey('trip-hito-sheet'));
  final handle = find.byKey(const ValueKey('trip-hito-handle'));
  final card = find.byKey(const ValueKey('trip-hito-card-tap'));
  final photos = find.byKey(const ValueKey('trip-inline-photos'));

  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    LabMapTiles.testProvider = TestMapTileProvider.new;
    LabFixtures.reset();
    provider = _SheetProvider();
    controller = TripMapController(tourCode: 1, provider: provider);
    addTearDown(() {
      controller.dispose();
      provider.dispose();
      HttpOverrides.global = previous;
      LabMapTiles.testProvider = null;
      LabMode.useFixturesForTests(false);
      LabFixtures.reset();
    });
  });

  Future<void> showSheet(
    WidgetTester tester, {
    double width = 393,
    double height = 852,
    double textScale = 1,
    bool reduceMotion = false,
    bool piloMap = false,
    double bottomInset = 0,
    bool settle = true,
    VoidCallback? onMapTap,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await controller.refresh();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                key: const ValueKey('map-surface'),
                behavior: HitTestBehavior.opaque,
                onTap: onMapTap,
                child: const ColoredBox(color: Colors.lightGreen),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => TripHitoSheet(
                    controller: controller,
                    entry: controller.selected!,
                    selectionRevision: controller.selectionRevision,
                    maxHeight: height / 3,
                    piloMap: piloMap,
                    bottomInset: bottomInset,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> expand(WidgetTester tester) async {
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  Future<void> down(WidgetTester tester) async {
    final initialHeight = tester.getSize(sheet).height;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getSize(sheet).height, lessThan(initialHeight));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'miniatura amplía primero; carrusel y detalle vuelven al mismo hito',
    (tester) async {
      provider.load = (id) async => DetailHitoList(
        titulo: 'Llegada al hotel',
        descripcion: 'Descripción ficticia del recorrido.',
        images: List.filled(5, photo),
      );
      await showSheet(tester);
      final compactHeight = tester.getSize(sheet).height;
      expect(photos, findsNothing);
      expect(find.text('Ver hito'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('trip-photo-gallery-1')));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsNothing);
      expect(tester.getSize(sheet).height, greaterThan(compactHeight));
      expect(tester.getSize(sheet).height, lessThanOrEqualTo(852 / 3));
      expect(photos, findsOneWidget);
      final horizontal = tester.widget<PageView>(
        find.descendant(of: photos, matching: find.byType(PageView)),
      );
      expect(horizontal.scrollDirection, Axis.horizontal);
      final target = find.byKey(const ValueKey('trip-inline-photo-4'));
      for (var index = 0; index < 4; index++) {
        await tester.drag(photos, const Offset(-155, 0));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      final gallery = tester.widget<TripPhotoGallery>(
        find.byType(TripPhotoGallery),
      );
      expect(gallery.initialIndex, 4);
      expect(find.text('5 de 5'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar fotos'));
      await tester.pumpAndSettle();
      expect(controller.selectedId, 1);
      expect(photos, findsOneWidget);
      expect(target.hitTestable(), findsOneWidget);
      expect(provider.calls, {1: 1});
      final details = find.text('Ver hito');
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.byType(TripHitoDetail), findsOneWidget);
      await tester.tap(find.byTooltip('Volver al mapa'));
      await tester.pumpAndSettle();
      expect(controller.selectedId, 1);
      expect(photos, findsOneWidget);
      expect(provider.calls, {1: 1});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deslizar asa baja ampliada a compacta y oculta; selección siempre reaparece compacta',
    (tester) async {
      var mapTaps = 0;
      await showSheet(tester, onMapTap: () => mapTaps++);
      final compactHeight = tester.getSize(sheet).height;
      await expand(tester);
      expect(tester.getSize(sheet).height, greaterThan(compactHeight));
      await down(tester);
      expect(tester.getSize(sheet).height, closeTo(compactHeight, 0.1));
      await down(tester);
      expect(card.hitTestable(), findsNothing);
      await tester.tapAt(const Offset(196, 820));
      expect(mapTaps, 1);
      expect(controller.selectedId, 1);
      controller.select(1);
      await tester.pumpAndSettle();
      expect(card.hitTestable(), findsOneWidget);
      expect(tester.getSize(sheet).height, closeTo(compactHeight, 0.1));
      await expand(tester);
      controller.select(2);
      await tester.pumpAndSettle();
      expect(find.text('Paseo por el lago'), findsOneWidget);
      expect(find.text('Ver hito'), findsNothing);
      await down(tester);
      expect(card.hitTestable(), findsNothing);
      controller.select(3);
      await tester.pumpAndSettle();
      expect(card.hitTestable(), findsOneWidget);
      expect(find.text('Ver hito'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('contenido sin fotos amplía y el asa permite volver a compacta', (
    tester,
  ) async {
    await showSheet(tester);
    final compactHeight = tester.getSize(sheet).height;
    await tester.tap(find.text('Llegada al hotel'));
    await tester.pumpAndSettle();
    expect(tester.getSize(sheet).height, greaterThan(compactHeight));
    expect(find.byType(TripPhoto), findsNothing);
    expect(photos, findsNothing);
    expect(find.text('Ver hito'), findsOneWidget);
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(tester.getSize(sheet).height, closeTo(compactHeight, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalle anterior que termina tarde no mezcla fotos ni texto', (
    tester,
  ) async {
    final oldDetail = Completer<DetailHitoList>();
    final currentDetail = Completer<DetailHitoList>();
    provider.load = (id) => id == 1 ? oldDetail.future : currentDetail.future;
    await showSheet(tester, settle: false);
    controller.select(2);
    await tester.pump();
    currentDetail.complete(
      DetailHitoList(
        descripcion: 'Descripción del hito seleccionado',
        images: [photo],
      ),
    );
    await tester.pumpAndSettle();
    await expand(tester);
    oldDetail.complete(
      DetailHitoList(
        descripcion: 'Texto anterior que no debe aparecer',
        images: [photo, photo, photo],
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.selectedId, 2);
    expect(find.text('Texto anterior que no debe aparecer'), findsNothing);
    expect(find.byKey(const ValueKey('trip-inline-photo-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-inline-photo-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('trip-inline-photo-0')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TripPhotoGallery>(find.byType(TripPhotoGallery)).images,
      hasLength(1),
    );
    expect(provider.calls, {1: 1, 2: 1});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'error fotográfico conserva resumen y reintenta solo por acción explícita',
    (tester) async {
      var fail = true;
      provider.load = (id) => fail
          ? Future.error(StateError('Fallo ficticio de fotografías'))
          : Future.value(DetailHitoList(images: [photo]));
      await showSheet(tester);
      expect(find.text('Llegada al hotel'), findsOneWidget);
      expect(provider.calls, {1: 1});
      await expand(tester);
      final retry = find.byTooltip('Reintentar fotografías');
      expect(retry, findsOneWidget);
      expect(find.byType(TripPhoto), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(provider.calls, {1: 1});
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(provider.calls, {1: 2});
      expect(retry, findsOneWidget);
      fail = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(provider.calls, {1: 3});
      expect(retry, findsNothing);
      expect(find.byKey(const ValueKey('trip-inline-photo-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pilo mantiene Ver hito visible con texto ampliado y conserva los estados',
    (tester) async {
      final pending = Completer<DetailHitoList>();
      provider.load = (_) => pending.future;
      await showSheet(
        tester,
        width: 320,
        height: 568,
        textScale: 2,
        piloMap: true,
        bottomInset: 34,
        settle: false,
      );
      await tester.pump();
      final action = find.text('Ver hito');
      expect(action, findsNothing);

      await tester.tap(handle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.getSize(sheet).height, lessThanOrEqualTo(568 / 3));

      pending.completeError(StateError('Error de foto ficticio'));
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      expect(find.byTooltip('Reintentar fotografías'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(handle);
      await tester.pumpAndSettle();
      expect(action, findsNothing);
      await tester.tap(handle);
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(TripHitoDetail), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pilo fija el botón mientras se desplazan las fotos y la descripción',
    (tester) async {
      provider.load = (_) async => DetailHitoList(
        titulo:
            'Llegada al hotel después del recorrido por el lago y la ciudad',
        descripcion: List.filled(
          20,
          'Descripción ficticia del recorrido. ',
        ).join(),
        images: List.filled(3, photo),
      );
      await showSheet(
        tester,
        width: 320,
        height: 568,
        textScale: 2,
        piloMap: true,
        bottomInset: 34,
      );
      await tester.tap(handle);
      await tester.pumpAndSettle();

      final action = find.text('Ver hito');
      expect(action.hitTestable(), findsOneWidget);
      final initialButtonRect = tester.getRect(action);
      final scrollable = find
          .descendant(of: card, matching: find.byType(Scrollable))
          .first;
      final scroll = tester.state<ScrollableState>(scrollable).position;
      expect(scroll.maxScrollExtent, greaterThan(30));

      await tester.drag(scrollable, const Offset(0, -44));
      await tester.pumpAndSettle();
      expect(scroll.pixels, greaterThan(0));
      expect(tester.getRect(action), initialButtonRect);
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.getSize(sheet).height, lessThanOrEqualTo(568 / 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('320 px y texto 1,6 conservan contenido y acceso a fotos y detalle', (
    tester,
  ) async {
    const longTitle =
        'Llegada al hotel después del recorrido por el lago y el centro de la ciudad';
    const longDescription =
        'Descripción ficticia extensa del recorrido, el punto de encuentro y las actividades del grupo. ';
    provider.rows = [
      for (final row in provider.rows)
        ConsolidatedTourSalesDTO.fromJson({
          ...row.toJson(),
          if (row.binnacleDetailId == 1) ...{
            'binnacleTitulo': longTitle,
            'binnacleUbicacion':
                'Entrada principal del hotel junto a la plaza del centro de ejemplo',
          },
        }),
    ];
    provider.load = (id) async => DetailHitoList(
      titulo: longTitle,
      descripcion: List.filled(20, longDescription).join(),
      images: [photo],
    );
    await showSheet(tester, width: 320, height: 740, textScale: 1.6);
    expect(tester.takeException(), isNull);
    await expand(tester);
    expect(tester.getSize(sheet).height, lessThanOrEqualTo(740 / 3));
    expect(tester.takeException(), isNull);
    final inlinePhoto = find.byKey(const ValueKey('trip-inline-photo-0'));
    await tester.ensureVisible(inlinePhoto);
    await tester.tap(inlinePhoto);
    await tester.pumpAndSettle();
    expect(find.byType(TripPhotoGallery), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar fotos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver hito'));
    await tester.tap(find.text('Ver hito'));
    await tester.pumpAndSettle();
    expect(find.byType(TripHitoDetail), findsOneWidget);
    final fullDescription = find.text(
      List.filled(20, longDescription).join().trim(),
    );
    await tester.scrollUntilVisible(
      fullDescription,
      250,
      scrollable: find
          .descendant(
            of: find.byType(TripHitoDetail),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(fullDescription, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reducir movimiento cambia de tamaño sin una animación pendiente',
    (tester) async {
      await showSheet(tester, reduceMotion: true);
      await tester.tap(card);
      await tester.pump();
      expect(tester.getSize(sheet).height, closeTo(852 / 3, 0.1));
      expect(find.text('Ver hito'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tarjeta oculta deja arrastrar el mapa y retocar su punto la recupera',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await controller.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripMapView(controller: controller, expanded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await down(tester);
      expect(card.hitTestable(), findsNothing);
      final mapElement = tester.element(
        find.byKey(const ValueKey('trip-pin-1')),
      );
      final centerBefore = MapCamera.of(mapElement).center;
      await tester.dragFrom(const Offset(180, 650), const Offset(55, -20));
      await tester.pumpAndSettle();
      expect(
        MapCamera.of(
          tester.element(find.byKey(const ValueKey('trip-pin-1'))),
        ).center,
        isNot(centerBefore),
      );
      await tester.tap(find.byKey(const ValueKey('trip-pin-1')));
      await tester.pumpAndSettle();
      expect(controller.selectedId, 1);
      expect(card.hitTestable(), findsOneWidget);
      expect(find.text('Ver hito'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
