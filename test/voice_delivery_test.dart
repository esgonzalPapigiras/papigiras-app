import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/voice/trip_voice_player.dart';
import 'package:papigiras_app/voice/voice_note_draft.dart';
import 'package:papigiras_app/voice/voice_note_metadata.dart';

class FakePlayback implements VoicePlaybackPort {
  final positions = StreamController<Duration>.broadcast();
  final states = StreamController<bool>.broadcast();
  int starts = 0, pauses = 0, disposals = 0;
  bool failPause = false;
  @override
  Stream<Duration> get position => positions.stream;
  @override
  Stream<bool> get playing => states.stream;
  @override
  Future<void> play(File file) async {
    starts++;
    states.add(true);
  }

  @override
  Future<void> pause() async {
    pauses++;
    if (failPause) throw StateError('synthetic pause failure');
    states.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    positions.add(position);
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await positions.close();
    await states.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'token': 'synthetic-audio-test',
      'tokenExpiry': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    }),
  );
  test(
    'metadata refuses invalid duration, oversized payload and foreign format',
    () {
      final valid = {
        'id': 'synthetic',
        'durationMs': 60000,
        'sizeBytes': 1920044,
        'contentType': 'audio/wav',
      };
      expect(VoiceNoteMetadata.parse(valid), isNotNull);
      expect(VoiceNoteMetadata.parse({...valid, 'durationMs': 60001}), isNull);
      expect(VoiceNoteMetadata.parse({...valid, 'durationMs': 0}), isNull);
      expect(VoiceNoteMetadata.parse({...valid, 'sizeBytes': 2097153}), isNull);
      expect(
        VoiceNoteMetadata.parse({...valid, 'contentType': 'video/mp4'}),
        isNull,
      );
    },
  );
  test(
    'multipart reports exact bytes while awaiting server confirmation',
    () async {
      final responseGate = Completer<http.Response>();
      final sent = Completer<void>();
      var calls = 0;
      String? multipartBody;
      final fractions = <double>[];
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((request) async {
            calls++;
            expect(
              request.url,
              LabApi.uri('/app/services/hitos/910003/audio', {
                'tourId': '910001',
              }),
            );
            expect(request.headers['Authorization'], 'synthetic-audio-test');
            expect(request.bodyBytes.length, greaterThan(44));
            multipartBody = latin1.decode(request.bodyBytes);
            expect(request.followRedirects, false);
            sent.complete();
            return responseGate.future;
          }),
        ),
      );
      addTearDown(provider.dispose);
      var complete = false;
      final upload = provider
          .addHitoVoice(
            910003,
            910001,
            VoiceNoteDraft(
              file: XFile.fromData(Uint8List(100)),
              duration: const Duration(seconds: 1),
              byteLength: 100,
            ),
            onProgress: (value) {
              if (value.fraction != null) fractions.add(value.fraction!);
            },
          )
          .then((_) => complete = true);
      await sent.future;
      expect(fractions.first, 0);
      expect(fractions.last, 1);
      expect(complete, false);
      responseGate.complete(
        http.Response(
          jsonEncode({
            'id': 'synthetic',
            'durationMs': 1000,
            'sizeBytes': 100,
            'contentType': 'audio/wav',
          }),
          201,
        ),
      );
      await upload;
      expect(complete, true);
      expect(calls, 1);
      expect(multipartBody!.toLowerCase(), contains('content-type: audio/wav'));
      expect(multipartBody, contains('name="audio"'));
      expect(multipartBody, isNot(contains('application/octet-stream')));
    },
  );
  test(
    'download writes verified WAV into a fresh private cache directory',
    () async {
      LabMode.useFixturesForTests(false);
      final cache = await Directory.systemTemp.createTemp(
        'papigiras-download-test-',
      );
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async {
            if (call.method == 'getTemporaryDirectory') return cache.path;
            throw StateError('Unexpected filesystem operation');
          });
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathChannel, null);
        await cache.delete(recursive: true);
      });
      final buffer = VoicePcmBuffer()..add(Uint8List(32000));
      final wav = buffer.finish();
      var downloads = 0;
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((request) async {
            downloads++;
            expect(request.method, 'GET');
            expect(
              request.url,
              LabApi.uri('/app/services/hitos/910003/audio', {
                'tourId': '910001',
              }),
            );
            expect(request.headers['Authorization'], 'synthetic-audio-test');
            expect(request.followRedirects, false);
            return http.Response.bytes(
              wav.bytes,
              200,
              headers: {'content-type': 'audio/wav'},
            );
          }),
        ),
      );
      addTearDown(provider.dispose);
      expect(await cache.list().isEmpty, isTrue);
      final file = await provider.readHitoVoice(
        910003,
        910001,
        VoiceNoteMetadata(
          id: 'synthetic',
          durationMs: wav.duration.inMilliseconds,
          sizeBytes: wav.bytes.length,
        ),
      );
      expect(downloads, 1);
      expect(await file.exists(), isTrue);
      expect(file.parent.parent.path, cache.path);
      expect(
        file.parent.path.split(Platform.pathSeparator).last,
        startsWith('papigiras-voice-'),
      );
      expect(await file.readAsBytes(), orderedEquals(wav.bytes));
      expect(await file.length(), 32044);
    },
  );
  testWidgets(
    'audio loads only after Play and only one player can remain active',
    (tester) async {
      var downloads = 0;
      final first = FakePlayback(), second = FakePlayback();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final port in [first, second])
                  TripVoicePlayer(
                    duration: const Duration(seconds: 20),
                    loadFile: () async {
                      downloads++;
                      return File('/private/tmp/synthetic-voice-test.wav');
                    },
                    deleteAfterUse: false,
                    playerFactory: () => port,
                  ),
              ],
            ),
          ),
        ),
      );
      expect(downloads, 0);
      await tester.tap(find.byKey(const ValueKey('voice-play')).first);
      await tester.pumpAndSettle();
      expect(downloads, 1);
      expect(first.starts, 1);
      await tester.tap(find.byKey(const ValueKey('voice-play')).last);
      await tester.pumpAndSettle();
      expect(downloads, 2);
      expect(first.pauses, greaterThan(0));
      expect(second.starts, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(second.pauses, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('leaving while download is pending never starts playback', (
    tester,
  ) async {
    final gate = Completer<File>();
    final port = FakePlayback();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripVoicePlayer(
            duration: const Duration(seconds: 3),
            loadFile: () => gate.future,
            deleteAfterUse: false,
            playerFactory: () => port,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('voice-play')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    gate.complete(File('/private/tmp/synthetic-voice-test.wav'));
    await tester.pump();
    expect(port.starts, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'a failed pause releases native playback and permits a clean retry',
    (tester) async {
      final failed = FakePlayback()..failPause = true;
      final retry = FakePlayback();
      var creates = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripVoicePlayer(
              duration: const Duration(seconds: 3),
              loadFile: () async =>
                  File('/private/tmp/synthetic-voice-test.wav'),
              deleteAfterUse: false,
              playerFactory: () => creates++ == 0 ? failed : retry,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('voice-play')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('voice-play')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(
        failed.disposals,
        1,
        reason:
            'starts=${failed.starts}; pauses=${failed.pauses}; creates=$creates; error=${find.text("No pudimos reproducirla. Reintenta.").evaluate().length}',
      );
      expect(find.text('No pudimos reproducirla. Reintenta.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('voice-play')));
      await tester.pumpAndSettle();
      expect(retry.starts, 1);
      expect(find.byTooltip('Pausar nota de voz'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(retry.disposals, 1);
    },
  );

  testWidgets('backgrounding releases playback when native pause fails', (
    tester,
  ) async {
    final port = FakePlayback()..failPause = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripVoicePlayer(
            duration: const Duration(seconds: 3),
            loadFile: () async => File('/private/tmp/synthetic-voice-test.wav'),
            deleteAfterUse: false,
            playerFactory: () => port,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('voice-play')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(port.disposals, 1);
    expect(tester.takeException(), isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(port.disposals, 1);
  });
}
