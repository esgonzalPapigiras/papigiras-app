import 'dart:ui' show SemanticsFlag;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/coordinator_tour_picker.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';

// Pure UI fixtures: no account, provider, transport or saved session.
const tours = [
  CoordinatorTour(
    tourId: 910001,
    tourCode: 'GIRA-DEMO-2026-A',
    startDate: '2026-10-26',
    endDate: '2026-11-01',
    status: '',
    clientId: 0,
    clientName: 'Colegio Horizonte LAB',
    course: '3° medio B',
    season: 2026,
    assignmentId: 0,
  ),
  CoordinatorTour(
    tourId: 910002,
    tourCode: 'GIRA-DEMO-2026-B',
    startDate: '2026-11-22',
    endDate: '2026-11-28',
    status: '',
    clientId: 0,
    clientName: 'Colegio de Demostración con Nombre Extenso LAB',
    course: '4° medio A',
    season: 2026,
    assignmentId: 0,
  ),
];

void main() {
  const ready = AsyncSnapshot.withData(ConnectionState.done, tours);
  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double scale = 1,
    TargetPlatform platform = TargetPlatform.iOS,
    Brightness brightness = Brightness.light,
    AsyncSnapshot<List<CoordinatorTour>> snapshot = ready,
    int? loadingId,
    bool reduceMotion = false,
    ValueChanged<CoordinatorTour>? select,
    VoidCallback? retry,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform, brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: CoordinatorTourPicker(
          snapshot: snapshot,
          loadingTourId: loadingId,
          onSelect: select ?? (_) {},
          onRetry: retry ?? () {},
        ),
      ),
    );
    await tester.pump();
  }

  test(
    'date presentation preserves full year, missing and malformed values',
    () {
      expect(
        formatCoordinatorTourDates('2026-11-22', '2026-11-28'),
        '22–28 nov 2026',
      );
      expect(
        formatCoordinatorTourDates('2026-10-26', '2026-11-01'),
        '26 oct – 1 nov 2026',
      );
      expect(
        formatCoordinatorTourDates('2026-12-30', '2027-01-05'),
        '30 dic 2026 – 5 ene 2027',
      );
      expect(
        formatCoordinatorTourDates('2026-11-22', '2026-11-22'),
        '22 nov 2026',
      );
      expect(formatCoordinatorTourDates('', ''), 'Fechas no disponibles');
      expect(formatCoordinatorTourDates('', '2026-11-22'), 'Hasta 22 nov 2026');
      expect(formatCoordinatorTourDates('2026-11-22', ''), 'Desde 22 nov 2026');
      expect(
        formatCoordinatorTourDates('2026-02-31', 'sin fecha'),
        '2026-02-31 – sin fecha',
      );
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final layout in [
      (const Size(320, 568), 1.0),
      (const Size(320, 568), 3.0),
      (const Size(402, 874), 1.0),
      (const Size(844, 390), 2.0),
      (const Size(1024, 768), 1.0),
    ]) {
      testWidgets(
        '${platform.name} $layout: all data and choices remain reachable',
        (tester) async {
          final semantics = tester.ensureSemantics();
          // Dispose before the binding performs end-of-test verification.
          try {
            final selections = <int>[];
            await show(
              tester,
              size: layout.$1,
              scale: layout.$2,
              platform: platform,
              select: (tour) => selections.add(tour.tourId),
            );
            expect(find.text('Selecciona una gira'), findsOneWidget);
            for (final tour in tours) {
              final title = find.text(tour.clientName);
              await tester.scrollUntilVisible(
                title,
                180,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final card = find.byKey(ValueKey('tour-choice-${tour.tourId}'));
              expect(
                tester.getSemantics(card).hasFlag(SemanticsFlag.isButton),
                isTrue,
              );
              final rect = tester.getRect(card);
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(layout.$1.width));
              await tester.ensureVisible(title);
              final visible = tester
                  .getRect(title)
                  .intersect(tester.getRect(find.byType(CustomScrollView)));
              expect(visible.height, greaterThan(0));
              await tester.tapAt(visible.center);
              await tester.pumpAndSettle();
              expect(selections.last, tour.tourId);
              await tester.ensureVisible(find.text('Código ${tour.tourCode}'));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            expect(selections, [910001, 910002]);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets(
    'pending selection blocks all choices and gives textual feedback',
    (tester) async {
      var calls = 0;
      await show(
        tester,
        loadingId: 910001,
        reduceMotion: true,
        select: (_) => calls++,
      );
      expect(find.text('Abriendo gira…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      for (final tour in tours) {
        await tester.tap(find.text(tour.clientName));
      }
      expect(calls, 0);
      await show(tester, select: (_) => calls++);
      await tester.tap(find.text(tours.last.clientName));
      expect(calls, 1);
    },
  );

  testWidgets(
    'loading, empty and error are useful without exposing exception details',
    (tester) async {
      var retries = 0;
      await show(
        tester,
        snapshot: const AsyncSnapshot.waiting(),
        reduceMotion: true,
      );
      expect(find.text('Cargando tus giras…'), findsOneWidget);
      await show(
        tester,
        snapshot: const AsyncSnapshot.withData(ConnectionState.done, []),
        retry: () => retries++,
      );
      expect(find.text('No tienes giras asignadas.'), findsOneWidget);
      await tester.tap(find.text('Actualizar'));
      await show(
        tester,
        snapshot: AsyncSnapshot.withError(
          ConnectionState.done,
          Exception('internal details'),
        ),
        retry: () => retries++,
      );
      expect(find.text('No pudimos cargar tus giras.'), findsOneWidget);
      expect(find.textContaining('internal details'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      expect(retries, 2);
    },
  );

  testWidgets('dark appearance retains legibility and selection', (
    tester,
  ) async {
    var selected = 0;
    await show(
      tester,
      brightness: Brightness.dark,
      select: (tour) => selected = tour.tourId,
    );
    final title = tester.widget<Text>(find.text(tours.first.clientName));
    expect(title.style!.color, const Color(0xFFF0F6F3));
    await tester.tap(find.text(tours.first.clientName));
    expect(selected, 910001);
  });
}
