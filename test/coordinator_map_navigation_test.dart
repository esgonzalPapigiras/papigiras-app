import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/detailbinnacleCoodinator.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/coordinator_location_toggle.dart';
import 'package:provider/provider.dart';

import 'support/map_tiles.dart';

// Isolate map navigation from the separately tested location feature. This
// service never starts a timer, changes sharing preferences or writes a point.
class _MapReviewLocationService extends LocationService {
  int initializationCalls = 0;
  bool sharing = false;
  final requests = <bool>[];

  @override
  bool get isTracking => sharing;

  @override
  Future<void> setSharingEnabled(bool enabled) async {
    requests.add(enabled);
    sharing = enabled;
    notifyListeners();
  }

  @override
  Future<void> initializeForCoordinatorSession() async {
    initializationCalls++;
  }
}

void main() {
  late _MapReviewLocationService location;
  late SharedPreferences prefs;

  setUp(() async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    addTearDown(() => HttpOverrides.global = previous);
    LabMode.useFixturesForTests(true);
    LabMapTiles.testProvider = TestMapTileProvider.new;
    LabFixtures.reset();
    SharedPreferences.setMockInitialValues({
      'userRole': 'coordinator',
      'token': 'synthetic-map-navigation-only',
      'tokenExpiry': DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String(),
      'selectedTourId': 910001,
    });
    prefs = await SharedPreferences.getInstance();
    location = _MapReviewLocationService();
  });

  tearDown(() {
    location.dispose();
    LabMapTiles.testProvider = null;
    LabMode.useFixturesForTests(false);
    LabFixtures.reset();
  });

  Map<String, Object?> sessionSnapshot() => {
    for (final key in prefs.getKeys()) key: prefs.get(key),
  };

  Future<void> showDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = TourSales.fromCoordinatorTour(
      coordinator: LabFixtures.coordinator,
      tour: LabFixtures.tour,
    );
    final tour = TourSales.fromJson({
      ...base.toJson(),
      'coordinatorId': 910001,
      'tourSalesId': 910001,
      // The public tour code is deliberately not the API's numeric ID.
      'tourCode': 'LAB-CODIGO-NO-ES-ID',
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<LocationService>.value(
        value: location,
        child: MaterialApp(home: TravelCoordinatorDashboard(login: tour)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Mapa abre la ruta compartida con la gira actual y vuelve sin cambiar sesión',
    (tester) async {
      final before = sessionSnapshot();
      await showDashboard(tester);
      final originalDashboard = tester.state(
        find.byType(TravelCoordinatorDashboard),
      );
      // The preview and immersive route keep the same trip controller.
      expect(find.byType(TripMapView), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Actividades'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('coordinator-home-open-map')));
      await tester.pumpAndSettle();

      final route = tester.widget<TraceMapFullScreen>(
        find.byType(TraceMapFullScreen),
      );
      final map = tester.widget<TripMapView>(find.byType(TripMapView));
      expect(route.tourCode, 910001);
      expect(map.controller.tourCode, 910001);
      expect(map.expanded, isTrue);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsNothing);
      expect(route.edgeToEdge, isTrue);
      expect(find.text('Llegada al hotel'), findsNothing);
      expect(find.text('Último'), findsNothing);
      expect(find.text('Hitos'), findsNothing);
      expect(find.text('3 de 3'), findsNothing);
      expect(find.byTooltip('Hito anterior'), findsNothing);
      expect(find.byTooltip('Siguiente hito'), findsNothing);
      // Move this fixture pin away from the expanded coordinator controls.
      await tester.drag(find.byType(FlutterMap), const Offset(-80, 50));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trip-pin-2')));
      await tester.pumpAndSettle();
      expect(map.controller.selectedId, 2);
      expect(find.text('Paseo por el lago'), findsOneWidget);
      final latest = tester.widget<Icon>(
        find.byKey(const ValueKey('trip-marker-fill-1')),
      );
      final selected = tester.widget<Icon>(
        find.byKey(const ValueKey('trip-marker-fill-2')),
      );
      expect(latest.color, PiloFamilyTheme.mint);
      expect(selected.color, PiloFamilyTheme.ink);
      await tester.tap(find.byTooltip('Ver lista de hitos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Llegada al hotel'));
      await tester.pumpAndSettle();
      expect(map.controller.selectedId, 1);
      expect(sessionSnapshot(), before);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(TraceMapFullScreen), findsNothing);
      expect(
        tester.state(find.byType(TravelCoordinatorDashboard)),
        same(originalDashboard),
      );
      expect(location.initializationCalls, 1);
      expect(sessionSnapshot(), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ubicación comparte el mismo estado entre preview y mapa ampliado',
    (tester) async {
      await showDashboard(tester);
      final homeService = Provider.of<LocationService>(
        tester.element(find.byType(CoordinatorLocationToggle)),
        listen: false,
      );
      expect(homeService, same(location));
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      expect(location.requests, [true]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.tap(find.byKey(const ValueKey('coordinator-home-open-map')));
      await tester.pumpAndSettle();
      expect(find.byType(TraceMapFullScreen), findsOneWidget);
      expect(find.byType(CoordinatorLocationToggle), findsOneWidget);
      final fullMapService = Provider.of<LocationService>(
        tester.element(find.byType(CoordinatorLocationToggle)),
        listen: false,
      );
      expect(fullMapService, same(homeService));
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(
        tester.getRect(find.byType(Switch)).right,
        lessThan(tester.getRect(find.text('Ubicación')).left),
      );
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      expect(location.requests, [true, false]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(TraceMapFullScreen), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(location.initializationCalls, 1);
      expect(location.requests, [true, false]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mapa familiar omite el control aunque haya un servicio de ubicación',
    (tester) async {
      await prefs.setString('userRole', 'attorney');
      location.sharing = true;
      await tester.pumpWidget(
        ChangeNotifierProvider<LocationService>.value(
          value: location,
          child: const MaterialApp(
            home: TraceMapFullScreen(tourCode: 910001, edgeToEdge: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(CoordinatorLocationToggle), findsNothing);
      expect(find.text('Ubicación'), findsNothing);
      expect(find.byTooltip('Ver lista de hitos'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(location.initializationCalls, 0);
      expect(location.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Mapa del coordinador muestra fotos y detalle con permisos del hito',
    (tester) async {
      final image = base64Encode(TileProvider.transparentImage);
      LabFixtures.photos[1] = [image, image];
      final rowsBefore = jsonEncode([
        for (final row in LabFixtures.hitos) row.toJson(),
      ]);
      final photosBefore = {
        for (final entry in LabFixtures.photos.entries)
          entry.key: List<String>.of(entry.value),
      };
      final sessionBefore = sessionSnapshot();
      await showDashboard(tester);
      await tester.tap(find.byKey(const ValueKey('coordinator-home-open-map')));
      await tester.pumpAndSettle();
      final map = tester.widget<TripMapView>(find.byType(TripMapView));
      expect(map.controller.selectedId, isNull);
      await tester.tap(find.byTooltip('Ver lista de hitos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Llegada al hotel'));
      await tester.pumpAndSettle();
      final selectedId = map.controller.selectedId;
      expect(selectedId, 1);

      await tester.tap(find.byTooltip('Ampliar tarjeta del hito'));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsNothing);
      final photos = find.byKey(const ValueKey('pilo-map-expanded-photos'));
      expect(photos, findsOneWidget);
      await tester.tap(photos);
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsOneWidget);
      await tester.tap(find.byTooltip('Foto siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar fotos'));
      await tester.pumpAndSettle();
      expect(map.controller.selectedId, selectedId);

      await tester.ensureVisible(find.text('Ver hito'));
      await tester.tap(find.text('Ver hito'));
      await tester.pumpAndSettle();
      final detail = tester.widget<DetalleBitacoraCoordScreen>(
        find.byType(DetalleBitacoraCoordScreen),
      );
      expect(detail.idHito, selectedId.toString());
      expect(detail.canModify, map.controller.selected!.source.canModify);
      expect(detail.initialLocation!.point, map.controller.selected!.position);
      expect(find.text('Llegada al hotel'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar hito'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(map.controller.selectedId, selectedId);
      expect(find.byType(DetalleBitacoraCoordScreen), findsNothing);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(TravelCoordinatorDashboard), findsOneWidget);
      expect(sessionSnapshot(), sessionBefore);
      expect(LabFixtures.photos, photosBefore);
      expect(
        jsonEncode([for (final row in LabFixtures.hitos) row.toJson()]),
        rowsBefore,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
