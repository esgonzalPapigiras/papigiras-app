import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_hito_discard_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  bool? result;
  setUpAll(() async {
    await (FontLoader(
      'Manjari',
    )..addFont(rootBundle.load('assets/fonts/Manjari-Regular.ttf'))).load();
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf')))
        .load();
  });

  Future<void> open(
    WidgetTester tester, {
    bool partial = false,
    double width = 390,
    double scale = 1,
  }) async {
    result = null;
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: const ValueKey('capture'), child: child!),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    barrierColor: Colors.black38,
                    builder: (_) => PiloHitoDiscardDialog(partial: partial),
                  );
                },
                child: const Text('Cerrar borrador de prueba'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cerrar borrador de prueba'));
    await tester.pumpAndSettle();
  }

  testWidgets('safe action cancels discard and explicit discard returns true', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('¿Descartar este hito?'), findsOneWidget);
    if (Platform.environment['PILO_R2_CAPTURE'] == '1') {
      await tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('capture')),
            )
            .toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(
            'registro-local/PILO-HITO-UBICACION-R2/evidencias',
          );
          await dir.create(recursive: true);
          await File(
            '${dir.path}/descartar-hito-fixture.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(result, false);
    await tester.tap(find.text('Cerrar borrador de prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(result, true);
  });

  testWidgets(
    'partial upload warning stays explicit and accessible on narrow enlarged text',
    (tester) async {
      await open(tester, partial: true, width: 320, scale: 1.6);
      expect(find.text('¿Salir del hito?'), findsOneWidget);
      expect(find.textContaining('Revisa la bitácora antes'), findsOneWidget);
      expect(find.text('Salir').hitTestable(), findsOneWidget);
      expect(find.text('Seguir editando').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result, null);
      expect(find.byType(PiloHitoDiscardDialog), findsNothing);
    },
  );
}
