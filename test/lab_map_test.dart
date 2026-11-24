import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/maps/trip_hito_detail.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/utils/TraceMap.dart';

import 'support/map_tiles.dart';

class _ThumbnailRetryProvider extends CoordinatorProviders {
  var detailCalls = 0;
  var failDetail = true;

  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tourId) {
    detailCalls++;
    if (failDetail) return Future.error(StateError('Error de foto ficticio'));
    return Future.value(
      DetailHitoList(
        titulo: 'Detalle LAB',
        images: [base64Encode(TileProvider.transparentImage)],
      ),
    );
  }
}

class _BusVisibilityProvider extends CoordinatorProviders {
  final positionTours = <String>[];

  @override
  Future<List<PositionCoordinator>> uniqueID(String tourId) async {
    positionTours.add(tourId);
    return [];
  }
}

void main() {
  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    LabMapTiles.testProvider = TestMapTileProvider.new;
    LabFixtures.reset();
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      HttpOverrides.global = previous;
      LabMapTiles.testProvider = null;
      LabMode.useFixturesForTests(false);
      LabFixtures.reset();
    });
  });

  void phone(WidgetTester tester, {double width = 393, double height = 852}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Color? markerColor(WidgetTester tester, int anchorId) {
    final marker = tester.widget(
      find.byKey(ValueKey('trip-marker-fill-$anchorId')),
    );
    if (marker is Icon) return marker.color;
    return ((marker as Container).decoration! as BoxDecoration).color;
  }

  void expectCleanCard() {
    expect(find.text('Último'), findsNothing);
    expect(find.text('Último ubicado'), findsNothing);
    expect(find.text('Hitos'), findsNothing);
    expect(find.text('Hitos · último'), findsNothing);
    expect(find.text('3 de 3'), findsNothing);
    expect(find.text('2 de 3'), findsNothing);
    expect(find.byTooltip('Hito anterior'), findsNothing);
    expect(find.byTooltip('Hito siguiente'), findsNothing);
  }

  Future<void> showMap(
    WidgetTester tester, {
    bool fullscreen = false,
    double textScale = 1,
    TripMapController? controller,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: fullscreen
            ? TraceMapFullScreen(
                tourCode: 1,
                controller: controller,
                // Shared legacy-list assertions exercise coordinator access.
                coordinatorId: 910001,
              )
            : const Scaffold(
                body: SingleChildScrollView(child: TraceMap(tourCode: 1)),
              ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ambas vistas conservan pines sin número y el más reciente amarillo al seleccionar',
    (tester) async {
      phone(tester);
      for (final fullscreen in [false, true]) {
        await showMap(tester, fullscreen: fullscreen);
        final view = tester.widget<TripMapView>(find.byType(TripMapView));
        expect(view.controller.selectedId, 1); // 18:30, despite its smaller ID.
        expect(view.controller.selected?.ordinal, 3);
        expect(view.controller.data?.latestId, 1);
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.byType(PolylineLayer), findsNothing);
        expect(find.text('Llegada al hotel'), findsOneWidget);
        expectCleanCard();
        expect(markerColor(tester, 1), tripYellow);
        expect(markerColor(tester, 2), tripMint);
        expect(markerColor(tester, 3), tripMint);
        for (final id in [1, 2, 3]) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey('trip-pin-$id')),
              matching: find.byType(Text),
            ),
            findsNothing,
          );
        }
        expect(find.text('Más reciente'), findsNothing);
        expect(find.text('Hitos del viaje'), findsNothing);
        expect(find.text('3 hitos publicados'), findsNothing);
        expect(find.byTooltip('Ver lista de hitos'), findsOneWidget);
        expect(find.byTooltip('Actualizar hitos'), findsOneWidget);
        expect(find.byKey(const ValueKey('trip-pin-2')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('trip-pin-2')));
        await tester.pumpAndSettle();
        expect(view.controller.selectedId, 2);
        expect(find.text('Paseo por el lago'), findsOneWidget);
        expect(view.controller.data?.latestId, 1);
        expectCleanCard();
        expect(markerColor(tester, 1), tripYellow);
        expect(markerColor(tester, 2), tripMint);
        expect(markerColor(tester, 3), tripMint);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('ampliar y volver conserva el mismo hito y controlador', (
    tester,
  ) async {
    phone(tester);
    await showMap(tester);
    final compact = tester.widget<TripMapView>(find.byType(TripMapView));
    await tester.tap(find.byKey(const ValueKey('trip-pin-2')));
    await tester.pumpAndSettle();
    expect(compact.controller.selectedId, 2);
    await tester.tap(find.byTooltip('Ampliar mapa'));
    await tester.pumpAndSettle();
    final expanded = tester.widget<TripMapView>(find.byType(TripMapView));
    expect(expanded.expanded, isTrue);
    expect(identical(expanded.controller, compact.controller), isTrue);
    expect(expanded.controller.selectedId, 2);
    expect(find.text('Paseo por el lago'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(TraceMapFullScreen), findsNothing);
    expect(compact.controller.selectedId, 2);
    expect(find.text('Paseo por el lago'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalle y galería regresan al hito seleccionado en el mapa', (
    tester,
  ) async {
    phone(tester);
    final semantics = tester.ensureSemantics();
    try {
      final photo = base64Encode(TileProvider.transparentImage);
      LabFixtures.photos[1] = [photo, photo];
      await showMap(tester, fullscreen: true);
      final view = tester.widget<TripMapView>(find.byType(TripMapView));
      final cachedDetail = view.controller.detail(1);
      final photoRect = tester.getRect(
        find.byKey(const ValueKey('trip-photo-gallery-1')),
      );
      final titleRect = tester.getRect(find.text('Llegada al hotel'));
      // The preview belongs beside the selected hito's information, not in a
      // separate section that displaces the map.
      expect(photoRect.top, lessThan(titleRect.bottom));
      expect(photoRect.bottom, greaterThan(titleRect.top));
      expect(
        photoRect.left >= titleRect.right || photoRect.right <= titleRect.left,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('trip-photo-gallery-1')));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsNothing);
      expect(find.byKey(const ValueKey('trip-inline-photos')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trip-inline-photo-0')));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsOneWidget);
      await tester.tap(find.byTooltip('Foto siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar fotos'));
      await tester.pumpAndSettle();
      expect(view.controller.selectedId, 1);
      expect(find.byType(TripPhotoGallery), findsNothing);
      await tester.ensureVisible(find.text('Ver hito'));
      await tester.tap(find.text('Ver hito'));
      await tester.pumpAndSettle();
      expect(find.byType(TripHitoDetail), findsOneWidget);
      expect(find.text('Llegada al hotel'), findsOneWidget);
      final photoButton = find.bySemanticsLabel('Abrir foto 1 de 2');
      await tester.ensureVisible(photoButton);
      await tester.tap(photoButton);
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsOneWidget);
      expect(find.text('1 de 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Foto siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar fotos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Volver al mapa'));
      await tester.pumpAndSettle();
      expect(find.byType(TripHitoDetail), findsNothing);
      expect(find.byType(TripPhotoGallery), findsNothing);
      expect(view.controller.selectedId, 1);
      expect(identical(cachedDetail, view.controller.detail(1)), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'hitos coincidentes se eligen en lista sin desplazar coordenadas',
    (tester) async {
      phone(tester);
      LabFixtures.hitos = [
        for (final source in LabFixtures.hitos)
          ConsolidatedTourSalesDTO.fromJson({
            ...source.toJson(),
            'binnacleLatitud': '-33.4500',
            'binnacleLongitud': '-70.6600',
          }),
      ];
      await showMap(tester, fullscreen: true);
      final view = tester.widget<TripMapView>(find.byType(TripMapView));
      final cluster = find.byKey(const ValueKey('trip-cluster-2'));
      expect(cluster, findsOneWidget);
      expect(
        find.descendant(of: cluster, matching: find.text('2')),
        findsOneWidget,
      );
      expect(markerColor(tester, 1), tripYellow);
      expectCleanCard();
      await tester.tap(cluster);
      await tester.pumpAndSettle();
      expect(find.text('2 hitos del viaje'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Paseo por el lago'));
      await tester.pumpAndSettle();
      expect(view.controller.selectedId, 2);
      expect(find.text('Paseo por el lago'), findsOneWidget);
      expect(find.text('2 hitos del viaje'), findsNothing);
      expect(markerColor(tester, 1), tripYellow);
      expectCleanCard();
      expect(
        view.controller.data!.mappedEntries.every(
          (entry) =>
              entry.position!.latitude == -33.4500 &&
              entry.position!.longitude == -70.6600,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pantalla de 320 px y texto grande conserva acciones utilizables', (
    tester,
  ) async {
    phone(tester, width: 320, height: 740);
    LabFixtures.photos[1] = [base64Encode(TileProvider.transparentImage)];
    LabFixtures.hitos = [
      for (final row in LabFixtures.hitos)
        ConsolidatedTourSalesDTO.fromJson({
          ...row.toJson(),
          if (row.binnacleDetailId == 1) ...{
            'binnacleTitulo':
                'Llegada al hotel después del recorrido por el lago y el centro',
            'binnacleUbicacion':
                'Punto de encuentro del grupo, entrada principal del hotel de ejemplo',
          },
        }),
    ];
    await showMap(tester, fullscreen: true, textScale: 1.6);
    final thumbnail = find.byKey(const ValueKey('trip-photo-gallery-1'));
    await tester.ensureVisible(thumbnail);
    expect(thumbnail, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(thumbnail);
    await tester.pumpAndSettle();
    expect(find.byType(TripPhotoGallery), findsNothing);
    final inlinePhoto = find.byKey(const ValueKey('trip-inline-photo-0'));
    await tester.ensureVisible(inlinePhoto);
    await tester.tap(inlinePhoto);
    await tester.pumpAndSettle();
    expect(find.byType(TripPhotoGallery), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar fotos'));
    await tester.pumpAndSettle();
    final action = find.text('Ver hito');
    await tester.ensureVisible(action);
    expect(action, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(TripHitoDetail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vacío y coordenadas inválidas no inventan posiciones', (
    tester,
  ) async {
    phone(tester);
    final original = LabFixtures.hitos.first;
    LabFixtures.hitos = [];
    // Empty state means neither events nor a separately recorded position.
    final provider = _BusVisibilityProvider();
    final controller = TripMapController(tourCode: 1, provider: provider);
    addTearDown(() {
      controller.dispose();
      provider.dispose();
    });
    await controller.refresh();
    await showMap(tester, fullscreen: true, controller: controller);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.textContaining('El viaje comienza aquí'), findsOneWidget);
    LabFixtures.hitos = [
      ConsolidatedTourSalesDTO.fromJson({
        ...original.toJson(),
        'binnacleLatitud': 'no disponible',
        'binnacleLongitud': '',
      }),
    ];
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Sin ubicación en el mapa'), findsOneWidget);
    expect(find.text('Llegada al hotel'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-hito-card-tap')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver hito'));
    await tester.tap(find.text('Ver hito'));
    await tester.pumpAndSettle();
    expect(find.byType(TripHitoDetail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sin fechas válidas ningún marcador se presenta como el más reciente',
    (tester) async {
      phone(tester);
      LabFixtures.hitos = [
        for (final row in LabFixtures.hitos)
          ConsolidatedTourSalesDTO.fromJson({
            ...row.toJson(),
            'binnacleFecha': '',
            'binnacleHora': '',
          }),
      ];
      await showMap(tester, fullscreen: true);
      final view = tester.widget<TripMapView>(find.byType(TripMapView));
      expect(view.controller.data?.latestId, isNull);
      for (final id in [1, 2, 3]) {
        expect(markerColor(tester, id), tripMint);
        expect(
          find.descendant(
            of: find.byKey(ValueKey('trip-pin-$id')),
            matching: find.byType(Text),
          ),
          findsNothing,
        );
      }
      await tester.tap(find.byKey(const ValueKey('trip-pin-2')));
      await tester.pumpAndSettle();
      expect(view.controller.selectedId, 2);
      expect(markerColor(tester, 2), tripMint);
      expectCleanCard();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('último sin ubicación no vuelve amarillo un hito anterior', (
    tester,
  ) async {
    phone(tester);
    LabFixtures.hitos = [
      for (final row in LabFixtures.hitos)
        ConsolidatedTourSalesDTO.fromJson({
          ...row.toJson(),
          if (row.binnacleDetailId == 1) ...{
            'binnacleLatitud': '',
            'binnacleLongitud': '',
          },
        }),
    ];
    await showMap(tester, fullscreen: true);
    final view = tester.widget<TripMapView>(find.byType(TripMapView));
    expect(view.controller.data?.latestId, 1);
    expect(view.controller.data?.latestMappedId, 2);
    expect(find.byKey(const ValueKey('trip-pin-1')), findsNothing);
    expect(markerColor(tester, 2), tripMint);
    expect(markerColor(tester, 3), tripMint);
    await tester.tap(find.byTooltip('Ver lista de hitos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Llegada al hotel'));
    await tester.pumpAndSettle();
    expect(view.controller.selectedId, 1);
    expect(find.text('Sin ubicación en el mapa'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-hito-card-tap')));
    await tester.pumpAndSettle();
    expect(find.text('Ver hito'), findsOneWidget);
    expect(markerColor(tester, 2), tripMint);
    expectCleanCard();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la miniatura usa solo fotos del hito y tolera una imagen inválida',
    (tester) async {
      phone(tester);
      // Only hito 2 has an attached image. Hito 1 must never borrow it.
      LabFixtures.photos[2] = ['imagen-ficticia-no-decodificable'];
      await showMap(tester, fullscreen: true);
      final view = tester.widget<TripMapView>(find.byType(TripMapView));
      expect(view.controller.selectedId, 1);
      expect(find.byType(TripPhoto), findsNothing);
      expect(find.byKey(const ValueKey('trip-photo-gallery-1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('trip-pin-2')));
      await tester.pumpAndSettle();
      expect(view.controller.selectedId, 2);
      expect(find.byType(TripPhoto), findsOneWidget);
      expect(find.byIcon(Icons.hide_image_outlined), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trip-photo-gallery-2')));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsNothing);
      expect(find.byKey(const ValueKey('trip-inline-photos')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trip-inline-photo-0')));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsOneWidget);
      expect(find.byIcon(Icons.hide_image_outlined), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar fotos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ver lista de hitos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Llegada al hotel'));
      await tester.pumpAndSettle();
      expect(view.controller.selectedId, 1);
      expect(find.byType(TripPhoto), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mapa pequeño y ampliado no muestran botón ni ventana de créditos',
    (tester) async {
      phone(tester);
      for (final fullscreen in [false, true]) {
        await showMap(tester, fullscreen: fullscreen);
        expect(find.byTooltip('Fuentes del mapa'), findsNothing);
        expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
        expect(find.textContaining('OpenStreetMap'), findsNothing);
        await tester.pump(const Duration(seconds: 6));
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('tocar la esquina del mapa de inicio abre el mapa sin créditos', (
    tester,
  ) async {
    phone(tester);
    final controller = TripMapController(tourCode: 910001);
    await controller.refresh();
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: TripMapView(
              controller: controller,
              preview: true,
              onExpand: () => opened++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getBottomLeft(find.byType(FlutterMap)) + const Offset(24, -24),
    );
    await tester.pumpAndSettle();
    expect(opened, 1);
    await tester.pump(const Duration(seconds: 6));
    await tester.tapAt(
      tester.getBottomLeft(find.byType(FlutterMap)) + const Offset(24, -24),
    );
    await tester.pumpAndSettle();
    expect(opened, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byTooltip('Fuentes del mapa'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('desmontar el mapa no deja temporizadores pendientes', (
    tester,
  ) async {
    phone(tester);
    await showMap(tester, fullscreen: true);
    expect(find.byTooltip('Fuentes del mapa'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Flutter's test binding also rejects timers left pending after teardown.
  });

  testWidgets('reintentar una miniatura con fallo inmediato no fuga errores', (
    tester,
  ) async {
    phone(tester);
    final provider = _ThumbnailRetryProvider();
    final controller = TripMapController(tourCode: 1, provider: provider);
    addTearDown(() {
      controller.dispose();
      provider.dispose();
    });
    await controller.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripMapView(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(provider.detailCalls, 1);
    await tester.tap(find.byKey(const ValueKey('trip-hito-card-tap')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Reintentar fotografías'), findsOneWidget);
    await tester.tap(find.byTooltip('Reintentar fotografías'));
    await tester.pumpAndSettle();
    expect(provider.detailCalls, 2);
    expect(find.byTooltip('Reintentar fotografías'), findsOneWidget);
    expect(tester.takeException(), isNull);
    provider.failDetail = false;
    await tester.tap(find.byTooltip('Reintentar fotografías'));
    await tester.pumpAndSettle();
    expect(provider.detailCalls, 3);
    expect(find.byTooltip('Reintentar fotografías'), findsNothing);
    expect(find.byType(TripPhoto), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compacto y ampliado comparten lector de ubicación y pausan detrás del detalle',
    (tester) async {
      phone(tester);
      final provider = _BusVisibilityProvider();
      final controller = TripMapController(
        tourCode: 910001,
        provider: provider,
      );
      addTearDown(() {
        controller.dispose();
        provider.dispose();
      });
      await controller.refresh();
      expect(provider.positionTours, isEmpty);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SingleChildScrollView(
                child: TripMapView(
                  controller: controller,
                  onExpand: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TraceMapFullScreen(
                        tourCode: 910001,
                        controller: controller,
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
      final sharedBus = controller.bus;
      expect(provider.positionTours, ['910001']);
      await tester.pump(sharedBus.pollInterval);
      await tester.pumpAndSettle();
      expect(provider.positionTours, ['910001', '910001']);
      await tester.tap(find.byKey(const ValueKey('trip-pin-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ampliar mapa'));
      await tester.pumpAndSettle();
      final expanded = tester.widget<TripMapView>(find.byType(TripMapView));
      expect(expanded.controller, same(controller));
      expect(expanded.controller.bus, same(sharedBus));
      expect(controller.selectedId, 2);
      final afterExpand = provider.positionTours.length;
      await tester.pump(sharedBus.pollInterval);
      await tester.pumpAndSettle();
      expect(provider.positionTours, hasLength(afterExpand + 1));
      await tester.tap(find.byKey(const ValueKey('trip-hito-card-tap')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ver hito'));
      await tester.tap(find.text('Ver hito'));
      await tester.pumpAndSettle();
      expect(find.byType(TripHitoDetail), findsOneWidget);
      final whileHidden = provider.positionTours.length;
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(provider.positionTours, hasLength(whileHidden));
      await tester.tap(find.byTooltip('Volver al mapa'));
      await tester.pumpAndSettle();
      expect(controller.selectedId, 2);
      expect(controller.bus, same(sharedBus));
      expect(provider.positionTours, hasLength(whileHidden + 1));
      await tester.tap(find.byTooltip('Volver al inicio'));
      await tester.pumpAndSettle();
      final backToCompact = provider.positionTours.length;
      await tester.pump(sharedBus.pollInterval);
      await tester.pumpAndSettle();
      expect(provider.positionTours, hasLength(backToCompact + 1));
      await tester.pumpWidget(const SizedBox.shrink());
      final afterDispose = provider.positionTours.length;
      await tester.pump(const Duration(minutes: 1));
      expect(provider.positionTours, hasLength(afterDispose));
      expect(tester.takeException(), isNull);
    },
  );
}
