import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/synthetic_location.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/voice/hito_publish_progress.dart';
import 'package:papigiras_app/voice/voice_note_draft.dart';
import 'package:papigiras_app/voice/voice_note_metadata.dart';

import 'voice_recorder_widget_test.dart' show FakeRecorder;

class _SheetProvider extends CoordinatorProviders {
  final requests = <RequestHito>[];
  final photos = <List<XFile>>[];
  final voices = <VoiceNoteDraft>[];
  Completer<void>? uploadGate;

  @override
  Future<ConsolidatedTourSalesDTO> addHito(RequestHito request) async {
    requests.add(request);
    return LabFixtures.hitos.first;
  }

  @override
  Future<void> addHitoFoto(
    int hito,
    String tourId,
    List<XFile> files, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    photos.add(List.of(files));
    await uploadGate?.future;
  }

  @override
  Future<VoiceNoteMetadata> addHitoVoice(
    int hitoId,
    int tourId,
    VoiceNoteDraft voice, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    voices.add(voice);
    return const VoiceNoteMetadata(
      id: 'sheet-synthetic-voice',
      durationMs: 3000,
      sizeBytes: 96044,
    );
  }
}

class _SheetPicker extends ImagePicker {
  _SheetPicker(this.file);
  final XFile file;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async => [file];
}

void main() {
  late _SheetProvider provider;
  late _SheetPicker picker;
  late FakeRecorder recorder;
  late Directory directory;
  bool? result;
  var closed = false;

  setUp(() async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    addTearDown(() => HttpOverrides.global = previous);
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    LabSyntheticLocation.instance.resetForTests();
    await LabSyntheticLocation.instance.restore();
    directory = await Directory.systemTemp.createTemp('pilo-sheet-fixture-');
    final file = File('${directory.path}/fixture.png');
    await file.writeAsBytes(TileProvider.transparentImage);
    picker = _SheetPicker(XFile(file.path));
    provider = _SheetProvider();
    recorder = FakeRecorder();
    result = null;
    closed = false;
  });

  tearDown(() async {
    provider.dispose();
    LabMode.useFixturesForTests(false);
    LabFixtures.reset();
    await directory.delete(recursive: true);
  });

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> show(
    WidgetTester tester, {
    double width = 402,
    double scale = 1,
    double keyboard = 0,
    bool fullPage = false,
  }) async {
    tester.view.physicalSize = Size(width, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                if (fullPage) {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => HitoAddCoordScreen(
                        login: TourSales.fromCoordinatorTour(
                          coordinator: LabFixtures.coordinator,
                          tour: LabFixtures.tour,
                        ),
                        provider: provider,
                        recorder: recorder,
                        picker: picker,
                      ),
                    ),
                  );
                } else {
                  result = await showPiloNewHitoSheet(
                    context,
                    login: TourSales.fromCoordinatorTour(
                      coordinator: LabFixtures.coordinator,
                      tour: LabFixtures.tour,
                    ),
                    provider: provider,
                    recorder: recorder,
                    picker: picker,
                    voicePreviewBuilder: (_) => const Text('Audio de prueba'),
                  );
                }
                closed = true;
              },
              child: const Text('Abrir nuevo hito'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir nuevo hito'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('empty composer closes back to home without publishing', (
    tester,
  ) async {
    await show(tester);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byType(HitoAddCoordScreen), findsOneWidget);
    expect(key('hito-add-title'), findsOneWidget);
    expect(key('hito-add-description'), findsOneWidget);
    expect(key('hito-add-camera'), findsOneWidget);
    expect(key('hito-add-gallery'), findsOneWidget);
    await tap(tester, key('hito-sheet-close'));
    expect(closed, isTrue);
    expect(result, isNull);
    expect(provider.requests, isEmpty);
    expect(find.byType(HitoAddCoordScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'drag, barrier and cancelled dismissal preserve draft and photos',
    (tester) async {
      await show(tester);
      await tester.enterText(key('hito-add-title'), 'Llegada de prueba');
      await tap(tester, key('hito-add-gallery'));
      expect(key('hito-add-photo-0'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 30));
      await tester.pumpAndSettle();
      expect(find.byType(HitoAddCoordScreen), findsOneWidget);
      await tap(tester, key('hito-sheet-close'));
      expect(find.text('¿Descartar este hito?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(key('hito-add-title')).controller!.text,
        'Llegada de prueba',
      );
      expect(key('hito-add-photo-0'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar este hito?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(provider.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full-page back uses the same guard and keeps draft when cancelled',
    (tester) async {
      await show(tester, fullPage: true);
      await tester.enterText(key('hito-add-title'), 'Borrador de prueba');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('hito-discard-dialog'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(
        tester.widget<TextFormField>(key('hito-add-title')).controller!.text,
        'Borrador de prueba',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(provider.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sheet publishes its photos and voice once, returns true after upload',
    (tester) async {
      provider.uploadGate = Completer<void>();
      await show(tester);
      await tester.enterText(key('hito-add-title'), 'Llegada de prueba');
      await tester.enterText(key('hito-add-description'), 'Texto de prueba.');
      await tap(tester, key('hito-add-gallery'));
      await tap(tester, key('voice-record'));
      await tap(tester, key('voice-stop'));
      await tester.tap(key('hito-add-publish'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Publicando hito'), findsOneWidget);
      expect(provider.requests, hasLength(1));
      expect(provider.photos, hasLength(1));
      expect(closed, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Publicando hito'), findsOneWidget);
      provider.uploadGate!.complete();
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isTrue);
      expect(provider.requests, hasLength(1));
      expect(provider.voices, hasLength(1));
      expect(find.byType(HitoAddCoordScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard and enlarged text retain fields, media and publish control',
    (tester) async {
      await show(tester, width: 320, scale: 1.6, keyboard: 240);
      await tester.enterText(key('hito-add-title'), 'Título de prueba');
      await tester.enterText(
        key('hito-add-description'),
        'Descripción de prueba.',
      );
      await tester.ensureVisible(key('hito-add-camera'));
      await tester.pumpAndSettle();
      expect(key('hito-add-camera').hitTestable(), findsOneWidget);
      expect(key('hito-add-publish').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(key('hito-add-publish')).bottom,
        lessThanOrEqualTo(634),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
