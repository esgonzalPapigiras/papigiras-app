import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_trip_progress.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    required DateTime Function() now,
    String start = '2026-12-31T23:30:00-03:00',
    String end = '02/01/2027',
    bool compact = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PiloTripProgress(
          departure: start,
          returnDate: end,
          now: now,
          compact: compact,
        ),
      ),
    ),
  );

  testWidgets('progress uses recorded calendar days across years', (
    tester,
  ) async {
    final indicator = find.byType(LinearProgressIndicator);
    for (final (date, status, fraction) in [
      (DateTime(2026, 12, 30), 'Por comenzar', 0.0),
      (DateTime(2026, 12, 31), 'Día 1 de 3', 1 / 3),
      (DateTime(2027, 1, 1), 'Día 2 de 3', 2 / 3),
      (DateTime(2027, 1, 2), 'Día 3 de 3', 1.0),
      (DateTime(2027, 1, 3), 'Finalizada', 1.0),
    ]) {
      await show(tester, now: () => date);
      expect(tester.widget<LinearProgressIndicator>(indicator).value, fraction);
      expect(find.text(status), findsOneWidget);
      expect(find.text('Salida 31/12/2026'), findsOneWidget);
      expect(find.text('Regreso 02/01/2027'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('refreshes at midnight while the home stays mounted', (
    tester,
  ) async {
    var now = DateTime(2027, 1, 1, 23, 59, 59);
    await show(tester, now: () => now);
    expect(find.text('Día 2 de 3'), findsOneWidget);
    now = DateTime(2027, 1, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Día 3 de 3'), findsOneWidget);
  });

  testWidgets('supports one day and keeps dates when progress is unknown', (
    tester,
  ) async {
    DateTime now() => DateTime(2027, 1, 2);
    await show(tester, now: now, start: '2027-01-02');
    expect(find.text('Día 1 de 1'), findsOneWidget);

    for (final start in ['', '2027-01-03']) {
      await show(tester, now: now, start: start);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Regreso 02/01/2027'), findsOneWidget);
    }
  });
  testWidgets('compact range preserves day semantics across months and years', (
    tester,
  ) async {
    for (final (start, end, range) in [
      ('2026-11-12', '2026-11-18', '12 – 18 nov.'),
      ('2026-11-29', '2026-12-05', '29 nov. – 5 dic.'),
      ('2026-12-31', '2027-01-06', '31 dic. 2026 – 6 ene. 2027'),
    ]) {
      await show(
        tester,
        now: () => DateTime.parse(start).add(const Duration(days: 2)),
        start: start,
        end: end,
        compact: true,
      );
      expect(find.text(range), findsOneWidget);
      expect(find.text('Día 3 de 7'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        3 / 7,
      );
      await tester.pumpWidget(const SizedBox());
    }
  });
}
