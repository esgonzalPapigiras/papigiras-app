import 'support/visual_capture.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/special_diet_passengers.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/listPassenger.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/ranking/coordinator_ranking_screen.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';
import 'package:provider/provider.dart';

import 'support/map_tiles.dart';

class _HomeLocationService extends LocationService {
  int initializations = 0;

  // Home navigation does not start GPS, timers, or the location transport.
  @override
  Future<void> initializeForCoordinatorSession() async {
    initializations++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _HomeLocationService location;
  late TourSales tour;
  late SharedPreferences prefs;

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final manjari = FontLoader('Manjari')
      ..addFont(rootBundle.load('assets/fonts/Manjari-Regular.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    await Future.wait([manjari.load(), inter.load(), icons.load()]);
  });

  setUp(() async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    addTearDown(() => HttpOverrides.global = previous);
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    LabMapTiles.testProvider = TestMapTileProvider.new;
    SharedPreferences.setMockInitialValues({
      'userRole': 'coordinator',
      'selectedTourId': 910001,
      'token': 'synthetic-home-navigation-only',
      'tokenExpiry': DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String(),
    });
    prefs = await SharedPreferences.getInstance();
    location = _HomeLocationService();
    final base = TourSales.fromCoordinatorTour(
      coordinator: LabFixtures.coordinator,
      tour: LabFixtures.tour,
    );
    tour = TourSales.fromJson({
      ...base.toJson(),
      'coordinatorId': 910001,
      'tourSalesId': 910001,
      'tourCode': 'LAB-CODIGO-NO-ES-ID',
    });
  });

  tearDown(() {
    location.dispose();
    LabMapTiles.testProvider = null;
    LabMode.useFixturesForTests(false);
    LabFixtures.reset();
  });

  Map<String, Object?> session() => {
    for (final key in prefs.getKeys()) key: prefs.get(key),
  };

  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<LocationService>.value(
        value: location,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('coordinator-home-capture'),
            child: TravelCoordinatorDashboard(login: tour),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final button = find.byKey(ValueKey(key));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  final destinations = <String, Type>{
    'home-passenger-list': ListPassengerCoordScreen,
    'family-tab-documents': DocumentCoordScreen,
    'home-new-hito': HitoAddCoordScreen,
    'home-action-count': CountDownCoordScreen,
  };

  for (final destination in destinations.entries) {
    captureTest(
      '${destination.key} opens its existing tool for the active tour',
      (tester) async {
        final before = session();
        final hitosBefore = jsonEncode([
          for (final hito in LabFixtures.hitos) hito.toJson(),
        ]);
        await show(tester);
        final originalHome = tester.state(
          find.byType(TravelCoordinatorDashboard),
        );
        await tapKey(tester, destination.key);
        expect(find.byType(destination.value), findsOneWidget);
        // Every destination must receive the actual tour ID, not its public code.
        if (destination.value == ListPassengerCoordScreen) {
          expect(
            tester
                .widget<ListPassengerCoordScreen>(
                  find.byType(destination.value),
                )
                .login
                .tourSalesId,
            910001,
          );
          expect(find.text('Ficha médica'), findsWidgets);
          expect(find.byIcon(Icons.medical_information_outlined), findsWidgets);
          expect(find.byTooltip('Compartir ficha médica'), findsNothing);
        } else if (destination.value == DocumentCoordScreen) {
          expect(
            tester
                .widget<DocumentCoordScreen>(find.byType(destination.value))
                .login
                .tourSalesId,
            910001,
          );
          expect(find.byKey(const ValueKey('documents-add')), findsOneWidget);
        } else if (destination.value == HitoAddCoordScreen) {
          expect(
            tester
                .widget<HitoAddCoordScreen>(find.byType(destination.value))
                .login
                .tourSalesId,
            910001,
          );
          expect(find.byKey(const ValueKey('hito-add-title')), findsOneWidget);
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(
            find.byKey(const ValueKey('hito-create-sheet')),
            findsOneWidget,
          );
          expect(
            tester
                .widget<HitoAddCoordScreen>(find.byType(HitoAddCoordScreen))
                .asSheet,
            isTrue,
          );
          final draftState = tester.state(find.byType(HitoAddCoordScreen));
          const draftTitle = 'Borrador ficticio conservado en recarga LAB';
          await tester.enterText(
            find.byKey(const ValueKey('hito-add-title')),
            draftTitle,
          );
          tester.testTextInput.hide();
          await tester.pump();
          // A debug hot reload may invalidate the home statistics while the
          // composer remains open. It must retain the route and local draft.
          final reassemble = tester.binding.reassembleApplication();
          // Reassemble finishes after its scheduled frame; drive that frame
          // before awaiting it under the widget tester's fake clock.
          await tester.pumpAndSettle();
          await reassemble;
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(
            tester.state(find.byType(HitoAddCoordScreen)),
            same(draftState),
          );
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const ValueKey('hito-add-title')),
                )
                .controller!
                .text,
            draftTitle,
          );
          expect(session(), before);
          expect(tester.takeException(), isNull);
        } else {
          expect(
            tester
                .widget<CountDownCoordScreen>(find.byType(destination.value))
                .login
                .tourSalesId,
            910001,
          );
          expect(find.text('Escanear QR'), findsOneWidget);
        }
        await tester.tap(
          find.byTooltip(
            destination.value == HitoAddCoordScreen
                ? 'Cerrar'
                : destination.value == CountDownCoordScreen
                ? 'Cerrar contador'
                : 'Volver',
          ),
        );
        await tester.pumpAndSettle();
        if (destination.value == HitoAddCoordScreen) {
          expect(find.text('¿Descartar este hito?'), findsOneWidget);
          await tester.tap(find.text('Descartar'));
          await tester.pumpAndSettle();
        }
        expect(find.byType(destination.value), findsNothing);
        expect(
          tester.state(find.byType(TravelCoordinatorDashboard)),
          same(originalHome),
        );
        expect(session(), before);
        expect(location.initializations, 1);
        expect(
          jsonEncode([for (final hito in LabFixtures.hitos) hito.toJson()]),
          hitosBefore,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  for (final fromMenu in [false, true]) {
    captureTest(
      'ranking opens from ${fromMenu ? 'menu' : 'home'} and returns without losing session',
      (tester) async {
        final before = session();
        await show(tester);
        final originalHome = tester.state(
          find.byType(TravelCoordinatorDashboard),
        );
        if (fromMenu) {
          await tester.tap(find.byTooltip('Menú de la cuenta'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.text('Ranking de temporada').hitTestable().last,
          );
        } else {
          await tapKey(tester, 'coordinator-home-ranking');
        }
        await tester.pumpAndSettle();
        final screen = tester.widget<CoordinatorRankingScreen>(
          find.byType(CoordinatorRankingScreen),
        );
        expect(screen.currentCoordinatorId, tour.coordinatorId);
        expect(screen.initialSeason, tour.seasonClient);
        await tester.tap(find.byTooltip('Volver').hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(CoordinatorRankingScreen), findsNothing);
        expect(
          tester.state(find.byType(TravelCoordinatorDashboard)),
          same(originalHome),
        );
        expect(session(), before);
        expect(location.initializations, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  captureTest(
    'trip details retain crew and exact dates without replacing home',
    (tester) async {
      await show(tester);
      final originalHome = tester.state(
        find.byType(TravelCoordinatorDashboard),
      );
      await tapKey(tester, 'coordinator-trip-details');
      expect(
        find.textContaining('10/11/2026', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('16/11/2026', findRichText: true),
        findsOneWidget,
      );
      await tapKey(tester, 'home-action-bus');
      expect(find.byType(BusCrewCoorScreen), findsOneWidget);
      expect(
        tester
            .widget<BusCrewCoorScreen>(find.byType(BusCrewCoorScreen))
            .login
            .tourSalesId,
        910001,
      );
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.state(find.byType(TravelCoordinatorDashboard)),
        same(originalHome),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  captureTest(
    'diet roster is reachable even when the summary count is unavailable',
    (tester) async {
      await show(tester);
      final originalHome = tester.state(
        find.byType(TravelCoordinatorDashboard),
      );
      // The synthetic tour deliberately has no aggregate diet information.
      // Absence must not become a fabricated zero or remove the roster entry.
      expect(LabFixtures.tour.specialDietCounts, isNull);
      await tapKey(tester, 'home-special-diets');
      expect(find.byType(SpecialDietPassengersScreen), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(
        find.text('No hay dietas especiales registradas en esta gira.'),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(TravelCoordinatorDashboard)),
        same(originalHome),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  for (final layout in [
    (const Size(402, 874), 1.0),
    (const Size(320, 740), 1.5),
  ]) {
    captureTest(
      'home tools and tabs remain reachable at ${layout.$1.width}/${layout.$2}',
      (tester) async {
        await show(tester, size: layout.$1, textScale: layout.$2);
        expect(find.byType(TripMapView), findsOneWidget);
        expect(
          tester.widget<TripMapView>(find.byType(TripMapView)).preview,
          isTrue,
        );
        expect(find.byType(Switch), findsOneWidget);
        for (final tab in ['home', 'diary', 'gallery', 'documents']) {
          expect(
            find.byKey(ValueKey('family-tab-$tab')).hitTestable(),
            findsOneWidget,
          );
        }
        expect(find.byKey(const ValueKey('family-tab-map')), findsNothing);
        for (final key in [...destinations.keys, 'coordinator-home-open-map']) {
          final button = find.byKey(ValueKey(key));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(button.hitTestable(), findsOneWidget);
          final rect = tester.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(layout.$1.width));
          expect(rect.height, greaterThanOrEqualTo(44));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  captureTest(
    '402-point first view shows preview, editable avatar, roster and primary tools',
    (tester) async {
      tour = TourSales.fromJson({
        ...tour.toJson(),
        'tourCode': 'BRC910001',
        'nameClient': 'COLEGIO HORIZONTE LAB',
        'courseClient': '3° Medio B',
      });
      // Keep synthetic IDs aligned with the local QA coordinator.
      LabFixtures.hitos = [
        for (final hito in LabFixtures.hitos)
          ConsolidatedTourSalesDTO.fromJson({
            ...hito.toJson(),
            'author': {
              'coordinatorId': 910001,
              'name': 'Coordinador',
              'lastname': 'Demo',
            },
          }),
      ];
      LabFixtures.busRecordedAt = DateTime.now().subtract(
        const Duration(hours: 2),
      );
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.resetPadding);
      await show(tester);
      expect(find.byType(TripMapView), findsOneWidget);
      expect(
        tester.widget<TripMapView>(find.byType(TripMapView)).preview,
        isTrue,
      );
      final avatar = tester.widget<ProfilePhotoAvatar>(
        find.byType(ProfilePhotoAvatar),
      );
      expect(avatar.showEditBadge, isTrue);
      expect(avatar.radius, greaterThanOrEqualTo(28));
      expect(
        find.byTooltip('Cambiar foto de perfil').hitTestable(),
        findsOneWidget,
      );
      expect(
        find
            .byTooltip('Abrir mi perfil')
            .hitTestable(at: const Alignment(-.5, -.5)),
        findsOneWidget,
      );
      expect(find.text('Ubicación'), findsOneWidget);
      expect(find.text('Gira a Bariloche'), findsOneWidget);
      expect(find.text('3 hitos · 0 fotos'), findsOneWidget);
      expect(find.byKey(const ValueKey('family-tab-map')), findsNothing);
      final capture = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('coordinator-home-capture')),
      );
      if (const bool.fromEnvironment('PILO_CAPTURE_COORDINATOR_HOME')) {
        await tester.runAsync(() async {
          final image = await capture.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = visualCaptureFile(
            '${Directory.current.path}/registro-local/PILO-COORDINADOR-INTEGRADO/inicio-fixture.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      for (final key in [
        ...destinations.keys,
        'coordinator-home-map-preview',
        'coordinator-home-open-map',
        'coordinator-home-profile',
      ]) {
        final button = find.byKey(ValueKey(key));
        final rect = tester.getRect(button);
        expect(
          button.hitTestable(),
          findsOneWidget,
          reason: '$key should be visible in the first view',
        );
        final scroll = find.ancestor(
          of: button,
          matching: find.byType(Scrollable),
        );
        if (scroll.evaluate().isNotEmpty) {
          final viewport = tester.getRect(scroll.first);
          expect(
            tester.state<ScrollableState>(scroll.first).position.pixels,
            0,
            reason: '$key should be visible without scrolling the initial home',
          );
          expect(rect.top, greaterThanOrEqualTo(viewport.top));
          expect(
            rect.bottom,
            lessThanOrEqualTo(viewport.bottom),
            reason: '$key should fit above its viewport bottom',
          );
        } else if (key != 'family-tab-documents') {
          final dockTop = tester
              .getTopLeft(find.byKey(const ValueKey('family-tab-home')))
              .dy;
          expect(rect.bottom, lessThanOrEqualTo(dockTop));
        }
      }
      final originalHome = tester.state(
        find.byType(TravelCoordinatorDashboard),
      );
      await tapKey(tester, 'coordinator-home-open-map');
      expect(find.byType(TraceMapFullScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('family-tab-home')), findsNothing);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(TraceMapFullScreen), findsNothing);
      expect(
        tester.state(find.byType(TravelCoordinatorDashboard)),
        same(originalHome),
      );
      expect(
        find.byKey(const ValueKey('family-tab-documents')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
