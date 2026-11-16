import 'dart:ui' show SemanticsFlag, SemanticsAction;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/apple_design_trial.dart';
import 'package:papigiras_app/design/coordinator_home_trial.dart';
import 'package:papigiras_app/utils/page_navigation.dart';

// Presentation-only fixtures: no providers, sessions, transport or device APIs.
const _name = 'Coordinadora Ficticia de Apellido Extenso LAB';
const _school = 'Colegio de Demostración con Nombre Extenso LAB';
const _destinations = [
  ('map', 'Mapa', CupertinoIcons.map, Icons.map_outlined),
  ('binnacle', 'Bitácora', CupertinoIcons.book, Icons.menu_book_outlined),
  ('bus', 'Tripulación', CupertinoIcons.bus, Icons.directions_bus_outlined),
  (
    'count',
    'Contador',
    CupertinoIcons.qrcode_viewfinder,
    Icons.qr_code_scanner,
  ),
  ('documents', 'Documentos', CupertinoIcons.folder, Icons.folder_outlined),
];

void main() {
  test('destination uses only the existing code prefix; no city guesses', () {
    expect(homeDestinationCode('BRC26910001A'), 'BRC');
    expect(homeDestinationCode('CMB26910002B'), 'CMB');
    expect(homeDestinationCode(' puc26910003c '), 'PUC');
    for (final code in ['', 'LAB', 'GIRA-DEMO-2026-A', '2026', 'BRC']) {
      expect(homeDestinationCode(code), isNull);
    }
  });
  Future<Map<String, int>> showHome(
    WidgetTester tester, {
    required Size size,
    required double scale,
    required TargetPlatform platform,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String, int>{};
    void record(String action) =>
        calls.update(action, (count) => count + 1, ifAbsent: () => 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          platform: platform,
          pageTransitionsTheme: papiPageTransitions,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: AppleDesignTrialScope(
          child: Scaffold(
            body: CoordinatorHomeTrial(
              name: _name,
              school: _school,
              course: '3° medio B',
              season: '2026',
              departure: '2026-10-26',
              returnDate: '2026-11-01',
              tourCode: 'BRC26910001A',
              // Match the real avatar and sharing control footprints. Their
              // service/photo behavior is covered by dedicated regression tests.
              avatar: const SizedBox.square(
                dimension: 72,
                child: CircleAvatar(child: Icon(Icons.person_outline)),
              ),
              locationToggle: const SizedBox(width: 84, height: 48),
              passengers: HomeTrialPassengers(
                male: 1,
                female: 2,
                maleCompanion: 1,
                femaleCompanion: 1,
                specialDietCounts: const {'vegetariano': 3, 'vegano': 1},
                onOpen: () => record('roster'),
              ),
              onProfile: () => record('profile'),
              onMenu: () => record('menu'),
              onNewHito: () => record('new-hito'),
              actions: [
                for (final action in _destinations)
                  HomeTrialAction(
                    action.$1,
                    action.$2,
                    action.$3,
                    action.$4,
                    () => record(action.$1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(calls, isEmpty);
    return calls;
  }

  const cases = [
    (Size(320, 568), 1.3),
    (Size(320, 568), 2.0),
    (Size(320, 568), 3.0),
    (Size(402, 874), 1.0),
    (Size(844, 390), 1.0),
  ];
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final item in cases) {
      testWidgets(
        'home ${platform.name} ${item.$1} text ${item.$2} keeps every action reachable',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final calls = await showHome(
              tester,
              size: item.$1,
              scale: item.$2,
              platform: platform,
            );
            final create = find.byKey(const ValueKey('home-new-hito'));
            final createBefore = tester.getRect(create);
            expect(create.hitTestable(), findsOneWidget);
            expect(createBefore.height, greaterThanOrEqualTo(48));
            expect(createBefore.left, greaterThanOrEqualTo(0));
            expect(createBefore.right, lessThanOrEqualTo(item.$1.width));
            expect(createBefore.bottom, lessThanOrEqualTo(item.$1.height));
            await tester.tap(create);
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Abrir menú'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Mi perfil'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Mi perfil'));
            await tester.pumpAndSettle();
            expect(calls['profile'], 1);
            expect(find.text(_name), findsOneWidget);
            final title = tester.widget<Text>(
              find.byKey(const ValueKey('home-trip-title')),
            );
            expect(title.maxLines, 2);
            expect(title.data, endsWith('3° medio B · 2026'));
            expect(find.text('Destino · BRC'), findsOneWidget);
            expect(find.text('26/10/2026 → 01/11/2026'), findsOneWidget);
            expect(find.text('♂ 1   ♀ 2'), findsOneWidget);
            expect(find.text('♂ 1   ♀ 1'), findsOneWidget);
            expect(
              find.byKey(const ValueKey('home-action-medical')),
              findsNothing,
            );

            final fullDetails = find.byKey(
              const ValueKey('home-trip-full-details'),
            );
            if (fullDetails.evaluate().isNotEmpty) {
              await tester.ensureVisible(fullDetails);
              await tester.pumpAndSettle();
              expect(
                tester
                    .getSemantics(fullDetails)
                    .getSemanticsData()
                    .hasAction(SemanticsAction.tap),
                isTrue,
              );
              await tester.tap(fullDetails);
              await tester.pumpAndSettle();
              expect(find.text('$_school · 3° medio B · 2026'), findsOneWidget);
              await tester.tap(find.text('Cerrar'));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            final dateScroll = find.byKey(
              const ValueKey('home-trip-dates-scroll'),
            );
            await tester.ensureVisible(dateScroll);
            await tester.pumpAndSettle();
            expect(
              find.bySemanticsLabel('Salida: 26/10/2026. Regreso: 01/11/2026'),
              findsOneWidget,
            );
            if (item.$2 >= 2) {
              final scrollable = find.descendant(
                of: dateScroll,
                matching: find.byType(Scrollable),
              );
              final state = tester.state<ScrollableState>(scrollable);
              await tester.drag(dateScroll, const Offset(-180, 0));
              await tester.pumpAndSettle();
              expect(state.position.pixels, greaterThan(0));
            }

            final roster = find.text('Nómina y fichas médicas');
            await tester.ensureVisible(roster);
            await tester.pumpAndSettle();
            expect(roster.hitTestable(), findsOneWidget);
            await tester.tap(roster);
            await tester.pumpAndSettle();
            expect(calls['roster'], 1);
            expect(tester.takeException(), isNull);

            for (final action in _destinations) {
              final target = find.byKey(ValueKey('home-action-${action.$1}'));
              await tester.ensureVisible(target);
              await tester.pumpAndSettle();
              expect(target.hitTestable(), findsOneWidget);
              expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
              expect(
                tester.getSemantics(target).hasFlag(SemanticsFlag.isButton),
                isTrue,
              );
              await tester.tap(target);
              await tester.pumpAndSettle();
              expect(calls[action.$1], 1);
              expect(tester.takeException(), isNull);
              // The primary action stays in reach while browsing long content.
              expect(create.hitTestable(), findsOneWidget);
              expect(tester.getRect(create), createBefore);
            }
            expect(calls, {
              'new-hito': 1,
              'menu': 1,
              'profile': 1,
              'roster': 1,
              for (final action in _destinations) action.$1: 1,
            });
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    testWidgets('home uses ${platform.name} system type and icon family', (
      tester,
    ) async {
      await showHome(
        tester,
        size: const Size(402, 874),
        scale: 1,
        platform: platform,
      );
      final context = tester.element(find.byType(CoordinatorHomeTrial));
      final theme = Theme.of(context);
      expect(
        theme.textTheme.bodyMedium?.fontFamily,
        platform == TargetPlatform.iOS
            ? const CupertinoThemeData().textTheme.textStyle.fontFamily
            : 'Roboto',
      );
      expect(theme.pageTransitionsTheme, papiPageTransitions);
      for (final action in _destinations) {
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(ValueKey('home-action-${action.$1}')),
            matching: find.byType(Icon),
          ),
        );
        expect(
          icon.icon,
          platform == TargetPlatform.iOS ? action.$3 : action.$4,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
