import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/pilo_student_medical_sheet.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/lab/media.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.directory);
  final Directory directory;
  Future<String?> Function()? temporary;
  @override
  Future<String?> getTemporaryPath() async =>
      temporary == null ? directory.path : await temporary!();
}

class _SavePicker extends FilePicker {
  Future<String?> Function(Uint8List, String)? save;
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    expect(type, FileType.custom);
    expect(allowedExtensions, ['pdf']);
    return save?.call(bytes!, fileName!);
  }
}

Uint8List _pdf() =>
    Uint8List.fromList(utf8.encode('%PDF-1.4\n% synthetic LAB\n'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => FilePicker.platform = _SavePicker());
  late Directory root;
  late _Paths paths;
  late PathProviderPlatform originalPaths;
  late FilePicker originalPicker;
  late _SavePicker picker;
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  setUp(() {
    root = Directory.systemTemp.createTempSync('pilo-medical-synthetic-');
    originalPaths = PathProviderPlatform.instance;
    paths = _Paths(root);
    PathProviderPlatform.instance = paths;
    originalPicker = FilePicker.platform;
    picker = _SavePicker();
    FilePicker.platform = picker;
  });
  tearDown(() {
    PathProviderPlatform.instance = originalPaths;
    FilePicker.platform = originalPicker;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> flush(WidgetTester tester) async {
    // File I/O crosses the widget test's fake-async boundary at each stage.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      await tester.pump();
    }
  }

  Future<void> show(
    WidgetTester tester, {
    required Future<Uint8List> Function() loadPdf,
    ValueChanged<String>? onPdf,
    double width = 393,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 852);
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
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPiloStudentMedicalSheet(
                context,
                studentName: 'Estudiante Ejemplo',
                studentIdentification: '99.000.011-5',
                loadPdf: loadPdf,
                pdfBuilder: (context, path) {
                  onPdf?.call(path);
                  return const Center(child: Text('PDF original de prueba'));
                },
              ),
              child: const Text('Abrir ficha'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir ficha'));
    await tester.pump();
    await flush(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'opens exact PDF bytes in a read-only Pilo sheet and deletes on close',
    (tester) async {
      String? path;
      await show(
        tester,
        loadPdf: () async => _pdf(),
        onPdf: (value) => path = value,
      );
      expect(find.text('PDF original de prueba'), findsOneWidget);
      expect(File(path!).readAsBytesSync(), _pdf());
      expect(path, startsWith(root.path));
      expect(path, isNot(contains('Estudiante')));
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('Editar'), findsNothing);
      expect(find.text('Compartir').hitTestable(), findsOneWidget);
      expect(find.text('Descargar').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar ficha médica'));
      await tester.pumpAndSettle();
      await flush(tester);
      expect(find.byType(PiloStudentMedicalSheet), findsNothing);
      expect(File(path!).existsSync(), isFalse);
    },
  );

  testWidgets('load failures are generic and retry retrieves the PDF', (
    tester,
  ) async {
    var attempts = 0;
    await show(
      tester,
      loadPdf: () async {
        if (attempts++ == 0) throw Exception('private details must not show');
        return _pdf();
      },
    );
    expect(find.text('No pudimos abrir tu ficha médica.'), findsOneWidget);
    expect(find.textContaining('private details'), findsNothing);
    expect(find.text('Compartir'), findsNothing);
    expect(find.text('Descargar'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('student-medical-retry')));
    await tester.pump();
    await flush(tester);
    expect(attempts, 2);
    expect(find.text('PDF original de prueba'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
  });

  testWidgets('non-PDF response never reaches viewer or temporary storage', (
    tester,
  ) async {
    await show(
      tester,
      loadPdf: () async =>
          Uint8List.fromList(utf8.encode('{"error":"denied"}')),
    );
    expect(find.text('No pudimos abrir tu ficha médica.'), findsOneWidget);
    expect(find.text('PDF original de prueba'), findsNothing);
    expect(root.listSync(recursive: true), isEmpty);
  });

  testWidgets(
    'closing while the request is pending ignores its later response',
    (tester) async {
      final pending = Completer<Uint8List>();
      await show(tester, loadPdf: () => pending.future);
      expect(find.text('Abriendo tu ficha médica…'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar ficha médica'));
      await tester.pumpAndSettle();
      pending.complete(_pdf());
      await flush(tester);
      expect(find.text('PDF original de prueba'), findsNothing);
      expect(root.listSync(recursive: true), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preview created after disposal is immediately removed', (
    tester,
  ) async {
    final temporary = Completer<String?>();
    var askedForDirectory = false;
    paths.temporary = () {
      askedForDirectory = true;
      return temporary.future;
    };
    await show(tester, loadPdf: () async => _pdf());
    expect(askedForDirectory, isTrue);
    await tester.tap(find.byTooltip('Cerrar ficha médica'));
    await tester.pumpAndSettle();
    paths.temporary = null;
    temporary.complete(root.path);
    await flush(tester);
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'session change removes visible PDF and prevents retry or stale data',
    (tester) async {
      String? path;
      await show(
        tester,
        loadPdf: () async => _pdf(),
        onPdf: (value) => path = value,
      );
      expect(path, isNotNull);
      LabSession.changed.value++;
      await flush(tester);
      expect(find.text('PDF original de prueba'), findsNothing);
      expect(find.text('Estudiante Ejemplo'), findsNothing);
      expect(find.text('Sesión finalizada'), findsOneWidget);
      expect(find.byKey(const ValueKey('student-medical-retry')), findsNothing);
      expect(find.text('Compartir'), findsNothing);
      expect(find.text('Descargar'), findsNothing);
      expect(File(path!).existsSync(), isFalse);
    },
  );

  testWidgets('session change during fetch never stores late PDF', (
    tester,
  ) async {
    final pending = Completer<Uint8List>();
    await show(tester, loadPdf: () => pending.future);
    LabSession.changed.value++;
    pending.complete(_pdf());
    await flush(tester);
    expect(find.text('PDF original de prueba'), findsNothing);
    expect(root.listSync(recursive: true), isEmpty);
  });

  testWidgets(
    '320 width and triple text retain a usable viewer and close action',
    (tester) async {
      await show(tester, loadPdf: () async => _pdf(), width: 320, scale: 3);
      expect(tester.takeException(), isNull);
      expect(find.text('PDF original de prueba'), findsOneWidget);
      expect(find.text('Compartir').hitTestable(), findsOneWidget);
      expect(find.text('Descargar').hitTestable(), findsOneWidget);
      expect(
        find.byTooltip('Cerrar ficha médica').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Cerrar ficha médica'));
      await tester.pumpAndSettle();
      await flush(tester);
      expect(find.byType(PiloStudentMedicalSheet), findsNothing);
    },
  );

  testWidgets('header supports dismissing sheet with downward drag', (
    tester,
  ) async {
    await show(tester, loadPdf: () async => _pdf());
    await tester.drag(find.text('Ficha médica'), const Offset(0, 800));
    await tester.pumpAndSettle();
    await flush(tester);
    expect(find.byType(PiloStudentMedicalSheet), findsNothing);
  });

  testWidgets(
    'download passes the original PDF and reports only a saved result',
    (tester) async {
      var calls = 0;
      picker.save = (bytes, name) async {
        expect(bytes, _pdf());
        expect(name, 'Ficha medica - Estudiante Ejemplo - 99.000.011-5.pdf');
        calls++;
        return calls == 1 ? null : '${root.path}/saved.pdf';
      };
      await show(tester, loadPdf: () async => _pdf());
      await tester.tap(find.text('Descargar'));
      await flush(tester);
      expect(calls, 1);
      expect(find.text('Ficha médica guardada.'), findsNothing);
      await tester.tap(find.text('Descargar'));
      await flush(tester);
      expect(calls, 2);
      expect(find.text('Ficha médica guardada.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
    },
  );

  testWidgets(
    'sharing uses the original PDF and keeps it alive until the native sheet closes',
    (tester) async {
      final result = Completer<String>.sync();
      var calls = 0;
      String? sharedPath;
      MethodCall? sharedCall;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        (call) async {
          calls++;
          sharedCall = call;
          sharedPath = ((call.arguments as Map)['paths'] as List).single as String;
          return result.future;
        },
      );
      await show(tester, loadPdf: () async => _pdf());
      await tester.tap(find.text('Compartir'));
      // Wait for actual file I/O, without depending on a fixed event-loop count.
      for (var attempt = 0; attempt < 30 && calls == 0; attempt++) {
        await flush(tester);
      }
      expect(calls, 1);
      expect(sharedCall!.method, 'shareFiles');
      final args = sharedCall!.arguments as Map;
      expect(args['mimeTypes'], ['application/pdf']);
      expect(File(sharedPath!).readAsBytesSync(), _pdf());
      expect(
        File(sharedPath!).uri.pathSegments.last,
        'Ficha medica - Estudiante Ejemplo - 99.000.011-5.pdf',
      );
      expect(args['text'], 'Ficha médica');
      for (final key in ['student-medical-share', 'student-medical-download']) {
        expect(
          tester.widget<FilledButton>(find.byKey(ValueKey(key))).onPressed,
          isNull,
        );
      }
      await tester.tap(find.byTooltip('Cerrar ficha médica'));
      await tester.pumpAndSettle();
      await flush(tester);
      expect(File(sharedPath!).existsSync(), isTrue);
      result.complete(''); // Cancelled, never a success message.
      await flush(tester);
      expect(File(sharedPath!).existsSync(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native failures remain generic and allow retry without losing the PDF',
    (tester) async {
      var attempts = 0;
      picker.save = (_, _) async {
        if (attempts++ == 0) throw PlatformException(code: 'private-detail');
        return null;
      };
      await show(tester, loadPdf: () async => _pdf());
      await tester.tap(find.text('Descargar'));
      await flush(tester);
      expect(
        find.text('No pudimos guardar la ficha. Inténtalo nuevamente.'),
        findsOneWidget,
      );
      expect(find.textContaining('private-detail'), findsNothing);
      expect(find.text('PDF original de prueba'), findsOneWidget);
      await tester.tap(find.text('Descargar'));
      await flush(tester);
      expect(attempts, 2);
      expect(
        find.text('No pudimos guardar la ficha. Inténtalo nuevamente.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
    },
  );

  test(
    'share revalidates the session after file I/O before opening native UI',
    () async {
      final file = File('${root.path}/synthetic.pdf')..writeAsBytesSync(_pdf());
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (_) async {
            calls++;
            return '';
          });
      await expectLater(
        LabMedia.sharePdf(file, isCurrent: () => false),
        throwsStateError,
      );
      expect(calls, 0);
    },
  );
}
