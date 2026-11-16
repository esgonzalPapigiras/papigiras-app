import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/maps/trip_binnacle_timeline.dart';
import 'package:papigiras_app/maps/trip_hito_sheet.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/attorney/binnacledetailFather.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/detailbinnacleCoodinator.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';

import 'support/map_tiles.dart';

class _TimelineProvider extends CoordinatorProviders {
  List<ConsolidatedTourSalesDTO> rows = List.of(LabFixtures.hitos);
  final photos = <int, List<String>>{};
  final details = <int, DetailHitoList>{};
  final detailCalls = <int, int>{};
  int binnacleCalls = 0;
  bool fail = false;
  Future<List<ConsolidatedTourSalesDTO>> Function()? pendingRows;

  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourCode) {
    binnacleCalls++;
    if (fail)
      return Future.error(StateError('PlatformException: error ficticio'));
    return pendingRows?.call() ?? Future.value(List.of(rows));
  }

  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tourId) async {
    final id = int.parse(hito);
    detailCalls[id] = (detailCalls[id] ?? 0) + 1;
    final source = rows.firstWhere((row) => row.binnacleDetailId == id);
    return details[id] ??
        DetailHitoList(
          titulo: source.binnacleTitulo,
          descripcion: source.binnacleDescripcion,
          ubicacion: source.binnacleUbicacion,
          images: photos[id] ?? [],
        );
  }

  @override
  Future<List<PositionCoordinator>> uniqueID(String tourId) async => [];
}

class _TimelineLocationService extends LocationService {
  @override
  Future<void> initializeForCoordinatorSession() async {}
}

void main() {
  late _TimelineProvider provider;
  final photo = base64Encode(TileProvider.transparentImage);

  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    LabMapTiles.testProvider = TestMapTileProvider.new;
    LabFixtures.reset();
    provider = _TimelineProvider();
    addTearDown(() {
      provider.dispose();
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

  Finder card(int id) => find.byKey(ValueKey('timeline-card-$id'));
  Finder withinCard(int id, String key) =>
      find.descendant(of: card(id), matching: find.byKey(ValueKey(key)));

  Future<void> showTimeline(
    WidgetTester tester, {
    Future<void> Function(TripMapEntry)? onOpenDetail,
    double textScale = 1,
    bool showAuthor = false,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: TripBinnacleTimeline(
            tourId: 910001,
            provider: provider,
            showAuthor: showAuthor,
            onOpenDetail: onOpenDetail ?? (_) async {},
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> expand(WidgetTester tester, int id) async {
    final target = withinCard(id, 'trip-hito-card-tap');
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ordena por fecha y hora del hito sin sustituirlas por el detalle',
    (tester) async {
      phone(tester);
      provider.rows = [
        for (final row in provider.rows)
          ConsolidatedTourSalesDTO.fromJson({
            ...row.toJson(),
            if (row.binnacleDetailId == 3) 'binnacleFecha': '',
          }),
      ];
      provider.details[1] = DetailHitoList(
        titulo: 'Llegada al hotel',
        fecha: '2040-12-31',
        hora: '23:59',
      );
      await showTimeline(tester);
      expect(
        tester.getTopLeft(card(1)).dy,
        lessThan(tester.getTopLeft(card(2)).dy),
      );
      expect(
        tester.getTopLeft(card(2)).dy,
        lessThan(tester.getTopLeft(card(3)).dy),
      );
      expect(find.textContaining('18:30'), findsOneWidget);
      expect(find.textContaining('14:30'), findsOneWidget);
      expect(find.textContaining('09:00'), findsOneWidget);
      expect(find.text('Sin fecha'), findsOneWidget);
      expect(find.textContaining('2040'), findsNothing);
      expect(find.textContaining('23:59'), findsNothing);
      expect(find.textContaining('Publicado el'), findsNothing);
      expect(provider.binnacleCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pin abre el mapa centrado en ese hito y vuelve a la misma tarjeta',
    (tester) async {
      phone(tester);
      provider.photos[2] = [photo, photo];
      await showTimeline(tester);
      await expand(tester, 2);
      final timelineState = tester.state(find.byType(TripBinnacleTimeline));
      final expandedHeight = tester.getSize(card(2)).height;
      final sourceSheet = tester.widget<TripHitoSheet>(
        find.descendant(of: card(2), matching: find.byType(TripHitoSheet)),
      );
      final pin = find.byKey(const ValueKey('timeline-map-2'));
      await tester.ensureVisible(pin);
      await tester.tap(pin);
      await tester.pumpAndSettle();
      final route = tester.widget<TraceMapFullScreen>(
        find.byType(TraceMapFullScreen),
      );
      final map = tester.widget<TripMapView>(find.byType(TripMapView));
      expect(route.initialHitoId, 2);
      expect(map.controller, same(sourceSheet.controller));
      expect(map.controller.selectedId, 2);
      final camera = MapCamera.of(
        tester.element(find.byKey(const ValueKey('trip-pin-2'))),
      );
      final target = map.controller.data!.entryById(2)!.position!;
      expect(camera.center.latitude, closeTo(target.latitude, .0000001));
      expect(camera.center.longitude, closeTo(target.longitude, .0000001));
      await tester.tap(find.byTooltip('Volver a la bitácora'));
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(TripBinnacleTimeline)),
        same(timelineState),
      );
      expect(tester.getSize(card(2)).height, closeTo(expandedHeight, .1));
      expect(provider.binnacleCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mapa con controlador propio aplica el hito inicial después de cargar',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: TraceMapFullScreen(tourCode: 1, initialHitoId: 2),
        ),
      );
      await tester.pumpAndSettle();
      final map = tester.widget<TripMapView>(find.byType(TripMapView));
      expect(map.controller.selectedId, 2);
      final camera = MapCamera.of(
        tester.element(find.byKey(const ValueKey('trip-pin-2'))),
      );
      final target = map.controller.selected!.position!;
      expect(camera.center.latitude, closeTo(target.latitude, .0000001));
      expect(camera.center.longitude, closeTo(target.longitude, .0000001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'foto alterna el tamaño y conserva carrusel sin eliminar la fila',
    (tester) async {
      phone(tester);
      provider.rows = [provider.rows.first];
      provider.photos[1] = [photo, photo, photo];
      await showTimeline(tester);
      final compactHeight = tester.getSize(card(1)).height;
      await tester.tap(withinCard(1, 'trip-photo-gallery-1'));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsNothing);
      expect(tester.getSize(card(1)).height, greaterThan(compactHeight));
      final carousel = withinCard(1, 'trip-inline-photos');
      await tester.drag(carousel, const Offset(-160, 0));
      await tester.pumpAndSettle();
      await tester.tap(withinCard(1, 'trip-inline-photo-1'));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsNothing);
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      expect(card(1), findsOneWidget);
      expect(withinCard(1, 'trip-hito-card-tap').hitTestable(), findsOneWidget);
      await tester.tap(withinCard(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, greaterThan(compactHeight));
      expect(withinCard(1, 'trip-inline-photos'), findsOneWidget);
      await tester.tap(withinCard(1, 'trip-timeline-toggle'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card(1)).height, closeTo(compactHeight, .1));
      expect(
        withinCard(1, 'trip-timeline-detail').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.customSemanticsActions?.keys.any(
                    (action) => action.label == 'Ocultar hito',
                  ) ??
                  false),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sin fotos no inventa miniaturas; ubicación ausente deshabilita su pin',
    (tester) async {
      phone(tester);
      provider.rows = [
        ConsolidatedTourSalesDTO.fromJson({
          ...provider.rows.first.toJson(),
          'binnacleLatitud': '',
          'binnacleLongitud': '',
        }),
      ];
      await showTimeline(tester);
      final pin = find.byKey(const ValueKey('timeline-map-1'));
      final button = tester.widget<IconButton>(pin);
      expect(button.onPressed, isNull);
      expect(find.byTooltip('Este hito no tiene ubicación'), findsOneWidget);
      expect(find.byType(TripPhoto), findsNothing);
      await expand(tester, 1);
      expect(find.byType(TripPhoto), findsNothing);
      expect(withinCard(1, 'trip-inline-photos'), findsNothing);
      expect(find.text('Ver más'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'errores de geocodificación se muestran como ubicación registrada',
    (tester) async {
      phone(tester, width: 320);
      const technical =
          'PlatformException(IO_ERROR, A network error occurred, null, null)';
      provider.rows = [
        ConsolidatedTourSalesDTO.fromJson({
          ...provider.rows.first.toJson(),
          'binnacleUbicacion': technical,
          'binnacleTitulo':
              'Recorrido de ejemplo con un título largo para comprobar lectura y navegación',
        }),
      ];
      provider.details[1] = DetailHitoList(
        ubicacion: technical,
        images: [photo],
      );
      await showTimeline(tester, textScale: 1.6);
      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.textContaining('IO_ERROR'), findsNothing);
      expect(find.text('Ubicación registrada'), findsOneWidget);
      await expand(tester, 1);
      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.text('Ubicación registrada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resumen ampliado queda acotado y Ver más da acceso al detalle', (
    tester,
  ) async {
    phone(tester);
    provider.rows = [provider.rows.first];
    final description = List.generate(
      12,
      (index) =>
          'Párrafo ficticio ${index + 1}: el grupo continúa su recorrido y comparte novedades de la gira.',
    ).join('\n\n');
    provider.details[1] = DetailHitoList(descripcion: description);
    var detailsOpened = 0;
    await showTimeline(tester, onOpenDetail: (_) async => detailsOpened++);
    await expand(tester, 1);
    final text = tester.widget<Text>(find.text(description));
    expect(text.maxLines, greaterThanOrEqualTo(1));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(
      find.descendant(
        of: card(1),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    expect(detailsOpened, 0);
    expect(
      tester.getSize(withinCard(1, 'trip-hito-sheet')).height,
      lessThanOrEqualTo(852 / 3),
    );
    await tester.tap(withinCard(1, 'trip-timeline-detail'));
    await tester.pumpAndSettle();
    expect(detailsOpened, 1);
    expect(provider.details[1]!.descripcion, description);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'arrastrar una tarjeta compacta desplaza la bitácora sin expandirla',
    (tester) async {
      phone(tester);
      final source = provider.rows.first;
      provider.rows = [
        for (var id = 1; id <= 8; id++)
          ConsolidatedTourSalesDTO.fromJson({
            ...source.toJson(),
            'binnacleDetailId': id,
            'binnacleTitulo': 'Hito ficticio $id',
            'binnacleHora': '${(8 + id).toString().padLeft(2, '0')}:00',
          }),
      ];
      await showTimeline(tester);
      final list = tester.widget<ListView>(
        find.byKey(const PageStorageKey('trip-timeline-910001')),
      );
      expect(list.controller!.offset, 0);
      await tester.drag(
        withinCard(8, 'trip-hito-card-tap'),
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      expect(list.controller!.offset, greaterThan(150));
      expect(find.byTooltip('Reducir hito'), findsNothing);
      expect(find.text('Ver más').hitTestable(), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('carga, error, vacío y reintento conservan mensajes útiles', (
    tester,
  ) async {
    phone(tester);
    final request = Completer<List<ConsolidatedTourSalesDTO>>();
    provider.pendingRows = () => request.future;
    await showTimeline(tester, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    request.completeError(StateError('PlatformException: error ficticio'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar la bitácora.'), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
    provider.pendingRows = null;
    provider.rows = [];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay hitos en esta gira.'), findsOneWidget);
    provider.rows = List.of(LabFixtures.hitos);
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    expect(card(1), findsOneWidget);
    await expand(tester, 1);
    final expandedHeight = tester.getSize(card(1)).height;
    provider.fail = true;
    await tester.tap(find.byTooltip('Actualizar bitácora'));
    await tester.pumpAndSettle();
    expect(card(1), findsOneWidget);
    expect(
      find.text('No pudimos actualizar los hitos. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(tester.getSize(card(1)).height, closeTo(expandedHeight, .1));
    expect(find.byTooltip('Reducir hito'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Ver más conserva canModify y refresca solo al terminar el detalle',
    (tester) async {
      phone(tester);
      provider.rows = [
        ConsolidatedTourSalesDTO.fromJson({
          ...provider.rows.first.toJson(),
          'canModify': false,
        }),
      ];
      final returned = Completer<void>();
      final opened = <TripMapEntry>[];
      await showTimeline(
        tester,
        onOpenDetail: (entry) {
          opened.add(entry);
          return returned.future;
        },
        showAuthor: true,
      );
      await expand(tester, 1);
      final expandedHeight = tester.getSize(card(1)).height;
      await tester.ensureVisible(find.text('Ver más'));
      await tester.tap(find.text('Ver más'));
      await tester.pump();
      expect(opened.single.id, 1);
      expect(opened.single.source.canModify, isFalse);
      expect(provider.binnacleCalls, 1);
      provider.rows = [
        ConsolidatedTourSalesDTO.fromJson({
          ...provider.rows.first.toJson(),
          'binnacleTitulo': 'Hito actualizado de prueba',
        }),
      ];
      returned.complete();
      await tester.pumpAndSettle();
      expect(provider.binnacleCalls, 2);
      expect(find.text('Hito actualizado de prueba'), findsOneWidget);
      expect(tester.getSize(card(1)).height, closeTo(expandedHeight, .1));
      expect(find.byTooltip('Reducir hito'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'coordinador conserva permisos y vuelve a su bitácora existente',
    (tester) async {
      phone(tester);
      final location = _TimelineLocationService();
      addTearDown(location.dispose);
      final login = TourSales.fromCoordinatorTour(
        coordinator: LabFixtures.coordinator,
        tour: LabFixtures.tour,
      );
      for (final canModify in [false, true]) {
        LabFixtures.hitos = [
          ConsolidatedTourSalesDTO.fromJson({
            ...LabFixtures.hitos.first.toJson(),
            'canModify': canModify,
          }),
        ];
        await tester.pumpWidget(
          ChangeNotifierProvider<LocationService>.value(
            value: location,
            child: MaterialApp(home: BitacoraCoordScreen(login: login)),
          ),
        );
        await tester.pumpAndSettle();
        final original = tester.state(find.byType(BitacoraCoordScreen));
        await expand(tester, 1);
        await tester.ensureVisible(find.text('Ver más'));
        await tester.tap(find.text('Ver más'));
        await tester.pumpAndSettle();
        final detail = tester.widget<DetalleBitacoraCoordScreen>(
          find.byType(DetalleBitacoraCoordScreen),
        );
        expect(detail.canModify, canModify);
        expect(detail.idHito, '1');
        expect(
          find.text('Eliminar hito'),
          canModify ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(BitacoraCoordScreen)), same(original));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'borrar un hito desde la bitácora actualiza el mapa con el mismo controlador',
    (tester) async {
      phone(tester);
      final login = TourSales.fromCoordinatorTour(
        coordinator: LabFixtures.coordinator,
        tour: LabFixtures.tour,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<LocationService>(
          create: (_) => _TimelineLocationService(),
          child: MaterialApp(home: TravelCoordinatorDashboard(login: login)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('coordinator-home-open-map')),
      );
      await tester.tap(find.byKey(const ValueKey('coordinator-home-open-map')));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<TripMapView>(find.byType(TripMapView))
          .controller;
      expect(controller.data?.entryById(1), isNotNull);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('family-tab-diary')));
      await tester.pumpAndSettle();
      final diary = tester.state(find.byType(BitacoraCoordScreen));
      await expand(tester, 1);
      await tester.ensureVisible(find.text('Ver más'));
      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Eliminar hito'));
      await tester.tap(find.text('Eliminar hito'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(BitacoraCoordScreen)), same(diary));
      expect(card(1), findsNothing);
      expect(card(2), findsOneWidget);
      expect(controller.data?.entryById(1), isNull);
      await tester.tap(find.byKey(const ValueKey('family-tab-home')));
      await tester.pumpAndSettle();
      // The current dashboard retains its embedded map preview.
      expect(find.byType(TripMapView), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('coordinator-home-open-map')),
      );
      await tester.tap(find.byKey(const ValueKey('coordinator-home-open-map')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TripMapView>(find.byType(TripMapView)).controller,
        same(controller),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'apoderado abre el detalle de lectura y vuelve sin crear otra bitácora',
    (tester) async {
      phone(tester);
      LabFixtures.hitos = [LabFixtures.hitos.first];
      await tester.pumpWidget(
        MaterialApp(home: BitacoraFatherScreen(login: LabFixtures.passenger)),
      );
      await tester.pumpAndSettle();
      final original = tester.state(find.byType(BitacoraFatherScreen));
      await expand(tester, 1);
      await tester.ensureVisible(find.text('Ver más'));
      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleBitacoraFatherScreen), findsOneWidget);
      expect(find.text('Eliminar hito'), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(BitacoraFatherScreen)), same(original));
      expect(tester.takeException(), isNull);
    },
  );
}
