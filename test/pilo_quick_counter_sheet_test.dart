import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/design/passenger_counter_session.dart';
import 'package:papigiras_app/design/passenger_counter_view.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/utils/LocationService.dart';

List<PassengerList> _roster() => [
  PassengerList.fromJson({
    'passengerId': 910011,
    'passengerName': 'Sofía Ejemplo LAB',
    'passengerverificate': true,
  }),
  PassengerList.fromJson({
    'passengerId': 910012,
    'passengerName': 'Mateo Ejemplo LAB',
    'passengerverificate': false,
  }),
  PassengerList.fromJson({
    'passengerId': 910013,
    'passengerName': 'Valentina Ejemplo LAB',
    'passengerverificate': false,
    'passengerSex': 'AF',
  }),
];

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final capture = Platform.environment['PILO_COUNTER_R2_CAPTURE'] == '1';
  setUpAll(() async {
    if (!capture) return;
    await Future.wait([
      (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load(),
      (FontLoader('CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load(),
      (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load(),
      (FontLoader(
        'Manjari',
      )..addFont(rootBundle.load('assets/fonts/Manjari-Regular.ttf'))).load(),
      (FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
          .load(),
    ]);
  });

  Future<void> captureFixture(WidgetTester tester, String name) async {
    if (!capture) return;
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(_key('counter-fixture-capture'))
          .toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory(
          'registro-local/PILO-CONTADOR-R2/evidencias',
        );
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  setUp(() async {
    LabMode.useFixturesForTests(true);
    await (await SharedPreferences.getInstance()).clear();
  });
  tearDown(() => LabMode.useFixturesForTests(false));

  Future<PassengerCounterSession> show(
    WidgetTester tester, {
    PassengerCounterSession? session,
    Future<List<PassengerList>> Function(String)? load,
    String? Function()? scanResult,
    Size size = const Size(402, 874),
    double scale = 1,
    bool reducedMotion = false,
    int tour = 910001,
    int coordinator = 910001,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state =
        session ??
        PassengerCounterSession(tourId: tour, coordinatorId: coordinator);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocationService(),
        child: MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            fontFamily: capture ? 'Inter' : null,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion,
              padding: const EdgeInsets.only(top: 59, bottom: 34),
            ),
            child: capture
                ? RepaintBoundary(
                    key: const ValueKey('counter-fixture-capture'),
                    child: child!,
                  )
                : child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open-counter'),
                  onPressed: () => showPiloPassengerCounter(
                    context,
                    login: TourSales.fromJson({
                      'tourSalesId': tour,
                      'coordinatorId': coordinator,
                    }),
                    session: state,
                    passengerLoader: load ?? (_) async => _roster(),
                    qrScannerBuilder: (context) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pop(context, scanResult?.call()),
                          child: const Text('Entregar QR sintético'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Abrir contador'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(_key('open-counter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return state;
  }

  void quick(WidgetTester tester, int count, [int total = 3]) {
    expect(
      tester.widget<Semantics>(_key('quick-counter-value')).properties.label,
      'Conteo rápido: $count de $total pasajeros',
    );
  }

  void noQuickInFull() {
    expect(find.textContaining('Conteo rápido'), findsNothing);
    expect(_key('quick-counter-value'), findsNothing);
    expect(_key('quick-counter-reset'), findsNothing);
    expect(_key('counter-quick-reference'), findsNothing);
  }

  void identified(WidgetTester tester, int count) =>
      expect(tester.widget<Text>(_key('counter-counted')).data, '$count');

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(_key(key));
    await tester.pumpAndSettle();
  }

  Future<void> deliverScan(WidgetTester tester) async {
    await tester.tap(find.text('Entregar QR sintético'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'opens compact, manual count includes companions and stays in bounds',
    (tester) async {
      final session = await show(tester);
      await tester.pumpAndSettle();
      quick(tester, 0);
      expect(_key('counter-summary'), findsNothing);
      expect(
        tester.widget<IconButton>(_key('quick-counter-reset')).onPressed,
        isNull,
      );
      expect(find.byTooltip('Reiniciar conteo rápido'), findsOneWidget);
      expect(
        tester.getSize(_key('passenger-counter-sheet')).height,
        lessThan(400),
      );
      expect(
        tester.widget<IconButton>(_key('quick-counter-decrement')).onPressed,
        isNull,
      );
      for (var i = 0; i < 3; i++) {
        await tap(tester, 'quick-counter-increment');
      }
      quick(tester, 3);
      expect(
        tester.widget<IconButton>(_key('quick-counter-increment')).onPressed,
        isNull,
      );
      expect(
        session.verified,
        isEmpty,
        reason: 'Anonymous taps never identify a passenger.',
      );
      await tap(tester, 'quick-counter-decrement');
      quick(tester, 2);
    },
  );

  testWidgets(
    'expand and collapse preserve tally and never reload the roster',
    (tester) async {
      var loads = 0;
      await show(
        tester,
        load: (_) async {
          loads++;
          return _roster();
        },
      );
      await tester.pumpAndSettle();
      await tap(tester, 'quick-counter-increment');
      await tap(tester, 'quick-counter-increment');
      await captureFixture(tester, 'contador-compacto-fixture');
      await tap(tester, 'quick-counter-expand');
      noQuickInFull();
      identified(tester, 1);
      await captureFixture(tester, 'contador-completo-fixture');
      await tap(tester, 'counter-sheet-grabber');
      quick(tester, 2);
      expect(loads, 1);
    },
  );

  testWidgets('upward grabber drag expands and downward drag can close', (
    tester,
  ) async {
    await show(tester);
    await tester.pumpAndSettle();
    await tester.drag(_key('counter-sheet-grabber'), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(_key('counter-summary'), findsOneWidget);
    await tester.drag(_key('counter-sheet-grabber'), const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(_key('passenger-counter-sheet'), findsNothing);
    expect(_key('open-counter').hitTestable(), findsOneWidget);
  });

  testWidgets('one upward swipe on compact body opens the complete counter', (
    tester,
  ) async {
    await show(tester);
    await tester.pumpAndSettle();
    await tester.drag(find.text('Conteo rápido'), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.byType(PassengerCounterView), findsOneWidget);
    expect(_key('counter-scan').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag to the minimum dismisses only the counter sheet', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Página anterior')),
      ),
    );
    navigator.currentState!.push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showPiloPassengerCounter(
              context,
              login: TourSales.fromJson({
                'tourSalesId': 910001,
                'coordinatorId': 910001,
              }),
              passengerLoader: (_) async => _roster(),
            ),
            child: const Text('Inicio del coordinador'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio del coordinador'));
    await tester.pumpAndSettle();
    await tester.drag(_key('counter-sheet-grabber'), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(_key('passenger-counter-sheet'), findsNothing);
    expect(find.text('Inicio del coordinador').hitTestable(), findsOneWidget);
    expect(find.text('Página anterior'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'QR opens full counter; valid duplicate and foreign QR do not alter quick tally',
    (tester) async {
      var code = '910012';
      await show(tester, scanResult: () => code);
      await tester.pumpAndSettle();
      await tap(tester, 'quick-counter-increment');
      await tap(tester, 'quick-counter-increment');
      await tap(tester, 'quick-counter-scan');
      expect(find.text('Entregar QR sintético'), findsOneWidget);
      await deliverScan(tester);
      expect(_key('counter-summary'), findsOneWidget);
      identified(tester, 2);
      noQuickInFull();
      await tap(tester, 'counter-scan');
      await deliverScan(tester);
      identified(tester, 2);
      code = '910001';
      await tap(tester, 'counter-scan');
      await deliverScan(tester);
      identified(tester, 2);
      expect(
        find.text('Este QR no corresponde a un pasajero de esta gira.'),
        findsOneWidget,
      );
      await tap(tester, 'counter-sheet-grabber');
      quick(tester, 2);
    },
  );

  testWidgets('cancelling QR returns to full counter without resetting tally', (
    tester,
  ) async {
    await show(tester);
    await tester.pumpAndSettle();
    await tap(tester, 'quick-counter-increment');
    await tap(tester, 'quick-counter-scan');
    await deliverScan(tester);
    identified(tester, 1);
    noQuickInFull();
    await tap(tester, 'counter-sheet-grabber');
    quick(tester, 1);
  });

  testWidgets('closing during QR expansion never opens a delayed scanner', (
    tester,
  ) async {
    final session = await show(tester);
    await tester.pumpAndSettle();
    await tap(tester, 'quick-counter-increment');
    await tester.tap(_key('quick-counter-scan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tap(tester, 'quick-counter-close');
    await tester.pump(const Duration(seconds: 1));
    expect(_key('passenger-counter-sheet'), findsNothing);
    expect(find.text('Entregar QR sintético'), findsNothing);
    expect(_key('open-counter').hitTestable(), findsOneWidget);
    expect(session.quickCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dragging the body interrupts QR expansion without losing count',
    (tester) async {
      await show(tester);
      await tester.pumpAndSettle();
      await tap(tester, 'quick-counter-increment');
      await tester.tap(_key('quick-counter-scan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.drag(find.text('Conteo rápido'), const Offset(0, 40));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Entregar QR sintético'), findsNothing);
      quick(tester, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'close and reopen preserve quick and named checks in same session',
    (tester) async {
      await show(tester, scanResult: () => '910012');
      await tester.pumpAndSettle();
      await tap(tester, 'quick-counter-increment');
      await tap(tester, 'quick-counter-scan');
      await deliverScan(tester);
      await tap(tester, 'counter-sheet-grabber');
      await tap(tester, 'quick-counter-close');
      await tap(tester, 'open-counter');
      quick(tester, 1);
      await tap(tester, 'quick-counter-expand');
      identified(tester, 2);
    },
  );

  for (final mismatch in ['tour', 'coordinator']) {
    testWidgets(
      'a different $mismatch does not inherit another count session',
      (tester) async {
        final previous = PassengerCounterSession(
          tourId: mismatch == 'tour' ? 910011 : 910001,
          coordinatorId: mismatch == 'coordinator' ? 910011 : 910001,
        )..quickCount = 2;
        previous.verified['910012'] = true;
        await show(tester, session: previous);
        await tester.pumpAndSettle();
        quick(tester, 0);
        await tap(tester, 'quick-counter-expand');
        identified(tester, 1);
        expect(previous.quickCount, 2);
      },
    );
  }

  testWidgets('load and error states show no invented zero and retry works', (
    tester,
  ) async {
    final loading = Completer<List<PassengerList>>();
    var attempts = 0;
    await show(
      tester,
      load: (_) {
        attempts++;
        return attempts == 1 ? loading.future : Future.value(_roster());
      },
    );
    expect(find.text('Cargando pasajeros…'), findsOneWidget);
    expect(
      tester.widget<IconButton>(_key('quick-counter-reset')).onPressed,
      isNull,
    );
    expect(_key('quick-counter-value'), findsNothing);
    expect(
      tester.widget<FilledButton>(_key('quick-counter-scan')).onPressed,
      isNull,
    );
    loading.completeError(StateError('synthetic failure'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar los pasajeros.'), findsOneWidget);
    expect(
      tester.widget<IconButton>(_key('quick-counter-reset')).onPressed,
      isNull,
    );
    expect(_key('quick-counter-value'), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    quick(tester, 0);
  });

  testWidgets('empty roster disables scan and does not show a false count', (
    tester,
  ) async {
    await show(tester, load: (_) async => []);
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay pasajeros en esta gira.'), findsOneWidget);
    expect(
      tester.widget<IconButton>(_key('quick-counter-reset')).onPressed,
      isNull,
    );
    expect(_key('quick-counter-value'), findsNothing);
    expect(
      tester.widget<FilledButton>(_key('quick-counter-scan')).onPressed,
      isNull,
    );
  });

  testWidgets(
    'full reset clears identified passengers only and keeps quick tally',
    (tester) async {
      final session = await show(tester);
      await tester.pumpAndSettle();
      await tap(tester, 'quick-counter-increment');
      await tap(tester, 'quick-counter-expand');
      await tap(tester, 'counter-reset');
      expect(
        find.text('Todos los pasajeros quedarán pendientes de verificar.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(session.quickCount, 1);
      identified(tester, 1);
      await tap(tester, 'counter-reset');
      await tester.tap(find.text('Reiniciar'));
      await tester.pumpAndSettle();
      expect(session.quickCount, 1);
      identified(tester, 0);
      noQuickInFull();
      expect(
        tester.widget<IconButton>(_key('counter-reset')).onPressed,
        isNull,
      );
      await tap(tester, 'counter-sheet-grabber');
      quick(tester, 1);
      await tap(tester, 'quick-counter-close');
      await tap(tester, 'open-counter');
      quick(tester, 1);
      await tap(tester, 'quick-counter-expand');
      identified(tester, 0);
    },
  );

  testWidgets('compact reset preserves QR verification and survives reopen', (
    tester,
  ) async {
    final session = await show(tester, scanResult: () => '910012');
    await tester.pumpAndSettle();
    await tap(tester, 'quick-counter-increment');
    await tap(tester, 'quick-counter-increment');
    await tap(tester, 'quick-counter-scan');
    await deliverScan(tester);
    identified(tester, 2);
    noQuickInFull();
    expect(session.verified['910012'], isTrue);
    await tap(tester, 'counter-sheet-grabber');
    quick(tester, 2);
    final checks = Map<String, bool>.from(session.verified);
    expect(
      tester.widget<IconButton>(_key('quick-counter-reset')).onPressed,
      isNotNull,
    );
    await tap(tester, 'quick-counter-reset');
    quick(tester, 0);
    expect(session.verified, checks);
    expect(find.text('¿Reiniciar el conteo?'), findsNothing);
    expect(
      tester.widget<IconButton>(_key('quick-counter-reset')).onPressed,
      isNull,
    );
    await tap(tester, 'quick-counter-expand');
    identified(tester, 2);
    noQuickInFull();
    await tap(tester, 'counter-sheet-grabber');
    await tap(tester, 'quick-counter-close');
    await tap(tester, 'open-counter');
    quick(tester, 0);
    await tap(tester, 'quick-counter-expand');
    identified(tester, 2);
    noQuickInFull();
  });

  testWidgets(
    'compact reset preserves manual named verification and unchecking',
    (tester) async {
      final session = await show(tester);
      await tester.pumpAndSettle();
      await tap(tester, 'quick-counter-increment');
      await tap(tester, 'quick-counter-expand');
      await tap(tester, 'counter-passenger-910011');
      await tap(tester, 'counter-passenger-910013');
      identified(tester, 1);
      noQuickInFull();
      final checks = Map<String, bool>.from(session.verified);
      expect(checks, {'910011': false, '910013': true});
      await tap(tester, 'counter-sheet-grabber');
      await tap(tester, 'quick-counter-reset');
      quick(tester, 0);
      expect(session.verified, checks);
      await tap(tester, 'quick-counter-expand');
      identified(tester, 1);
      noQuickInFull();
    },
  );

  testWidgets('reduced motion supports button expansion and quick return', (
    tester,
  ) async {
    await show(tester, reducedMotion: true);
    await tester.pumpAndSettle();
    await tap(tester, 'quick-counter-expand');
    expect(_key('counter-summary'), findsOneWidget);
    await tap(tester, 'counter-sheet-grabber');
    quick(tester, 0);
  });

  for (final layout in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 3.0),
    (const Size(844, 390), 1.3),
  ]) {
    testWidgets(
      'compact and full adapt without overflow ${layout.$1} scale ${layout.$2}',
      (tester) async {
        await show(tester, size: layout.$1, scale: layout.$2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_key('quick-counter-close').hitTestable(), findsOneWidget);
        expect(_key('quick-counter-reset').hitTestable(), findsOneWidget);
        await tester.ensureVisible(_key('quick-counter-scan'));
        await tester.pumpAndSettle();
        expect(_key('quick-counter-scan').hitTestable(), findsOneWidget);
        await tester.ensureVisible(_key('quick-counter-expand'));
        await tester.pumpAndSettle();
        expect(_key('quick-counter-expand').hitTestable(), findsOneWidget);
        await tap(tester, 'counter-sheet-grabber');
        expect(find.byType(PassengerCounterView), findsOneWidget);
        noQuickInFull();
        expect(_key('counter-scan').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
