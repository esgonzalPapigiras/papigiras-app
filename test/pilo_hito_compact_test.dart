import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
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

class _Provider extends CoordinatorProviders {
  final requests = <RequestHito>[];
  var photos = 0, voices = 0;
  Completer<void>? photoConfirmation;
  Completer<void>? voiceConfirmation;

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
    photos++;
    onProgress?.call(
      const HitoPublishProgress('Confirmando fotos de prueba', fraction: 1),
    );
    await photoConfirmation?.future;
  }

  @override
  Future<VoiceNoteMetadata> addHitoVoice(
    int hitoId,
    int tourId,
    VoiceNoteDraft voice, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    voices++;
    onProgress?.call(
      const HitoPublishProgress('Confirmando voz de prueba', fraction: 1),
    );
    await voiceConfirmation?.future;
    return const VoiceNoteMetadata(
      id: 'compact-fixture-voice',
      durationMs: 3000,
      sizeBytes: 96044,
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
  }) async => [file];
}

void main() {
  late _Provider provider;
  late _Picker picker;
  late FakeRecorder recorder;
  late Directory directory;
  late ValueNotifier<double> keyboard;
  late GlobalKey<NavigatorState> rootNavigator;
  late GlobalKey<NavigatorState> sectionNavigator;
  bool closed = false;
  bool? result;

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
            ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
          .load(),
    ]);
  });

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
    directory = await Directory.systemTemp.createTemp('pilo-compact-fixture-');
    final file = File('${directory.path}/photo.png');
    await file.writeAsBytes(TileProvider.transparentImage);
    picker = _Picker(XFile(file.path));
    provider = _Provider();
    recorder = FakeRecorder();
    keyboard = ValueNotifier(0);
    rootNavigator = GlobalKey<NavigatorState>();
    sectionNavigator = GlobalKey<NavigatorState>();
    closed = false;
    result = null;
  });

  tearDown(() async {
    provider.dispose();
    keyboard.dispose();
    LabMode.useFixturesForTests(false);
    LabFixtures.reset();
    await directory.delete(recursive: true);
  });

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> show(
    WidgetTester tester, {
    double width = 402,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigator,
        theme: PiloFamilyTheme.theme(ThemeData()),
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: keyboard,
          builder: (context, inset, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(top: 59, bottom: inset == 0 ? 34 : 0),
              viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
              viewInsets: EdgeInsets.only(bottom: inset),
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(
              key: const ValueKey('compact-composer-capture'),
              child: child!,
            ),
          ),
        ),
        home: Scaffold(
          bottomNavigationBar: SizedBox(
            height: 120,
            child: ColoredBox(
              color: PiloFamilyTheme.soft,
              child: TextButton(
                key: const ValueKey('fixture-dock'),
                onPressed: () {},
                child: const Text('Inicio · Bitácora · Galería · Documentos'),
              ),
            ),
          ),
          body: Navigator(
            key: sectionNavigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      result = await showPiloNewHitoSheet(
                        context,
                        login: TourSales.fromCoordinatorTour(
                          coordinator: LabFixtures.coordinator,
                          tour: LabFixtures.tour,
                        ),
                        provider: provider,
                        picker: picker,
                        recorder: recorder,
                        voicePreviewBuilder: (_) =>
                            const Text('Voz ficticia LAB'),
                      );
                      closed = true;
                    },
                    child: const Text('Abrir hito ficticio'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir hito ficticio'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'initial composer exposes camera gallery and voice above the dock',
    (tester) async {
      await show(tester);
      for (final action in [
        'hito-add-camera',
        'hito-add-gallery',
        'voice-record',
      ]) {
        // The initial view must offer every media option without scrolling first.
        expect(key(action).hitTestable(), findsOneWidget, reason: action);
      }
      expect(key('hito-add-publish').hitTestable(), findsOneWidget);
      expect(rootNavigator.currentState!.canPop(), isTrue);
      expect(sectionNavigator.currentState!.canPop(), isFalse);
      expect(key('fixture-dock').hitTestable(), findsNothing);
      expect(tester.getRect(find.byType(BottomSheet)).bottom, 874);
      expect(
        tester.getRect(key('hito-add-publish')).bottom,
        lessThanOrEqualTo(840),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'root sheet stays above keyboard and retains text at narrow width',
    (tester) async {
      await show(tester, width: 320, scale: 1.6);
      await tester.enterText(key('hito-add-title'), 'Salida ficticia');
      keyboard.value = 280;
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('hito-add-description'));
      await tester.pumpAndSettle();
      await tester.enterText(
        key('hito-add-description'),
        'El grupo de prueba inicia la actividad.',
      );
      expect(key('hito-add-publish').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(key('hito-add-publish')).bottom,
        lessThanOrEqualTo(594),
      );
      expect(rootNavigator.currentState!.canPop(), isTrue);
      expect(sectionNavigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
      keyboard.value = 0;
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(key('hito-add-title')).controller!.text,
        'Salida ficticia',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'title enforces 60 graphemes without splitting composed emoji and description stays 140',
    (tester) async {
      await show(tester);
      const family = '👨‍👩‍👧‍👦';
      const flag = '🇨🇱';
      const tonedEmoji = '👍🏽';
      final expected = '${'a' * 57}$family$flag$tonedEmoji';
      await tester.enterText(key('hito-add-title'), '${expected}extra');
      await tester.pump();
      final title = tester
          .widget<TextFormField>(key('hito-add-title'))
          .controller!
          .text;
      expect(title, expected);
      expect(title.characters.length, 60);
      expect(tester.widget<Text>(key('hito-title-counter')).data, '60 / 60');
      await tester.enterText(key('hito-add-description'), 'd' * 141);
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(key('hito-add-description'))
            .controller!
            .text,
        'd' * 140,
      );
      expect(
        tester.widget<Text>(key('hito-description-counter')).data,
        '140 / 140',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'complex title preserves 60 graphemes but rejects excess server code points',
    (tester) async {
      await show(tester);
      final tooComplex = '👨‍👩‍👧‍👦' * 60;
      await tester.enterText(key('hito-add-title'), tooComplex);
      await tester.enterText(key('hito-add-description'), 'Texto de prueba.');
      await tester.tap(key('hito-add-publish'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(key('hito-add-title')).controller!.text,
        tooComplex,
      );
      expect(
        find.text('Simplifica los emojis o símbolos del título.'),
        findsOneWidget,
      );
      expect(provider.requests, isEmpty);
      expect(closed, isFalse);

      final accepted = '👍🏽' * 60;
      await tester.enterText(key('hito-add-title'), accepted);
      await tester.tap(key('hito-add-publish'));
      await tester.pumpAndSettle();
      expect(provider.requests, hasLength(1));
      expect(provider.requests.single.titulo, accepted);
      expect(closed, isTrue);
      expect(result, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reassemble retains text photo and voice in the root sheet', (
    tester,
  ) async {
    await show(tester);
    await tester.enterText(key('hito-add-title'), 'Borrador ficticio');
    await tester.enterText(
      key('hito-add-description'),
      'Descripción conservada.',
    );
    await tap(tester, key('hito-add-gallery'));
    await tap(tester, key('voice-record'));
    await tap(tester, key('voice-stop'));
    final original = tester.state(find.byType(HitoAddCoordScreen));
    final reload = tester.binding.reassembleApplication();
    await tester.pumpAndSettle();
    await reload;
    expect(tester.state(find.byType(HitoAddCoordScreen)), same(original));
    expect(
      tester.widget<TextFormField>(key('hito-add-title')).controller!.text,
      'Borrador ficticio',
    );
    expect(
      tester
          .widget<TextFormField>(key('hito-add-description'))
          .controller!
          .text,
      'Descripción conservada.',
    );
    expect(key('hito-add-photo-0'), findsOneWidget);
    expect(find.text('Voz ficticia LAB'), findsOneWidget);
    expect(provider.requests, isEmpty);
    expect(closed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'success waits for photo and voice acknowledgement and double tap creates one hito',
    (tester) async {
      provider.photoConfirmation = Completer<void>();
      provider.voiceConfirmation = Completer<void>();
      await show(tester);
      await tester.enterText(key('hito-add-title'), 'Llegada de prueba');
      await tester.enterText(key('hito-add-description'), 'Texto de prueba.');
      await tap(tester, key('hito-add-gallery'));
      await tap(tester, key('voice-record'));
      await tap(tester, key('voice-stop'));
      await tester.tap(key('hito-add-publish'));
      await tester.tap(key('hito-add-publish'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(provider.requests, hasLength(1));
      expect(provider.photos, 1);
      expect(provider.voices, 0);
      expect(find.text('Confirmando fotos de prueba'), findsOneWidget);
      expect(find.text('100 %'), findsOneWidget);
      expect(key('hito-published-confirmation'), findsNothing);
      expect(closed, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(closed, isFalse);
      provider.photoConfirmation!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(provider.voices, 1);
      expect(find.text('Confirmando voz de prueba'), findsOneWidget);
      expect(key('hito-published-confirmation'), findsNothing);
      expect(closed, isFalse);
      provider.voiceConfirmation!.complete();
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isTrue);
      expect(find.byType(HitoAddCoordScreen), findsNothing);
      final confirmation = key('hito-published-confirmation');
      expect(confirmation, findsOneWidget);
      expect(
        find.descendant(
          of: confirmation,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CircleAvatar>(
              find.descendant(
                of: confirmation,
                matching: find.byType(CircleAvatar),
              ),
            )
            .backgroundColor,
        PiloFamilyTheme.mint,
      );
      expect(provider.requests, hasLength(1));
      expect(provider.photos, 1);
      expect(provider.voices, 1);
      expect(sectionNavigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
