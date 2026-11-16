import 'package:papigiras_app/navigation/family_navigation.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/main.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/pages/attorney/documentsfather.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:papigiras_app/utils/page_navigation.dart';

import 'support/map_tiles.dart';

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

void main() {
  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    LabMapTiles.testProvider = TestMapTileProvider.new;
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      HttpOverrides.global = previous;
      LabMode.useFixturesForTests(false);
      LabFixtures.reset();
      LabMapTiles.testProvider = null;
      SharedPreferences.setMockInitialValues({});
    });
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> renderImmediate(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  void expectImmediate(PageRoute<dynamic> route) {
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    expect(route.animation!.status, AnimationStatus.completed);
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform MaterialPageRoute entra y vuelve sin animación ni perder resultado',
      (tester) async {
        phone(tester);
        final routes = _Routes();
        int? returned;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: platform,
              pageTransitionsTheme: papiPageTransitions,
            ),
            navigatorObservers: [routes],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    returned = await Navigator.of(context).push<int>(
                      MaterialPageRoute<int>(
                        settings: const RouteSettings(
                          name: '/synthetic/detail',
                        ),
                        builder: (context) => Scaffold(
                          body: SizedBox.expand(
                            key: const ValueKey('destination'),
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, 7),
                              child: const Text('Volver'),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await renderImmediate(tester);
        final route = routes.pushed.last as PageRoute<dynamic>;
        expectImmediate(route);
        expect(route.settings.name, '/synthetic/detail');
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('destination'))),
          Offset.zero,
        );
        expect(find.byType(SlideTransition), findsNothing);
        await tester.tap(find.text('Volver'));
        await renderImmediate(tester);
        expect(returned, 7);
        expect(find.text('Abrir'), findsOneWidget);
        expect(find.byKey(const ValueKey('destination')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'ruta personalizada coordinador conserva pila y resultado sin depender del tema',
    (tester) async {
      final routes = _Routes();
      Object? returned;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routes],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  returned = await Navigator.of(context).push<dynamic>(
                    buildCoordinatorRoute(
                      Scaffold(
                        body: Builder(
                          builder: (context) => TextButton(
                            onPressed: () => Navigator.pop(context, 'guardado'),
                            child: const Text('Volver'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await renderImmediate(tester);
      expectImmediate(routes.pushed.last as PageRoute<dynamic>);
      expect(find.byType(SlideTransition), findsNothing);
      await tester.tap(find.text('Volver'));
      await renderImmediate(tester);
      expect(returned, 'guardado');
      expect(find.text('Abrir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'app activa aplica el tema a rutas normales y conserva animaciones locales',
    (tester) async {
      phone(tester);
      var wider = false;
      late MaterialPageRoute<void> route;
      await tester.pumpWidget(
        PapigirasLab(
          startScreen: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  route = MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: StatefulBuilder(
                        builder: (context, setState) => Column(
                          children: [
                            AnimatedContainer(
                              key: const ValueKey('local-animation'),
                              duration: const Duration(seconds: 1),
                              width: wider ? 120 : 40,
                              height: 30,
                              color: Colors.teal,
                            ),
                            TextButton(
                              onPressed: () => setState(() => wider = true),
                              child: const Text('Cambiar ancho'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Volver'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  Navigator.push(context, route);
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await renderImmediate(tester);
      expectImmediate(route);
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.text('Cambiar ancho')),
        ),
        isFalse,
      );
      await tester.tap(find.text('Cambiar ancho'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final width = tester
          .getSize(find.byKey(const ValueKey('local-animation')))
          .width;
      expect(width, greaterThan(40));
      expect(width, lessThan(120));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await renderImmediate(tester);
      expect(find.text('Abrir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'apoderado abre documentos por su ruta real y vuelve al mismo inicio',
    (tester) async {
      phone(tester);
      final routes = _Routes();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routes],
          home: TravelFatherDashboard(login: LabFixtures.passenger),
        ),
      );
      await tester.pumpAndSettle();
      final dashboard = tester.state(find.byType(TravelFatherDashboard));
      await tester.tap(find.byKey(const ValueKey('family-trip-details')));
      await tester.pumpAndSettle();
      final documents = find.byKey(const ValueKey('family-action-documents'));
      await tester.ensureVisible(documents);
      await tester.tap(documents);
      await tester.pumpAndSettle();
      await renderImmediate(tester);
      expect(
        routes.pushed.whereType<PageRoute<dynamic>>().length,
        1,
      ); // The trip sheet is a popup; selecting a section adds no page route.
      expect(find.byType(DocumentFatherScreen), findsOneWidget);
      expectImmediate(
        ModalRoute.of(tester.element(find.byType(DocumentFatherScreen)))!
            as PageRoute<dynamic>,
      );
      expect(find.byType(FamilyNavigationBar), findsOneWidget);
      await FamilyNavigationScope.maybeOf(
        tester.element(find.byType(DocumentFatherScreen)),
      )!.back();
      await renderImmediate(tester);
      expect(tester.state(find.byType(TravelFatherDashboard)), same(dashboard));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'galería usa ruta instantánea conservando índice y navegación entre fotos',
    (tester) async {
      phone(tester);
      final routes = _Routes();
      final photo = base64Encode(TileProvider.transparentImage);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(pageTransitionsTheme: papiPageTransitions),
          navigatorObservers: [routes],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    openTripPhotos(context, [photo, photo], initialIndex: 1),
                child: const Text('Fotos'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Fotos'));
      await renderImmediate(tester);
      expectImmediate(routes.pushed.last as PageRoute<dynamic>);
      expect(find.text('2 de 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Foto anterior'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar fotos'));
      await renderImmediate(tester);
      expect(find.text('Fotos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('diálogo conserva su interacción y resultado propios', (
    tester,
  ) async {
    final routes = _Routes();
    bool? returned;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(pageTransitionsTheme: papiPageTransitions),
        navigatorObservers: [routes],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                returned = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirmación de prueba'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Aceptar'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Diálogo'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Diálogo'));
    await tester.pumpAndSettle();
    expect(
      (routes.pushed.last as DialogRoute).transitionDuration,
      greaterThan(Duration.zero),
    );
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(find.text('Diálogo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
