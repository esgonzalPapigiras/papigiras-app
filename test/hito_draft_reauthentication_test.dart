import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/synthetic_location.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/voice/hito_publish_progress.dart';
import 'package:papigiras_app/voice/voice_note_draft.dart';
import 'package:papigiras_app/voice/voice_note_metadata.dart';
import 'voice_recorder_widget_test.dart' show FakeRecorder;

class _DraftProvider extends CoordinatorProviders {
  bool active = false;
  String? loginFailure;
  int renewals = 0, creates = 0, photoUploads = 0, voiceUploads = 0;
  int? createStatus;
  String? failStage;
  final savedIds = <int>[];
  final sentTitles = <String>[];
  final sentPhotos = <List<XFile>>[];
  final sentVoices = <VoiceNoteDraft>[];
  Completer<void>? renewalGate;
  @override
  Future<bool> hasHitoSession(int coordinatorId) async => active;
  @override
  Future<void> reauthenticateHitoDraft({
    required String rut,
    required String password,
    required TourSales expectedTour,
  }) async {
    renewals++;
    if (loginFailure == 'password') throw Exception('synthetic');
    if (loginFailure == 'account')
      throw const CoordinatorReauthenticationException(
        'Ingresa con la misma cuenta de coordinación que abrió este hito.',
      );
    await renewalGate?.future;
    active = true;
  }

  @override
  Future<ConsolidatedTourSalesDTO> addHito(RequestHito request) async {
    creates++;
    sentTitles.add(request.titulo);
    if (createStatus != null) {
      if (createStatus == 401) active = false;
      throw LabApiException(createStatus!);
    }
    return LabFixtures.hitos.first;
  }

  @override
  Future<void> addHitoFoto(
    int id,
    String tour,
    List<XFile> photos, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    photoUploads++;
    savedIds.add(id);
    sentPhotos.add(List.of(photos));
    onProgress?.call(const HitoPublishProgress('Cargando fotos…', fraction: 1));
    if (failStage == 'photos') {
      active = false;
      throw const LabApiException(401);
    }
  }

  @override
  Future<VoiceNoteMetadata> addHitoVoice(
    int id,
    int tour,
    VoiceNoteDraft voice, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    voiceUploads++;
    savedIds.add(id);
    sentVoices.add(voice);
    if (failStage == 'voice') {
      active = false;
      throw const LabApiException(401);
    }
    return const VoiceNoteMetadata(
      id: 'synthetic',
      durationMs: 6000,
      sizeBytes: 192044,
    );
  }
}

class _Picker extends ImagePicker {
  _Picker(this.file);
  final XFile file;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async => [file, file];
}

void main() {
  late _DraftProvider provider;
  late FakeRecorder recorder;
  late Directory cache;
  late XFile photo;
  bool? result;
  Finder key(String name) => find.byKey(ValueKey(name));
  setUp(() async {
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    LabSyntheticLocation.instance.resetForTests();
    await LabSyntheticLocation.instance.restore();
    cache = await Directory.systemTemp.createTemp('papigiras-reauth-test-');
    final image = File('${cache.path}/synthetic.png');
    await image.writeAsBytes(TileProvider.transparentImage);
    photo = XFile(image.path);
    recorder = FakeRecorder();
    provider = _DraftProvider();
    result = null;
  });
  tearDown(() async {
    provider.dispose();
    LabMode.useFixturesForTests(false);
    LabFixtures.reset();
    await cache.delete(recursive: true);
  });
  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => HitoAddCoordScreen(
                      login: TourSales.fromCoordinatorTour(
                        coordinator: LabFixtures.coordinator,
                        tour: LabFixtures.tour,
                      ),
                      provider: provider,
                      recorder: recorder,
                      picker: _Picker(photo),
                      voicePreviewBuilder: (_) => const Text(
                        'Nota sintética conservada',
                        key: ValueKey('retained-voice'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      key('hito-add-title'),
      'Título que no debe perderse',
    );
    await tester.enterText(
      key('hito-add-description'),
      'Descripción sintética conservada.',
    );
    await tester.ensureVisible(key('hito-add-gallery'));
    await tester.tap(key('hito-add-gallery'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(key('voice-record'));
    await tester.tap(key('voice-record'));
    await tester.pumpAndSettle();
    await tester.tap(key('voice-stop'));
    await tester.pumpAndSettle();
  }

  void retained(WidgetTester tester) {
    expect(
      tester.widget<TextFormField>(key('hito-add-title')).controller!.text,
      'Título que no debe perderse',
    );
    expect(
      tester
          .widget<TextFormField>(key('hito-add-description'))
          .controller!
          .text,
      'Descripción sintética conservada.',
    );
    expect(key('hito-add-photo-0'), findsOneWidget);
    expect(key('hito-add-photo-1'), findsOneWidget);
    expect(key('retained-voice'), findsOneWidget);
    expect(recorder.discards, 0);
  }

  Future<void> publish(WidgetTester tester) async {
    await tester.tap(key('hito-add-publish'));
    await tester.pumpAndSettle();
  }

  Future<void> credentials(WidgetTester tester) async {
    await tester.enterText(key('hito-reauth-rut'), '11111111-1');
    await tester.enterText(key('hito-reauth-password'), 'synthetic-password');
    await tester.tap(key('hito-reauth-submit'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cancel, wrong password/account and valid renewal keep every draft field without publishing',
    (tester) async {
      await show(tester);
      await publish(tester);
      expect(provider.creates, 0);
      expect(key('hito-reauth-dialog'), findsOneWidget);
      await tester.tap(key('hito-reauth-cancel'));
      await tester.pumpAndSettle();
      retained(tester);
      await publish(tester);
      provider.loginFailure = 'password';
      await credentials(tester);
      expect(find.textContaining('No pudimos renovar'), findsOneWidget);
      expect(provider.creates, 0);
      provider.loginFailure = 'account';
      await tester.tap(key('hito-reauth-submit'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Ingresa con la misma cuenta de coordinación que abrió este hito.',
        ),
        findsOneWidget,
      );
      expect(provider.creates, 0);
      provider.loginFailure = null;
      await tester.tap(key('hito-reauth-submit'));
      await tester.pumpAndSettle();
      expect(key('hito-reauth-dialog'), findsNothing);
      retained(tester);
      expect(provider.creates, 0);
      expect(result, isNull);
      await publish(tester);
      expect(provider.creates, 1);
      expect(result, isTrue);
      expect(provider.sentPhotos.single.map((p) => p.path), [
        photo.path,
        photo.path,
      ]);
      expect(provider.sentVoices.single, same(recorder.draft));
    },
  );

  testWidgets(
    '401 on creation opens inline login and explicit retry uses newly edited text',
    (tester) async {
      provider.active = true;
      provider.createStatus = 401;
      await show(tester);
      await publish(tester);
      expect(key('hito-reauth-dialog'), findsOneWidget);
      expect(provider.creates, 1);
      provider.createStatus = null;
      await credentials(tester);
      retained(tester);
      expect(provider.creates, 1);
      await tester.ensureVisible(key('hito-add-title'));
      await tester.enterText(key('hito-add-title'), 'Título actualizado');
      await publish(tester);
      expect(provider.creates, 2);
      expect(provider.sentTitles.last, 'Título actualizado');
      expect(result, isTrue);
    },
  );

  for (final stage in ['photos', 'voice']) {
    testWidgets(
      '401 during $stage keeps created ID and confirmed attachments across reauthentication',
      (tester) async {
        provider.active = true;
        provider.failStage = stage;
        await show(tester);
        await publish(tester);
        expect(provider.creates, 1);
        expect(key('hito-reauth-dialog'), findsOneWidget);
        provider.failStage = null;
        await credentials(tester);
        retained(tester);
        expect(provider.creates, 1);
        expect(
          tester.widget<TextFormField>(key('hito-add-title')).enabled,
          isFalse,
        );
        await publish(tester);
        expect(provider.creates, 1);
        expect(result, isTrue);
        expect(provider.savedIds.toSet(), {
          LabFixtures.hitos.first.binnacleDetailId,
        });
        expect(provider.photoUploads, stage == 'photos' ? 2 : 1);
        expect(provider.voiceUploads, stage == 'voice' ? 2 : 1);
      },
    );
  }

  testWidgets(
    '403 with current session is a permission error with no login loop or automatic replay',
    (tester) async {
      provider.active = true;
      provider.createStatus = 403;
      await show(tester);
      await publish(tester);
      retained(tester);
      expect(find.textContaining('Tu cuenta no tiene permiso'), findsOneWidget);
      expect(key('hito-reauth-dialog'), findsNothing);
      expect(provider.renewals, 0);
      expect(provider.creates, 1);
      expect(result, isNull);
    },
  );
}
