import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_coordinator_summary.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';

CoordinatorTourDetail detail({
  Map<String, int> passengers = const {'M': 4, 'F': 4, 'AM': 1, 'AF': 1},
  Map<String, int>? diets = const {'Sin gluten': 2, 'Vegetariana': 1},
}) => CoordinatorTourDetail.fromJson({
  'tourId': 910001,
  'assignmentId': 910001,
  'passengerCountsBySex': passengers,
  'specialDietCounts': diets,
});

Future<void> showSummary(
  WidgetTester tester,
  PiloCoordinatorSummary summary, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: PiloFamilyTheme.theme(ThemeData()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(18), child: summary),
        ),
      ),
    ),
  );
  await tester.pump();
}

String shown(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
        .load();
  });

  testWidgets(
    'total does not add special diets twice; whole diet column opens',
    (tester) async {
      var opens = 0;
      await showSummary(
        tester,
        PiloCoordinatorSummary(detail: detail(), onOpenDiets: () => opens++),
      );
      expect(
        shown(tester, 'coordinator-passenger-total'),
        '10 pasajeros en esta gira',
      );
      expect(shown(tester, 'coordinator-student-total'), '8');
      expect(shown(tester, 'coordinator-companion-total'), '2');
      expect(shown(tester, 'home-special-diets-total'), '3');
      final column = find.byKey(const ValueKey('home-special-diets'));
      expect(tester.getSize(column).height, greaterThanOrEqualTo(48));
      await tester.tapAt(tester.getTopLeft(column) + const Offset(8, 8));
      expect(opens, 1);
      expect(
        tester.getSize(find.byType(PiloCoordinatorSummary)).height,
        lessThan(140),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('normalizes known codes and includes unclassified in total', (
    tester,
  ) async {
    await showSummary(
      tester,
      PiloCoordinatorSummary(
        detail: detail(
          passengers: {
            ' m ': 3,
            'f': 4,
            'AM': 1,
            'pm': 2,
            'APM': 1,
            'AF': 1,
            'PF': 2,
            'APF': 1,
            'desconocido': 2,
          },
        ),
      ),
    );
    expect(
      shown(tester, 'coordinator-passenger-total'),
      '17 pasajeros en esta gira',
    );
    expect(shown(tester, 'coordinator-student-total'), '7');
    expect(shown(tester, 'coordinator-companion-total'), '8');
    expect(find.text('2 sin clasificar'), findsOneWidget);
  });

  testWidgets('unavailable counts are not zero and error offers retry', (
    tester,
  ) async {
    var retries = 0;
    await showSummary(
      tester,
      PiloCoordinatorSummary(hasError: true, onRetry: () => retries++),
    );
    expect(
      shown(tester, 'coordinator-passenger-total'),
      'Resumen no disponible',
    );
    expect(shown(tester, 'coordinator-student-total'), '—');
    expect(shown(tester, 'coordinator-companion-total'), '—');
    expect(shown(tester, 'home-special-diets-total'), '—');
    await tester.tap(find.byKey(const ValueKey('coordinator-summary-retry')));
    expect(retries, 1);
  });

  testWidgets('loading never exposes retained old counts', (tester) async {
    await showSummary(
      tester,
      PiloCoordinatorSummary(detail: detail(), loading: true),
    );
    expect(shown(tester, 'coordinator-passenger-total'), 'Cargando pasajeros…');
    expect(shown(tester, 'coordinator-student-total'), '—');
    expect(shown(tester, 'home-special-diets-total'), '—');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('missing breakdown is unknown; explicit zero stays zero', (
    tester,
  ) async {
    var opens = 0;
    await showSummary(
      tester,
      PiloCoordinatorSummary(
        detail: detail(passengers: {}, diets: null),
        onOpenDiets: () => opens++,
      ),
    );
    expect(shown(tester, 'coordinator-student-total'), '—');
    expect(shown(tester, 'home-special-diets-total'), '—');
    await tester.tap(find.byKey(const ValueKey('home-special-diets')));
    expect(opens, 1);
    await showSummary(
      tester,
      PiloCoordinatorSummary(
        detail: detail(
          passengers: {'M': 0, 'F': 0, 'AM': 0, 'AF': 0},
          diets: {},
        ),
        onOpenDiets: () => opens++,
      ),
    );
    expect(
      shown(tester, 'coordinator-passenger-total'),
      '0 pasajeros en esta gira',
    );
    expect(shown(tester, 'coordinator-student-total'), '0');
    expect(shown(tester, 'home-special-diets-total'), '0');
    await tester.tap(find.byKey(const ValueKey('home-special-diets')));
    expect(opens, 2);
  });

  testWidgets(
    'independent diets route remains available during errors/loading',
    (tester) async {
      var opens = 0;
      for (final loading in [false, true]) {
        await showSummary(
          tester,
          PiloCoordinatorSummary(
            loading: loading,
            hasError: !loading,
            onOpenDiets: () => opens++,
          ),
        );
        expect(shown(tester, 'home-special-diets-total'), '—');
        await tester.tap(find.byKey(const ValueKey('home-special-diets')));
      }
      expect(opens, 2);
    },
  );

  for (final width in [280.0, 320.0, 390.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('remains readable at width $width and text scale $scale', (
        tester,
      ) async {
        var opens = 0;
        await showSummary(
          tester,
          PiloCoordinatorSummary(
            detail: detail(
              passengers: {'M': 470, 'F': 600, 'PM': 20, 'AF': 30},
            ),
            onOpenDiets: () => opens++,
          ),
          width: width,
          scale: scale,
        );
        final column = find.byKey(const ValueKey('home-special-diets'));
        await tester.ensureVisible(column);
        await tester.tap(column);
        expect(opens, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
