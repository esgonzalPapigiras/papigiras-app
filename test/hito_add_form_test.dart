import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/api_http.dart';
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

class _Provider extends CoordinatorProviders {
  final requests = <RequestHito>[];
  final photoBatches = <List<XFile>>[];
  final voices = <VoiceNoteDraft>[];
  bool failCreate = false, failPhotos = false, failVoice = false;
  bool uncertainCreate = false;
  Completer<void>? photosGate;
  ValueChanged<HitoPublishProgress>? photoProgress;
  @override
  Future<ConsolidatedTourSalesDTO> addHito(RequestHito request) async {
    requests.add(request);
    if (uncertainCreate) throw TimeoutException('synthetic response lost');
    if (failCreate) throw const LabApiException(400);
    return LabFixtures.hitos.first;
  }

  @override
  Future<void> addHitoFoto(
    int hito,
    String tourId,
    List<XFile> photos, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    photoBatches.add(List.of(photos));
    photoProgress = onProgress;
    onProgress?.call(
      const HitoPublishProgress('Cargando fotos…', fraction: .25),
    );
    if (failPhotos) throw StateError('technical');
    await photosGate?.future;
  }

  @override
  Future<VoiceNoteMetadata> addHitoVoice(
    int hitoId,
    int tourId,
    VoiceNoteDraft voice, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    voices.add(voice);
    if (failVoice) throw StateError('technical');
    return VoiceNoteMetadata(
      id: 'synthetic',
      durationMs: voice.duration.inMilliseconds,
      sizeBytes: voice.byteLength,
    );
  }
}

class _Picker extends ImagePicker {
  _Picker(this.file);
  final XFile file;
  bool fail = false;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    if (fail) throw StateError('technical');
    return [file, file];
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async => file;
}

void main() {
  late _Provider provider;
  late FakeRecorder recorder;
  late _Picker picker;
  late Directory directory;
  bool? result;
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
    directory = await Directory.systemTemp.createTemp(
      'papigiras-form-fixture-',
    );
    final file = File('${directory.path}/fixture.png');
    await file.writeAsBytes(TileProvider.transparentImage);
    picker = _Picker(XFile(file.path));
    recorder = FakeRecorder();
    provider = _Provider();
    result = null;
  });
  tearDown(() async {
    provider.dispose();
    LabMode.useFixturesForTests(false);
    LabFixtures.reset();
    await directory.delete(recursive: true);
  });
  Finder key(String name) => find.byKey(ValueKey(name));
  Future<void> show(
    WidgetTester tester, {
    double width = 393,
    double scale = 1,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = Size(width, 852);
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
                result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HitoAddCoordScreen(
                      login: TourSales.fromCoordinatorTour(
                        coordinator: LabFixtures.coordinator,
                        tour: LabFixtures.tour,
                      ),
                      provider: provider,
                      recorder: recorder,
                      picker: picker,
                      voicePreviewBuilder: (_) => const Text('Voz ficticia'),
                    ),
                  ),
                );
              },
              child: const Text('Abrir formulario'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
    expect(find.text('Cargando ubicación…'), findsNothing);
    expect(find.textContaining('No pudimos cargar la ubicación'), findsNothing);
    expect(
      tester.widget<FilledButton>(key('hito-add-publish')).onPressed,
      isNotNull,
    );
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(key('hito-add-title'), ' Llegada de prueba ');
    await tester.enterText(
      key('hito-add-description'),
      ' El grupo llegó al destino ficticio. ',
    );
  }

  Future<void> publish(WidgetTester tester, {bool settle = true}) async {
    await tester.tap(key('hito-add-publish'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> voice(WidgetTester tester) async {
    await tester.ensureVisible(key('voice-record'));
    await tester.tap(key('voice-record'));
    await tester.pumpAndSettle();
    await tester.tap(key('voice-stop'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'formulario limpio sin nota de cierre ni miniaturas vacías valida junto al campo',
    (tester) async {
      await show(tester);
      expect(find.textContaining('Nota al cierre'), findsNothing);
      expect(key('hito-add-photo-0'), findsNothing);
      expect(recorder.permissions, 0);
      await publish(tester);
      expect(provider.requests, isEmpty);
      expect(find.text('Escribe un título.'), findsOneWidget);
      expect(find.text('Escribe una descripción.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'galería y cámara muestran sólo fotos elegidas y permiten eliminarlas',
    (tester) async {
      await show(tester);
      await tester.tap(key('hito-add-gallery'));
      await tester.pumpAndSettle();
      expect(key('hito-add-photo-0'), findsOneWidget);
      expect(key('hito-add-photo-1'), findsOneWidget);
      expect(key('hito-add-photo-2'), findsNothing);
      expect(find.byType(Image), findsNWidgets(2));
      await tester.tap(key('hito-remove-photo-0'));
      await tester.pumpAndSettle();
      expect(key('hito-add-photo-1'), findsNothing);
      await tester.tap(key('hito-add-camera'));
      await tester.pumpAndSettle();
      expect(key('hito-add-photo-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'publicación muestra progreso real y100porciento no anticipa confirmación',
    (tester) async {
      provider.photosGate = Completer<void>();
      await show(tester);
      await fill(tester);
      await tester.tap(key('hito-add-gallery'));
      await tester.pumpAndSettle();
      await publish(tester, settle: false);
      await tester.pump();
      expect(provider.requests, hasLength(1));
      expect(provider.requests.single.notaCierre, '');
      expect(provider.requests.single.titulo, 'Llegada de prueba');
      expect(find.text('25 %'), findsOneWidget);
      expect(result, isNull);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Publicando hito'), findsOneWidget);
      provider.photoProgress!(
        const HitoPublishProgress('Confirmando carga de fotos…', fraction: 1),
      );
      await tester.pump();
      expect(find.text('100 %'), findsOneWidget);
      expect(find.text('Confirmando carga de fotos…'), findsOneWidget);
      expect(result, isNull);
      provider.photosGate!.complete();
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(provider.requests, hasLength(1));
      expect(find.text('Abrir formulario'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fallo antes de crear conserva texto y permite reintentar sin alerta técnica',
    (tester) async {
      provider.failCreate = true;
      await show(tester);
      await fill(tester);
      await publish(tester);
      expect(find.textContaining('No pudimos publicar'), findsOneWidget);
      expect(find.textContaining('technical'), findsNothing);
      expect(
        tester.widget<TextFormField>(key('hito-add-title')).controller!.text,
        ' Llegada de prueba ',
      );
      provider.failCreate = false;
      await publish(tester);
      expect(result, isTrue);
      expect(provider.requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'respuesta de creación perdida bloquea repetición y exige revisar bitácora',
    (tester) async {
      provider.uncertainCreate = true;
      await show(tester);
      await fill(tester);
      final savedCallback = tester
          .widget<FilledButton>(key('hito-add-publish'))
          .onPressed!;
      await publish(tester);
      expect(
        find.textContaining('No pudimos confirmar si se guardó el hito'),
        findsOneWidget,
      );
      expect(find.text('Ver bitácora'), findsOneWidget);
      expect(key('hito-add-publish'), findsNothing);
      expect(
        tester.widget<TextFormField>(key('hito-add-title')).enabled,
        isFalse,
      );
      savedCallback();
      savedCallback();
      await tester.pumpAndSettle();
      expect(provider.requests, hasLength(1));
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'audio fallido reintenta sólo audio con mismo hito y fotos ya guardadas',
    (tester) async {
      provider.failVoice = true;
      await show(tester);
      await fill(tester);
      await tester.tap(key('hito-add-gallery'));
      await tester.pumpAndSettle();
      await voice(tester);
      await publish(tester);
      expect(provider.requests, hasLength(1));
      expect(provider.photoBatches, hasLength(1));
      expect(provider.voices, hasLength(1));
      expect(
        tester.widget<TextFormField>(key('hito-add-title')).enabled,
        isFalse,
      );
      expect(find.text('Reintentar envío'), findsOneWidget);
      provider.failVoice = false;
      await publish(tester);
      expect(provider.requests, hasLength(1));
      expect(provider.photoBatches, hasLength(1));
      expect(provider.voices, hasLength(2));
      expect(result, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fotos con resultado incierto no se reenvían y ofrecen revisar bitácora',
    (tester) async {
      provider.failPhotos = true;
      await show(tester);
      await fill(tester);
      await tester.tap(key('hito-add-gallery'));
      await tester.pumpAndSettle();
      await publish(tester);
      expect(
        find.textContaining('no pudimos confirmar las fotos'),
        findsOneWidget,
      );
      expect(find.text('Ver bitácora'), findsOneWidget);
      expect(key('hito-add-publish'), findsNothing);
      expect(provider.requests, hasLength(1));
      expect(provider.photoBatches, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('grabación activa bloquea publicación y selección de fotos', (
    tester,
  ) async {
    await show(tester);
    await fill(tester);
    await tester.ensureVisible(key('voice-record'));
    await tester.tap(key('voice-record'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(key('hito-add-publish')).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(key('hito-add-camera')).onPressed,
      isNull,
    );
    await tester.tap(key('voice-stop'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(key('hito-add-publish')).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    '320px textoampliado teclado y error de galería conservan formulario utilizable',
    (tester) async {
      picker.fail = true;
      await show(tester, width: 320, scale: 1.6, keyboard: 220);
      await fill(tester);
      await tester.ensureVisible(key('hito-add-gallery'));
      await tester.tap(key('hito-add-gallery'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No pudimos abrir la galería'),
        findsOneWidget,
      );
      expect(find.textContaining('technical'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
