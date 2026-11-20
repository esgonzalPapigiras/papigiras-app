import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:papigiras_app/design/passenger_counter_session.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/utils/LocationService.dart';

class _PopObserver extends NavigatorObserver {
  Completer<void> popped = Completer<void>();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!popped.isCompleted) popped.complete();
  }
}

Future<Uint8List> _qrImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 320, 320),
    Paint()..color = Colors.white,
  );
  canvas.translate(20, 20);
  QrPainter(
    data: 'papigiras-lab:passenger/910012',
    version: QrVersions.auto,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Colors.black,
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Colors.black,
    ),
  ).paint(canvas, const Size(280, 280));
  final picture = recorder.endRecording();
  final image = await picture.toImage(320, 320);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

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

Finder _key(String value) => find.byKey(ValueKey(value));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List image;
  late ValueChanged<String> reportCameraError;
  late PassengerCounterSession session;
  late _PopObserver observer;

  setUpAll(() async => image = await _qrImage());
  setUp(() async {
    LabMode.useFixturesForTests(true);
    await (await SharedPreferences.getInstance()).clear();
    session = PassengerCounterSession(tourId: 910001, coordinatorId: 910001)
      ..quickCount = 2;
    observer = _PopObserver();
  });
  tearDown(() => LabMode.useFixturesForTests(false));

  Future<void> open(
    WidgetTester tester, {
    Future<Uint8List?> Function()? gallery,
    Size size = const Size(402, 874),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocationService(),
        child: MaterialApp(
          navigatorObservers: [observer],
          theme: ThemeData(platform: TargetPlatform.iOS),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open-counter'),
                onPressed: () => showPiloPassengerCounter(
                  context,
                  login: TourSales.fromJson({
                    'tourSalesId': 910001,
                    'coordinatorId': 910001,
                  }),
                  session: session,
                  passengerLoader: (_) async => _roster(),
                  qrScannerBuilder: (_) => QRViewExample(
                    cameraBuilder: (_, onError) {
                      reportCameraError = onError;
                      return const SizedBox.expand(
                        key: ValueKey('synthetic-camera-surface'),
                      );
                    },
                    galleryImageLoader: gallery ?? () async => null,
                  ),
                ),
                child: const Text('Abrir contador'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(_key('open-counter'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('quick-counter-scan'));
    await tester.tap(_key('quick-counter-scan'));
    await tester.pumpAndSettle();
  }

  Future<void> unavailable(WidgetTester tester) async {
    reportCameraError('camera_unavailable');
    await tester.pumpAndSettle();
    expect(find.text('Cámara no disponible'), findsOneWidget);
    expect(_key('synthetic-camera-surface'), findsNothing);
  }

  void expectUnchanged(WidgetTester tester) {
    expect(session.quickCount, 2);
    expect(find.textContaining('Conteo rápido'), findsNothing);
    expect(_key('quick-counter-value'), findsNothing);
    expect(_key('counter-quick-reference'), findsNothing);
    expect(tester.widget<Text>(_key('counter-counted')).data, '1');
    expect(tester.widget<Text>(_key('counter-pending')).data, '2');
  }

  testWidgets(
    'available camera surface keeps normal reader and gallery action',
    (tester) async {
      await open(tester);
      expect(_key('synthetic-camera-surface'), findsOneWidget);
      expect(find.text('Cámara no disponible'), findsNothing);
      expect(find.text('Lector QR'), findsOneWidget);
      expect(find.text('Leer QR desde Galería').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native camera error shows fallback and Back preserves both counts',
    (tester) async {
      await open(tester);
      await unavailable(tester);
      expect(find.text('Leer QR desde Galería').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expectUnchanged(tester);
      expect(find.byType(QRViewExample), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('gallery cancellation keeps fallback and counts intact', (
    tester,
  ) async {
    var picks = 0;
    await open(
      tester,
      gallery: () async {
        picks++;
        return null;
      },
    );
    await unavailable(tester);
    await tester.tap(find.text('Leer QR desde Galería'));
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(find.text('Cámara no disponible'), findsOneWidget);
    expect(find.text('Leer QR desde Galería').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expectUnchanged(tester);
  });

  testWidgets(
    'fallback decodes gallery QR and verifies passenger without losing tally',
    (tester) async {
      await open(tester, gallery: () async => image);
      await unavailable(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Leer QR desde Galería'));
        await observer.popped.future.timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(session.quickCount, 2);
      expect(tester.widget<Text>(_key('counter-counted')).data, '2');
      expect(tester.widget<Text>(_key('counter-pending')).data, '1');
      expect(session.verified['910012'], isTrue);
      expect(find.textContaining('Conteo rápido'), findsNothing);
      expect(_key('quick-counter-value'), findsNothing);
      expect(_key('counter-quick-reference'), findsNothing);
      expect(find.byType(QRViewExample), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed gallery load keeps fallback actionable without resetting tally',
    (tester) async {
      await open(tester, gallery: () async => throw StateError('synthetic'));
      await unavailable(tester);
      await tester.tap(find.text('Leer QR desde Galería'));
      await tester.pumpAndSettle();
      expect(
        find.text('No se encontró un QR válido de Papigiras en la imagen.'),
        findsOneWidget,
      );
      expect(find.text('Leer QR desde Galería').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expectUnchanged(tester);
    },
  );

  testWidgets(
    'camera callback after reader disposal cannot alter the counter',
    (tester) async {
      await open(tester);
      final lateError = reportCameraError;
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      lateError('camera_unavailable');
      await tester.pumpAndSettle();
      expectUnchanged(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('camera fallback remains usable at $size with enlarged text', (
      tester,
    ) async {
      await open(tester, size: size, textScale: 1.5);
      await unavailable(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Leer QR desde Galería'));
      await tester.pumpAndSettle();
      expect(find.text('Leer QR desde Galería').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Volver').hitTestable(), findsOneWidget);
    });
  }
}
