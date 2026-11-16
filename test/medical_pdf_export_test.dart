import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/medical_pdf_name.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getTemporaryPath() async => root.path;
}

class _Picker extends FilePicker {
  String? name;
  String? title;
  Uint8List? content;
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
    title = dialogTitle;
    name = fileName;
    content = bytes;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const expectedName = 'Ficha medica - Estudiante Ejemplo - 99.000.011-5.pdf';
  const pdf = '%PDF-1.4 synthetic fixture';
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  late Directory temporary;
  late PathProviderPlatform originalPaths;
  late _Picker picker;
  setUp(() {
    LabMode.useFixturesForTests(false);
    SharedPreferences.setMockInitialValues({
      'token': 'Bearer fixture-only',
      'tokenExpiry': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'userRole': 'attorney',
    });
    temporary = Directory.systemTemp.createTempSync('medical-export-fixture-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temporary);
    picker = _Picker();
    FilePicker.platform = picker;
  });
  tearDown(() {
    PathProviderPlatform.instance = originalPaths;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    temporary.deleteSync(recursive: true);
  });
  CoordinatorProviders provider() => CoordinatorProviders(
    client: LabApiClient(
      transport: MockClient((request) async {
        expect(request.url.path, '/app/services/get/pdf/view/medical-records');
        expect(request.url.queryParameters['idPassenger'], '910011');
        return http.Response(
          pdf,
          200,
          headers: {
            'content-disposition':
                "attachment; filename=unused.pdf; filename*=UTF-8''${Uri.encodeComponent(expectedName)}",
          },
        );
      }),
    ),
  );

  test('name contains passenger identity and neutral medical title', () {
    expect(
      MedicalPdfName.forPassenger('Estudiante Ejemplo', '99.000.011-5'),
      expectedName,
    );
    expect(
      MedicalPdfName.forPassenger('Sofía Muñoz', '99.000.011-5'),
      'Ficha medica - Sofia Munoz - 99.000.011-5.pdf',
    );
  });
  test(
    'long name preserves the RUT and cannot create directories or control characters',
    () {
      final name = MedicalPdfName.forPassenger(
        '${'A' * 200}/../Test\n',
        '99.000.011-5',
      );
      expect(name.endsWith(' - 99.000.011-5.pdf'), isTrue);
      expect(name.contains('/'), isFalse);
      expect(name.contains('\n'), isFalse);
      expect(name.length, lessThanOrEqualTo(100));
    },
  );
  test('server UTF8 filename takes precedence over plain fallback', () {
    expect(
      MedicalPdfName.fromContentDisposition(
        "attachment; filename=old.pdf; filename*=UTF-8''${Uri.encodeComponent(expectedName)}",
        'ignored',
      ),
      expectedName,
    );
  });
  test('bad encoding falls back without accepting path traversal', () {
    expect(
      MedicalPdfName.fromContentDisposition(
        "attachment; filename=../../safe.pdf; filename*=UTF-8''%XY",
        'ignored',
      ),
      'safe.pdf',
    );
  });
  test(
    'legacy server without filename remains usable with neutral RUT name',
    () {
      expect(
        MedicalPdfName.fromContentDisposition(null, '99.000.011-5'),
        'Ficha medica - 99.000.011-5.pdf',
      );
    },
  );
  test(
    'download uses server identity filename with untouched PDF bytes',
    () async {
      final api = provider();
      addTearDown(api.dispose);
      await api.downloadDocumentMedicalRecord(
        '910001',
        '910011',
        '99.000.011-5',
      );
      expect(picker.name, expectedName);
      expect(picker.title, 'Guardar ficha médica');
      expect(picker.content, utf8.encode(pdf));
    },
  );
  test(
    'share uses named PDF and neutral text then removes its private copy',
    () async {
      String? shared;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = call.arguments as Map;
            expect(args['text'], 'Ficha médica');
            shared = (args['paths'] as List).single as String;
            expect(File(shared!).uri.pathSegments.last, expectedName);
            expect(File(shared!).readAsStringSync(), pdf);
            return '';
          });
      final api = provider();
      addTearDown(api.dispose);
      await api.shareDocumentMedicalRecord('910001', '910011', '99.000.011-5');
      expect(shared, isNotNull);
      expect(File(shared!).existsSync(), isFalse);
      expect(temporary.listSync(recursive: true).whereType<File>(), isEmpty);
    },
  );
  test('failed share also cleans both medical temporary files', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'fixture'),
        );
    final api = provider();
    addTearDown(api.dispose);
    await expectLater(
      api.shareDocumentMedicalRecord('910001', '910011', '99.000.011-5'),
      throwsA(isA<PlatformException>()),
    );
    expect(temporary.listSync(recursive: true).whereType<File>(), isEmpty);
  });
}
