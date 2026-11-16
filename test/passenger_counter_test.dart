import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/utils/LocationService.dart';

List<PassengerList> roster() => [
  PassengerList.fromJson({
    'passengerId': 910011,
    'passengerName': 'Sofía',
    'passengerApellidos': 'Ejemplo LAB',
    'passengerverificate': true,
  }),
  PassengerList.fromJson({
    'passengerId': 910012,
    'passengerName': 'Mateo Ejemplo LAB',
    'passengerApellidos': 'Ejemplo LAB',
    'passengerverificate': false,
  }),
  PassengerList.fromJson({
    'passengerId': 910013,
    'passengerName': 'Valentina Ejemplo LAB',
    'passengerverificate': false,
    'passengerSex': 'AF',
  }),
];

void main() {
  setUp(() async {
    LabMode.useFixturesForTests(true);
    await (await SharedPreferences.getInstance()).clear();
  });
  tearDown(() => LabMode.useFixturesForTests(false));

  Future<void> show(
    WidgetTester tester, {
    Future<List<PassengerList>> Function(String)? load,
    String? scannedId = '910012',
    Size size = const Size(402, 874),
    double scale = 1,
    TargetPlatform platform = TargetPlatform.iOS,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocationService(),
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: CountDownCoordScreen(
            login: TourSales.fromJson({'tourSalesId': 910001}),
            passengerLoader:
                load ??
                (id) async {
                  expect(id, '910001');
                  return roster();
                },
            qrScannerBuilder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, scannedId),
                  child: const Text('Entregar QR de prueba'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void expectCounts(WidgetTester tester, String counted, String pending) {
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('counter-counted'))).data,
      counted,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('counter-pending'))).data,
      pending,
    );
  }

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('counter-scan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregar QR de prueba'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'counts all passengers including companions and preserves stored verification',
    (tester) async {
      await show(tester);
      await tester.pumpAndSettle();
      expectCounts(tester, '1', '2');
      expect(find.text('3 pasajeros'), findsOneWidget);
      expect(find.text('Sofía Ejemplo LAB'), findsOneWidget);
      expect(find.text('Mateo Ejemplo LAB Ejemplo LAB'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('QR counts a passenger once, preserving results on return', (
    tester,
  ) async {
    await show(tester);
    await tester.pumpAndSettle();
    await scan(tester);
    expectCounts(tester, '2', '1');
    await scan(tester);
    expectCounts(tester, '2', '1');
    expect(
      find.text('Mateo Ejemplo LAB ya está contabilizado.'),
      findsOneWidget,
    );
  });
  testWidgets('QR from another tour does not change totals', (tester) async {
    await show(tester, scannedId: '999999');
    await tester.pumpAndSettle();
    await scan(tester);
    expectCounts(tester, '1', '2');
    expect(
      find.text('Este QR no corresponde a un pasajero de esta gira.'),
      findsOneWidget,
    );
  });
  testWidgets('closing the scanner is silent and preserves counts', (
    tester,
  ) async {
    await show(tester, scannedId: null);
    await tester.pumpAndSettle();
    await scan(tester);
    expectCounts(tester, '1', '2');
    expect(find.byType(SnackBar), findsNothing);
  });
  testWidgets('manual correction updates totals and the pending filter', (
    tester,
  ) async {
    await show(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('counter-filter-pending')));
    await tester.pumpAndSettle();
    expect(find.text('Sofía Ejemplo LAB'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('counter-passenger-910012')));
    await tester.pumpAndSettle();
    expectCounts(tester, '2', '1');
    expect(find.text('Mateo Ejemplo LAB'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('counter-filter-counted')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('counter-passenger-910012')));
    await tester.pumpAndSettle();
    expectCounts(tester, '1', '2');
  });
  testWidgets('reset requires confirmation and clears only current count', (
    tester,
  ) async {
    var loads = 0;
    await show(
      tester,
      load: (_) async {
        loads++;
        return roster();
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('counter-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expectCounts(tester, '1', '2');
    await tester.tap(find.byKey(const ValueKey('counter-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reiniciar'));
    await tester.pumpAndSettle();
    expectCounts(tester, '0', '3');
    expect(loads, 1);
  });
  testWidgets(
    'shows loading instead of false zero counts then renders real result',
    (tester) async {
      final response = Completer<List<PassengerList>>();
      await show(tester, load: (_) => response.future);
      expect(find.text('Cargando pasajeros…'), findsOneWidget);
      expect(find.byKey(const ValueKey('counter-summary')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('counter-scan')))
            .onPressed,
        isNull,
      );
      response.complete(roster());
      await tester.pumpAndSettle();
      expectCounts(tester, '1', '2');
    },
  );
  testWidgets('load failure offers retry without reporting everyone missing', (
    tester,
  ) async {
    var attempts = 0;
    await show(
      tester,
      load: (_) async {
        if (attempts++ == 0) throw StateError('synthetic');
        return roster();
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar los pasajeros.'), findsOneWidget);
    expect(find.byKey(const ValueKey('counter-summary')), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expectCounts(tester, '1', '2');
  });
  testWidgets('empty roster has clear state with scanning disabled', (
    tester,
  ) async {
    await show(tester, load: (_) async => []);
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay pasajeros en esta gira.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('counter-scan')))
          .onPressed,
      isNull,
    );
  });
  testWidgets('completing all passengers reports zero pending', (tester) async {
    await show(tester, load: (_) async => [roster().first]);
    await tester.pumpAndSettle();
    expectCounts(tester, '1', '0');
    await tester.tap(find.byKey(const ValueKey('counter-filter-pending')));
    await tester.pumpAndSettle();
    expect(find.text('Todos están contabilizados.'), findsOneWidget);
  });
  testWidgets(
    'late loading completion after disposal does not update an unmounted page',
    (tester) async {
      final response = Completer<List<PassengerList>>();
      await show(tester, load: (_) => response.future);
      await tester.pumpWidget(const SizedBox());
      response.complete(roster());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'summary and manual switches expose labels to assistive technology',
    (tester) async {
      final handle = tester.ensureSemantics();

      await show(tester);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Contabilizados: 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Faltan: 2'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Mateo Ejemplo LAB')), findsWidgets);
      handle.dispose();
    },
  );
  for (final entry in [
    (const Size(320, 568), 1.0, TargetPlatform.iOS),
    (const Size(320, 568), 2.0, TargetPlatform.iOS),
    (const Size(320, 568), 3.0, TargetPlatform.android),
    (const Size(844, 390), 1.3, TargetPlatform.iOS),
    (const Size(402, 874), 1.0, TargetPlatform.android),
  ]) {
    testWidgets(
      'layout and scanner remain usable ${entry.$1} scale ${entry.$2} ${entry.$3}',
      (tester) async {
        await show(tester, size: entry.$1, scale: entry.$2, platform: entry.$3);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('counter-scan')).hitTestable(),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('counter-passenger-910013')),
          100,
          scrollable: find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(const ValueKey('counter-passenger-910013')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
