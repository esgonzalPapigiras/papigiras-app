import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'package:papigiras_app/maps/trip_bus_controller.dart';
import 'package:papigiras_app/maps/trip_bus_marker.dart';

void main() {
  final timestamp = DateTime.utc(2026, 11, 5, 14, 23, 19);
  TripBusPosition position({DateTime? recordedAt}) => TripBusPosition(
    coordinatorId: 910001,
    coordinate: const LatLng(-33.45, -70.66),
    recordedAt: recordedAt,
  );

  Future<void> show(
    WidgetTester tester, {
    required bool recent,
    bool reduceMotion = false,
    bool tickerEnabled = true,
    bool simulation = true,
    bool missingDate = false,
    bool pilo = false,
    DateTime? recordedAt,
    DateTime Function()? now,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: papiLocale,
        supportedLocales: papiSupportedLocales,
        localizationsDelegates: papiLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: TickerMode(
              enabled: tickerEnabled,
              child: TripBusMarker(
                key: const ValueKey('bus-test-state'),
                position: position(
                  recordedAt: missingDate ? null : recordedAt ?? timestamp,
                ),
                recent: recent,
                simulation: simulation,
                pilo: pilo,
                now: now,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double pulseScale(WidgetTester tester) => tester
      .widget<Transform>(find.byKey(const ValueKey('trip-bus-pulse')))
      .transform
      .storage[0];

  testWidgets('posición reciente pulsa y la última posición queda estática', (
    tester,
  ) async {
    await show(tester, recent: true);
    expect(
      tester.getSize(find.byKey(const ValueKey('trip-bus-marker'))),
      const Size.square(64),
    );
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byTooltip('Ubicación de prueba reciente'), findsOneWidget);
    final initial = pulseScale(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(pulseScale(tester), greaterThan(initial));
    expect(pulseScale(tester), lessThanOrEqualTo(1.42));

    await show(tester, recent: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-bus-pulse')), findsNothing);
    expect(find.byTooltip('Última posición registrada'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-bus-illustration')), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reducir movimiento y TickerMode detienen el halo y pueden reanudarlo',
    (tester) async {
      await show(tester, recent: true, reduceMotion: true);
      final reducedScale = pulseScale(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(pulseScale(tester), reducedScale);
      expect(tester.binding.transientCallbackCount, 0);

      await show(tester, recent: true, tickerEnabled: false);
      final mutedScale = pulseScale(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(pulseScale(tester), mutedScale);
      expect(tester.binding.transientCallbackCount, 0);

      await show(tester, recent: true);
      final resumedScale = pulseScale(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(pulseScale(tester), greaterThan(resumedScale));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'al tocar muestra fecha local, estado y aclaración ficticia sin afirmar conexión',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await show(tester, recent: true);
        expect(
          find.bySemanticsLabel('Ubicación de prueba reciente'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('trip-bus-marker')));
        await tester.pumpAndSettle();
        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(dialog.backgroundColor, Colors.white);
        expect(find.text('Bus de la gira'), findsOneWidget);
        expect(find.text('Ubicación de prueba reciente'), findsOneWidget);
        final local = timestamp.toLocal();
        String two(int value) => value.toString().padLeft(2, '0');
        expect(
          find.text(
            '${two(local.day)}/${two(local.month)}/${local.year} · '
            '${two(local.hour)}:${two(local.minute)}:${two(local.second)}',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Posición ficticia del LAB'),
          findsOneWidget,
        );
        expect(
          find.textContaining('No representa la ubicación real del bus.'),
          findsOneWidget,
        );
        expect(find.textContaining('GPS'), findsNothing);
        expect(find.text('ON'), findsNothing);
        // Opening the modal pauses the otherwise repeating animation underneath.
        expect(tester.binding.transientCallbackCount, 0);
        await tester.tap(find.text('Cerrar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(AlertDialog), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'fecha ausente se informa y el texto LAB queda separado de la UI reutilizable',
    (tester) async {
      await show(tester, recent: false, simulation: false, missingDate: true);
      await tester.tap(find.byKey(const ValueKey('trip-bus-marker')));
      await tester.pumpAndSettle();
      expect(find.text('Última posición registrada'), findsOneWidget);
      expect(find.text('Fecha no disponible'), findsOneWidget);
      expect(find.textContaining('LAB'), findsNothing);
      expect(
        find.textContaining('No confirma el estado de conexión del bus.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('trip-bus-pulse')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  Finder lastLocationChip() =>
      find.byKey(const ValueKey('pilo-bus-last-location-chip'));

  testWidgets('Pilo muestra la antigüedad y el detalle de un reporte de hoy', (
    tester,
  ) async {
    final recordedAt = DateTime(2026, 11, 14, 13, 12);
    var now = DateTime(2026, 11, 14, 15, 22);
    await show(
      tester,
      recent: false,
      simulation: false,
      pilo: true,
      recordedAt: recordedAt.toUtc(),
      now: () => now,
    );

    final chip = lastLocationChip();
    expect(
      find.descendant(of: chip, matching: find.byIcon(Icons.schedule_rounded)),
      findsOneWidget,
    );
    expect(find.text('Hace 2 h'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-bus-pulse')), findsNothing);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      expect(
        find.bySemanticsLabel('Última ubicación conocida. Hace 2 h'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }

    await tester.tap(chip);
    await tester.pumpAndSettle();
    final title = find.text('Última ubicación conocida');
    expect(title, findsOneWidget);
    expect(find.text('Hoy a las 13:12'), findsOneWidget);
    expect(find.textContaining('LAB'), findsNothing);
    final surface = find.ancestor(of: title, matching: find.byType(Material));
    final size = tester.getSize(surface.first);
    expect(size.width, lessThanOrEqualTo(320));
    expect(size.height, lessThanOrEqualTo(120));
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(title, findsNothing);

    now = DateTime(2026, 11, 14, 15, 32);
    await show(
      tester,
      recent: false,
      pilo: true,
      recordedAt: now.subtract(const Duration(minutes: 20)),
      now: () => now,
    );
    expect(find.text('Hace 20 min'), findsOneWidget);
  });

  testWidgets('Pilo distingue ayer por día calendario y muestra fecha y hora', (
    tester,
  ) async {
    final recordedAt = DateTime(2026, 12, 31, 23, 58);
    final now = DateTime(2027, 1, 1, 0, 2);
    await show(
      tester,
      recent: false,
      pilo: true,
      recordedAt: recordedAt.toUtc(),
      now: () => now.toUtc(),
    );

    expect(find.text('Ayer'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-bus-marker')));
    await tester.pumpAndSettle();
    expect(find.text('Última ubicación conocida'), findsOneWidget);
    expect(find.text('31/12/2026 a las 23:58'), findsOneWidget);
    expect(find.textContaining('Posición ficticia'), findsOneWidget);
  });

  testWidgets('Pilo abrevia fechas anteriores y maneja horas inválidas', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 14, 15, 12);
    final recordedAt = DateTime(2026, 11, 12, 13, 12);
    await show(
      tester,
      recent: false,
      pilo: true,
      recordedAt: recordedAt.toUtc(),
      now: () => now,
    );
    final localizations = MaterialLocalizations.of(
      tester.element(lastLocationChip()),
    );
    expect(
      find.text(localizations.formatShortMonthDay(recordedAt)),
      findsOneWidget,
    );

    await show(
      tester,
      recent: false,
      pilo: true,
      recordedAt: now.add(const Duration(minutes: 1)).toUtc(),
      now: () => now,
    );
    expect(find.text('Sin hora'), findsOneWidget);
    await tester.tap(lastLocationChip());
    await tester.pumpAndSettle();
    expect(find.text('Fecha no disponible'), findsOneWidget);
  });
}
