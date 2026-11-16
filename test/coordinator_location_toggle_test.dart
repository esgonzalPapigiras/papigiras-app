import 'dart:async';
import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/coordinator_location_toggle.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

import 'support/map_tiles.dart';

const _label = 'Compartir ubicación de prueba';
const _pinColor = Color(0xFFF4C542);
const _offTrackColor = Color(0xFFE4E7E7);
const _onTrackColor = Color(0xFF16A36A);

class _FakeLocationService extends LocationService {
  bool sharing = false;
  bool busy = false;
  String? error;
  String? nextError;
  Completer<void>? pending;
  final requests = <bool>[];

  @override
  bool get isTracking => sharing;
  @override
  bool get isChangingMode => busy;
  @override
  String? get lastError => error;

  // UI tests never start the location timer or call its transport.
  @override
  Future<void> initializeForCoordinatorSession() async {}

  @override
  Future<void> setSharingEnabled(bool enabled) async {
    requests.add(enabled);
    busy = true;
    notifyListeners();
    try {
      await pending?.future;
      error = nextError;
      if (error == null) sharing = enabled;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

void main() {
  late _FakeLocationService location;

  setUp(() async {
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    LabMapTiles.testProvider = TestMapTileProvider.new;
    await (await SharedPreferences.getInstance()).clear();
    location = _FakeLocationService();
  });

  tearDown(() {
    location.dispose();
    LabMapTiles.testProvider = null;
    LabMode.useFixturesForTests(false);
  });

  Future<void> show(
    WidgetTester tester, {
    bool dashboard = false,
    double width = 402,
    double textScale = 1,
    bool longName = false,
    bool compactPilo = false,
  }) async {
    tester.view.physicalSize = Size(width, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tour = TourSales.fromCoordinatorTour(
      coordinator: LabFixtures.coordinator,
      tour: LabFixtures.tour,
    );
    final displayTour = longName
        ? TourSales.fromJson({
            ...tour.toJson(),
            'tourTripulationNameId':
                'Coordinadora Ficticia de Apellido Extenso LAB',
          })
        : tour;
    await tester.pumpWidget(
      ChangeNotifierProvider<LocationService>.value(
        value: location,
        child: MaterialApp(
          theme: compactPilo ? PiloFamilyTheme.theme(ThemeData()) : null,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: dashboard
              ? TravelCoordinatorDashboard(login: displayTour)
              : Scaffold(
                  body: Center(
                    child: CoordinatorLocationToggle(compact: compactPilo),
                  ),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Switch control(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch));

  Color? trackColor(Switch toggle) =>
      toggle.trackColor?.resolve({if (toggle.value) WidgetState.selected}) ??
      (toggle.value ? toggle.activeTrackColor : toggle.inactiveTrackColor);

  Color? thumbColor(Switch toggle) =>
      toggle.thumbColor?.resolve({if (toggle.value) WidgetState.selected}) ??
      (toggle.value ? toggle.activeThumbColor : toggle.inactiveThumbColor);

  Finder pin() => find.byWidgetPredicate(
    (widget) => widget is Icon && widget.color == _pinColor,
  );

  for (final enabled in [false, true]) {
    testWidgets(
      'location control exposes one semantic switch and ${enabled ? 'green' : 'gray'} state',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          location.sharing = enabled;
          await show(tester);
          final toggle = control(tester);
          expect(toggle.value, enabled);
          expect(trackColor(toggle), enabled ? _onTrackColor : _offTrackColor);
          expect(thumbColor(toggle), Colors.white);
          expect(pin(), findsOneWidget);
          expect(find.bySemanticsLabel(_label), findsOneWidget);
          final node = tester.getSemantics(find.bySemanticsLabel(_label));
          expect(node.hasFlag(SemanticsFlag.hasToggledState), isTrue);
          expect(node.hasFlag(SemanticsFlag.isToggled), enabled);
          expect(location.requests, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'pin is an indicator and each switch tap requests one ON or OFF change',
    (tester) async {
      await show(tester);
      await tester.tap(pin());
      await tester.pumpAndSettle();
      expect(location.requests, isEmpty);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(location.requests, [true]);
      expect(control(tester).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(location.requests, [true, false]);
      expect(control(tester).value, isFalse);
    },
  );

  testWidgets(
    'pending change disables the control and prevents another request',
    (tester) async {
      await show(tester);
      location.pending = Completer<void>();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(control(tester).onChanged, isNull);
      expect(location.requests, [true]);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(location.requests, [true]);
      location.pending!.complete();
      await tester.pumpAndSettle();
      expect(control(tester).onChanged, isNotNull);
      expect(control(tester).value, isTrue);
    },
  );

  testWidgets(
    'failed change shows the service message and preserves the OFF state',
    (tester) async {
      location.nextError = 'No se pudo activar el recorrido de prueba.';
      await show(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(location.requests, [true]);
      expect(control(tester).value, isFalse);
      expect(find.text(location.nextError!), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  for (final enabled in [false, true]) {
    testWidgets(
      'compact Pilo exposes one accessible ${enabled ? 'ON' : 'OFF'} control',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          location.sharing = enabled;
          await show(tester, compactPilo: true);
          expect(find.text('Ubicación'), findsOneWidget);
          expect(find.text('Compartiendo'), findsNothing);
          expect(find.text('Desactivada'), findsNothing);
          expect(find.bySemanticsLabel(_label), findsOneWidget);
          final node = tester.getSemantics(find.bySemanticsLabel(_label));
          expect(node.hasFlag(SemanticsFlag.hasToggledState), isTrue);
          expect(node.hasFlag(SemanticsFlag.isToggled), enabled);
          expect(node.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
          expect(node.hasFlag(SemanticsFlag.isEnabled), isTrue);
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          expect(control(tester).value, enabled);
          expect(
            tester.getRect(find.byType(Switch)).right,
            lessThan(tester.getRect(find.text('Ubicación')).left),
          );
          expect(
            trackColor(control(tester)),
            enabled ? PiloFamilyTheme.mint : PiloFamilyTheme.hairline,
          );
          final target = tester.getRect(
            find.byKey(const ValueKey('coordinator-map-location-toggle')),
          );
          expect(target.height, greaterThanOrEqualTo(44));
          expect(target.width, greaterThanOrEqualTo(44));
          expect(location.requests, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'compact Pilo label, outer touch area and switch each toggle exactly once',
    (tester) async {
      await show(tester, compactPilo: true);
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      expect(location.requests, [true]);
      expect(control(tester).value, isTrue);

      // Tap the 44-point target beyond the smaller visible capsule.
      final target = tester.getRect(
        find.byKey(const ValueKey('coordinator-map-location-toggle')),
      );
      await tester.tapAt(Offset(target.center.dx, target.top + 2));
      await tester.pumpAndSettle();
      expect(location.requests, [true, false]);
      expect(control(tester).value, isFalse);

      // Switch visuals ignore their own pointer handler; the shared target
      // sends one request even when the user's tap lands on the switch.
      await tester.tapAt(tester.getCenter(find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(location.requests, [true, false, true]);
      expect(control(tester).value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact Pilo disables every touch surface and semantics while changing',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await show(tester, compactPilo: true);
        location.pending = Completer<void>();
        final target = find.byKey(
          const ValueKey('coordinator-map-location-toggle'),
        );
        final switchCenter = tester.getCenter(find.byType(Switch));
        await tester.tap(find.text('Ubicación'));
        await tester.pump();
        expect(location.requests, [true]);
        expect(find.byType(Switch), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.widget<InkWell>(target).onTap, isNull);
        final node = tester.getSemantics(find.bySemanticsLabel(_label));
        expect(node.hasFlag(SemanticsFlag.isToggled), isFalse);
        expect(node.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
        expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
        await tester.tap(find.text('Ubicación'));
        await tester.tapAt(switchCenter);
        final rect = tester.getRect(target);
        await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
        await tester.pump();
        expect(location.requests, [true]);
        location.pending!.complete();
        await tester.pumpAndSettle();
        expect(control(tester).value, isTrue);
        final restored = tester.getSemantics(find.bySemanticsLabel(_label));
        expect(restored.hasFlag(SemanticsFlag.isEnabled), isTrue);
        expect(restored.hasFlag(SemanticsFlag.isToggled), isTrue);
        await tester.tap(find.text('Ubicación'));
        await tester.pumpAndSettle();
        expect(location.requests, [true, false]);
        expect(control(tester).value, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'compact Pilo failed activation retains OFF and exposes the service error',
    (tester) async {
      location.nextError = 'No se pudo activar el recorrido de prueba.';
      await show(tester, compactPilo: true);
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      expect(location.requests, [true]);
      expect(control(tester).value, isFalse);
      expect(find.text(location.nextError!), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320-point dashboard keeps compact sharing in map and long profile names in details',
    (tester) async {
      await show(
        tester,
        dashboard: true,
        width: 320,
        textScale: 1.3,
        longName: true,
      );
      expect(find.byType(CoordinatorLocationToggle), findsOneWidget);
      final toggle = tester.getRect(find.byType(CoordinatorLocationToggle));
      final preview = tester.getRect(
        find.byKey(const ValueKey('coordinator-home-map-preview')),
      );
      expect(toggle.top, greaterThanOrEqualTo(preview.top));
      expect(toggle.bottom, lessThanOrEqualTo(preview.bottom));
      expect(toggle.left, greaterThanOrEqualTo(preview.left));
      expect(toggle.right, lessThanOrEqualTo(preview.right));
      expect(toggle.height, greaterThanOrEqualTo(44));
      expect(toggle.left, greaterThanOrEqualTo(0));
      expect(toggle.right, lessThanOrEqualTo(320));
      expect(find.text('Ubicación'), findsOneWidget);
      expect(find.text('Compartir ubicación'), findsNothing);
      expect(find.text('Desactivada'), findsNothing);
      expect(trackColor(control(tester)), PiloFamilyTheme.hairline);
      location.sharing = true;
      location.notifyListeners();
      await tester.pumpAndSettle();
      expect(trackColor(control(tester)), PiloFamilyTheme.mint);
      expect(find.text('Compartiendo'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('coordinator-trip-details')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Coordinadora Ficticia de Apellido Extenso Lab'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(location.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('drawer no longer duplicates the location switch', (
    tester,
  ) async {
    await show(tester, dashboard: true);
    await tester.tap(find.byKey(const ValueKey('coordinator-trip-details')));
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('home-account-menu'));
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final drawer = find.byType(CoordinatorEndDrawer);
    expect(drawer, findsOneWidget);
    expect(
      find.descendant(of: drawer, matching: find.byType(Switch)),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.byType(SwitchListTile)),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Seguimiento de prueba')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Mi perfil')),
      findsOneWidget,
    );
    expect(location.requests, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
