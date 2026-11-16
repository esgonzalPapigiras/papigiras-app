import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_change_password_sheet.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final capture = Platform.environment['PILO_PASSWORD_CAPTURE'] == '1';
  final boundary = GlobalKey();
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

  Future<void> snapshot(WidgetTester tester) async {
    if (!capture) return;
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File(
        'registro-local/PILO-CREDENCIALES-POR-ROL/evidencia/cambio-contrasena-apoderado-fixture.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  Future<void> open(
    WidgetTester tester, {
    required Future<void> Function(String, String) change,
    required Future<void> Function(String) remember,
    void Function(PiloPasswordChangeResult?)? onResult,
    double width = 393,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: PiloFamilyTheme.theme(ThemeData(useMaterial3: true)),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => RepaintBoundary(
          key: boundary,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Abrir'),
              onPressed: () async {
                final result = await showPiloChangePasswordSheet(
                  context,
                  attorneyPassword: true,
                  onChangePassword: change,
                  onUpdateRememberedPassword: remember,
                );
                onResult?.call(result);
                if (context.mounted)
                  showPiloPasswordChangeFeedback(context, result);
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> validFields(WidgetTester tester) async {
    await enter(tester, 'password-current', 'fixture-current');
    await enter(tester, 'password-new', 'fixture-next');
    await enter(tester, 'password-confirmation', 'fixture-next');
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('password-save'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('validates current, minimum length and confirmation before API', (
    tester,
  ) async {
    var apiCalls = 0;
    var storageCalls = 0;
    await open(
      tester,
      change: (_, _) async {
        apiCalls++;
      },
      remember: (_) async {
        storageCalls++;
      },
    );
    expect(
      find.textContaining(
        'Esta contraseña es sólo para tu acceso como apoderado.',
      ),
      findsOneWidget,
    );
    await snapshot(tester);
    await submit(tester);
    expect(find.text('Ingresa tu contraseña actual.'), findsOneWidget);
    expect(find.text('Usa al menos 6 caracteres.'), findsOneWidget);
    await enter(tester, 'password-current', 'fixture-current');
    await enter(tester, 'password-new', '🙂🙂🙂');
    await enter(tester, 'password-confirmation', '🙂🙂🙂');
    await submit(tester);
    expect(find.text('Usa al menos 6 caracteres.'), findsOneWidget);
    expect(apiCalls, 0);
    await enter(tester, 'password-new', 'fixture-next');
    await enter(tester, 'password-confirmation', 'different');
    await submit(tester);
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(apiCalls, 0);
    expect(storageCalls, 0);
  });

  testWidgets(
    'prevents duplicate submission and only remembers after server success',
    (tester) async {
      final completion = Completer<void>();
      final calls = <List<String>>[];
      final remembered = <String>[];
      PiloPasswordChangeResult? result;
      await open(
        tester,
        change: (current, next) {
          calls.add([current, next]);
          return completion.future;
        },
        remember: (next) async {
          remembered.add(next);
        },
        onResult: (value) => result = value,
      );
      await validFields(tester);
      await submit(tester);
      expect(calls, [
        ['fixture-current', 'fixture-next'],
      ]);
      expect(remembered, isEmpty);
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('password-save')),
      );
      expect(save.onPressed, isNull);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('password-close')))
            .onPressed,
        isNull,
      );
      completion.complete();
      await tester.pumpAndSettle();
      expect(remembered, ['fixture-next']);
      expect(result, PiloPasswordChangeResult.updated);
      expect(find.text('Contraseña actualizada.'), findsOneWidget);
      expect(find.byKey(const ValueKey('password-current')), findsNothing);
    },
  );

  for (final characters in [36, 37]) {
    testWidgets(
      'enforces BCrypt UTF-8 boundary with $characters accented characters',
      (tester) async {
        var calls = 0;
        await open(
          tester,
          change: (_, _) async {
            calls++;
          },
          remember: (_) async {},
        );
        final password = List.filled(characters, 'é').join();
        await enter(tester, 'password-current', 'fixture-current');
        await enter(tester, 'password-new', password);
        await enter(tester, 'password-confirmation', password);
        await submit(tester);
        await tester.pumpAndSettle();
        expect(calls, characters == 36 ? 1 : 0);
        if (characters == 37) {
          expect(
            find.textContaining('Esta contraseña es demasiado larga'),
            findsOneWidget,
          );
        }
      },
    );
  }

  testWidgets(
    'API failure retains form, does not change remembered credentials and permits retry',
    (tester) async {
      var calls = 0;
      var saved = 0;
      await open(
        tester,
        change: (_, _) async {
          if (++calls == 1) throw Exception('Revisa tu contraseña actual.');
        },
        remember: (_) async {
          saved++;
        },
      );
      await validFields(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Revisa tu contraseña actual.'), findsOneWidget);
      expect(saved, 0);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('password-current')),
            )
            .controller!
            .text,
        'fixture-current',
      );
      await submit(tester);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(saved, 1);
    },
  );

  testWidgets(
    'native storage failure reports successful password change without offering an API retry',
    (tester) async {
      var calls = 0;
      PiloPasswordChangeResult? result;
      await open(
        tester,
        change: (_, _) async {
          calls++;
        },
        remember: (_) async {
          throw Exception('Fixture storage unavailable');
        },
        onResult: (value) => result = value,
      );
      await validFields(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(result, PiloPasswordChangeResult.updatedWithoutRemembering);
      expect(
        find.textContaining('Contraseña actualizada. No se pudo guardar'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('password-save')), findsNothing);
    },
  );

  testWidgets(
    '320 wide, large text and keyboard keep fields and save reachable',
    (tester) async {
      await open(
        tester,
        width: 320,
        scale: 2,
        change: (_, _) async {},
        remember: (_) async {},
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      for (final key in [
        'password-current',
        'password-new',
        'password-confirmation',
        'password-save',
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.byKey(const ValueKey('password-close')));
      await tester.tap(find.byKey(const ValueKey('password-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('password-current')), findsNothing);
    },
  );
}
