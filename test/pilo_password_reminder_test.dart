import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/pilo_password_reminder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final capture = Platform.environment['PILO_LOGIN_CAPTURE'] == '1';
  final boundary = GlobalKey();
  var completed = false;

  setUpAll(() async {
    await Future.wait([
      (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load(),
      (FontLoader(
        'Manjari',
      )..addFont(rootBundle.load('assets/fonts/Manjari-Regular.ttf'))).load(),
      (FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
          .load(),
    ]);
  });

  Future<void> open(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
    double scale = 1,
  }) async {
    completed = false;
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.deepPurple,
        ),
        builder: (context, child) => RepaintBoundary(
          key: boundary,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: TextButton(
                key: const Key('show-reminder'),
                onPressed: () async {
                  await showPiloPasswordReminder(context);
                  completed = true;
                },
                child: const Text('Acceso Pilo'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('show-reminder')));
    await tester.pumpAndSettle();
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    if (!capture) return;
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('registro-local/PILO-LOGIN-PULIDO/evidencia/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  testWidgets(
    'explicit Pilo theme overrides legacy lavender and keeps reminder compact',
    (tester) async {
      await open(tester);
      final dialog = tester.widget<Dialog>(
        find.byKey(const Key('pilo-password-reminder')),
      );
      expect(dialog.backgroundColor, PiloFamilyTheme.paper);
      expect(dialog.surfaceTintColor, Colors.transparent);
      expect(
        (dialog.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(32),
      );
      final button = find.byKey(const Key('pilo-password-reminder-continue'));
      final theme = Theme.of(tester.element(button));
      expect(PiloFamilyTheme.isActive(tester.element(button)), isTrue);
      expect(
        theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
        PiloFamilyTheme.mint,
      );
      expect(
        tester.widget<Text>(find.text('Cuida tu cuenta')).style!.fontFamily,
        'Manjari',
      );
      expect(find.textContaining('cambiarla desde tu perfil'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(
        tester.getSize(find.byType(SingleChildScrollView)).height,
        lessThan(400),
      );
      expect(completed, isFalse);
      await snapshot(tester, 'password-reminder-fixture');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Continue closes just the reminder and returns to its caller', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('pilo-password-reminder-continue')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.byKey(const Key('pilo-password-reminder')), findsNothing);
    expect(find.text('Acceso Pilo'), findsOneWidget);
  });

  testWidgets(
    'barrier dismissal remains available without forcing a password change',
    (tester) async {
      await open(tester);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(find.byKey(const Key('pilo-password-reminder')), findsNothing);
    },
  );

  testWidgets(
    '320 width and 200 percent text permit scrolling and Continue without overflow',
    (tester) async {
      await open(tester, width: 320, height: 568, scale: 2);
      expect(tester.takeException(), isNull);
      await snapshot(tester, 'password-reminder-320-texto200-fixture');
      final button = find.byKey(const Key('pilo-password-reminder-continue'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
