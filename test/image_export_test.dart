import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getTemporaryPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const share = MethodChannel('dev.fluttercommunity.plus/share');
  const gal = MethodChannel('gal');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late PathProviderPlatform previousPaths;
  late Uint8List jpeg, png;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('papigiras-image-fixture-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    // Existing bundled placeholder/logo assets; no downloaded passenger data.
    jpeg = await File('assets/profile.jpg').readAsBytes();
    png = await File('assets/logo-papigiras.png').readAsBytes();
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(share, null);
    messenger.setMockMethodCallHandler(gal, null);
    PathProviderPlatform.instance = previousPaths;
    await root.delete(recursive: true);
  });

  test(
    'gallery receives exact JPEG and PNG originals, without conversion',
    () async {
      final saved = <Map>[];
      messenger.setMockMethodCallHandler(gal, (call) async {
        if (call.method == 'requestAccess') return true;
        expect(call.method, 'putImageBytes');
        saved.add(call.arguments as Map);
        return null;
      });
      await LabMedia.saveImage(jpeg);
      await LabMedia.saveImage(png);
      expect(saved[0]['bytes'], orderedEquals(jpeg));
      expect(saved[1]['bytes'], orderedEquals(png));
      expect(
        saved.every(
          (args) => (args['name'] as String).startsWith('PapiGiras_'),
        ),
        isTrue,
      );
      expect(
        saved.every((args) => !(args['name'] as String).contains('LAB')),
        isTrue,
      );
    },
  );

  testWidgets(
    'sharing retains original bytes, type and extension then cleans its copies',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        var index = 0;
        final paths = <String>[];
        messenger.setMockMethodCallHandler(share, (call) async {
          final args = call.arguments as Map;
          final path = (args['paths'] as List).single as String;
          paths.add(path);
          expect(args['text'], 'Imagen de PapiGiras');
          expect(args['mimeTypes'], [index == 0 ? 'image/jpeg' : 'image/png']);
          expect(path.endsWith(index == 0 ? '.jpg' : '.png'), isTrue);
          expect(
            await File(path).readAsBytes(),
            orderedEquals(index++ == 0 ? jpeg : png),
          );
          return '';
        });
        await LabMedia.shareImage(jpeg, context);
        await LabMedia.shareImage(png, context);
        expect(paths, hasLength(2));
        expect(paths[0], isNot(paths[1]));
        expect(await root.list().toList(), isEmpty);
      });
    },
  );

  testWidgets(
    'failed share removes only its own copy and preserves unrelated files',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        final unrelated = await File(
          '${root.path}/unrelated.txt',
        ).writeAsString('keep');
        messenger.setMockMethodCallHandler(
          share,
          (_) async => throw PlatformException(code: 'unavailable'),
        );
        await expectLater(
          LabMedia.shareImage(jpeg, context),
          throwsA(isA<PlatformException>()),
        );
        expect(await unrelated.readAsString(), 'keep');
        final remaining = await root.list().toList();
        expect(remaining, hasLength(1));
        expect(
          await FileSystemEntity.identical(
            remaining.single.path,
            unrelated.path,
          ),
          isTrue,
        );
      });
    },
  );

  test('invalid server content never reaches the gallery', () async {
    messenger.setMockMethodCallHandler(
      gal,
      (_) async => fail('Invalid image reached gallery'),
    );
    await expectLater(
      LabMedia.saveImage(Uint8List.fromList('<html>error'.codeUnits)),
      throwsException,
    );
  });

  test(
    'logout while an image is decoded prevents its gallery export',
    () async {
      messenger.setMockMethodCallHandler(
        gal,
        (_) async => fail('Revoked image reached gallery'),
      );
      final pending = expectLater(LabMedia.saveImage(jpeg), throwsStateError);
      await LabSession.clear(await SharedPreferences.getInstance());
      await pending;
      expect(await root.list().toList(), isEmpty);
    },
  );

  testWidgets('a hidden viewer cannot share or save the downloaded image', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    messenger.setMockMethodCallHandler(
      share,
      (_) async => fail('Hidden viewer reached share'),
    );
    messenger.setMockMethodCallHandler(
      gal,
      (_) async => fail('Hidden viewer reached gallery'),
    );
    await tester.runAsync(() async {
      await expectLater(
        LabMedia.shareImage(jpeg, context, isCurrent: () => false),
        throwsStateError,
      );
      await expectLater(
        LabMedia.saveImage(jpeg, isCurrent: () => false),
        throwsStateError,
      );
      expect(await root.list().toList(), isEmpty);
    });
  });
}
