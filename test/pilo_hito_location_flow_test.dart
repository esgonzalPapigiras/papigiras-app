import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/synthetic_location.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'package:papigiras_app/maps/trip_hito_edit_sheet.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/voice/hito_publish_progress.dart';
import 'package:papigiras_app/voice/voice_note_draft.dart';
import 'package:papigiras_app/voice/voice_note_metadata.dart';

import 'support/map_tiles.dart';
import 'voice_recorder_widget_test.dart' show FakeRecorder;

class _LocationProvider extends CoordinatorProviders {
  final requests = <RequestHito>[];
  final uploadedPhotos = <XFile>[];
  final uploadedVoices = <VoiceNoteDraft>[];

  @override
  Future<bool> hasHitoSession(int? expectedCoordinatorId) async => true;

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
  }) async => uploadedPhotos.addAll(files);

  @override
  Future<VoiceNoteMetadata> addHitoVoice(
    int hitoId,
    int tourId,
    VoiceNoteDraft voice, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    uploadedVoices.add(voice);
    return const VoiceNoteMetadata(
      id: 'location-flow-fixture',
      durationMs: 3000,
      sizeBytes: 96044,
    );
  }
}

class _PhotoPicker extends ImagePicker {
  _PhotoPicker(this.file);
  final XFile file;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async => [file];
}

typedef _EditSave =
    Future<void> Function(
      String title,
      String description,
      String closing,
      HitoLocationDraft? location,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _LocationProvider provider;
  late FakeRecorder recorder;
  late Directory files;
  late XFile photo;
  bool? returned;
  var completed = false;
  final initial = HitoLocationDraft(
    point: const LatLng(-33.45, -70.66),
    label: 'Sitio ficticio del hito',
  );
  final detail = DetailHitoList(
    titulo: 'Visita de prueba',
    descripcion: 'Descripción original de prueba.',
    notaCierre: 'Nota original.',
    ubicacion: initial.label,
  );

  Finder key(String name) => find.byKey(ValueKey(name));
  String value(WidgetTester tester, String name) =>
      tester.widget<TextFormField>(key(name)).controller!.text;
  MapController camera(WidgetTester tester) =>
      tester.widget<FlutterMap>(key('hito-location-map')).mapController!;

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
    final previousHttp = HttpOverrides.current;
    final previousTiles = LabMapTiles.testProvider;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMapTiles.testProvider = TestMapTileProvider.new;
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    LabSyntheticLocation.instance.resetForTests();
    await LabSyntheticLocation.instance.select(3);
    provider = _LocationProvider();
    recorder = FakeRecorder();
    returned = null;
    completed = false;
    files = await Directory.systemTemp.createTemp(
      'pilo-location-flow-fixture-',
    );
    final fixturePhoto = File('${files.path}/photo.png');
    await fixturePhoto.writeAsBytes(TileProvider.transparentImage);
    photo = XFile(fixturePhoto.path);
    addTearDown(() async {
      provider.dispose();
      HttpOverrides.global = previousHttp;
      LabMapTiles.testProvider = previousTiles;
      LabSyntheticLocation.instance.resetForTests();
      LabMode.useFixturesForTests(false);
      LabFixtures.reset();
      await files.delete(recursive: true);
    });
  });

  Future<void> open(
    WidgetTester tester, {
    HitoLocationDraft? createLocation,
    _EditSave? edit,
    bool locationNeedsConfirmation = false,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        theme: PiloFamilyTheme.theme(ThemeData()),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('location-flow-capture'),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  returned = edit == null
                      ? await showPiloNewHitoSheet(
                          context,
                          login: TourSales.fromCoordinatorTour(
                            coordinator: LabFixtures.coordinator,
                            tour: LabFixtures.tour,
                          ),
                          initialLocation: createLocation,
                          provider: provider,
                          picker: _PhotoPicker(photo),
                          recorder: recorder,
                          voicePreviewBuilder: (_) =>
                              const Text('Voz de prueba conservada'),
                        )
                      : await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => TripHitoEditSheet(
                            detail: detail,
                            initialLocation: initial,
                            locationNeedsConfirmation:
                                locationNeedsConfirmation,
                            onSave: (_, _, _) async =>
                                fail('Must use the location-aware callback'),
                            onSaveWithLocation: edit,
                          ),
                        );
                  completed = true;
                },
                child: const Text('Abrir formulario de prueba'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir formulario de prueba'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String name) async {
    await tester.ensureVisible(key(name));
    await tester.pumpAndSettle();
    await tester.tap(key(name));
    await tester.pumpAndSettle();
  }

  Future<LatLng> moveSelection(WidgetTester tester) async {
    final map = tester.getRect(key('hito-location-map'));
    await tester.tapAt(map.center + const Offset(-65, 45));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    return camera(tester).camera.center;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.environment['PILO_LOCATION_CAPTURE'] != '1') return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        key('location-flow-capture'),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory(
          'registro-local/PILO-HITO-UBICACION/evidencias',
        );
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  void expectSharedSourceUnchanged() {
    expect(LabSyntheticLocation.instance.index, 3);
    expect(
      LabSyntheticLocation.instance.current,
      same(LabSyntheticLocation.route[3]),
    );
  }

  Future<void> fillCreate(WidgetTester tester) async {
    await tester.enterText(key('hito-add-title'), 'Excursión ficticia');
    await tester.enterText(
      key('hito-add-description'),
      'El grupo visita un lugar de prueba.',
    );
  }

  testWidgets('creation honours a point supplied from the expanded map', (
    tester,
  ) async {
    await open(tester, createLocation: initial);
    await fillCreate(tester);
    await tap(tester, 'hito-add-publish');
    final request = provider.requests.single;
    expect(request.ubicacion, initial.label);
    expect(double.parse(request.latitud), initial.point.latitude);
    expect(double.parse(request.longitud), initial.point.longitude);
    expect(returned, isTrue);
    expectSharedSourceUnchanged();
    expect(tester.takeException(), isNull);
  });

  testWidgets('adjusting before publication retains text photos and voice', (
    tester,
  ) async {
    await open(tester);
    await fillCreate(tester);
    await tap(tester, 'hito-add-gallery');
    await tap(tester, 'voice-record');
    await tap(tester, 'voice-stop');
    final formState = tester.state(find.byType(HitoAddCoordScreen));
    await tap(tester, 'hito-adjust-location');
    final selected = await moveSelection(tester);
    await capture(tester, 'selector-ubicacion-fixture');
    expect(provider.requests, isEmpty);
    await tap(tester, 'hito-location-confirm');
    expect(tester.state(find.byType(HitoAddCoordScreen)), same(formState));
    expect(value(tester, 'hito-add-title'), 'Excursión ficticia');
    expect(
      value(tester, 'hito-add-description'),
      'El grupo visita un lugar de prueba.',
    );
    expect(key('hito-add-photo-0'), findsOneWidget);
    expect(find.text('Voz de prueba conservada'), findsOneWidget);
    expect(recorder.discards, 0);
    expect(completed, isFalse);
    expectSharedSourceUnchanged();
    await capture(tester, 'borrador-ubicacion-fixture');
    await tap(tester, 'hito-add-publish');
    final request = provider.requests.single;
    expect(request.ubicacion, 'Punto seleccionado en el mapa');
    expect(double.parse(request.latitud), closeTo(selected.latitude, 1e-8));
    expect(double.parse(request.longitud), closeTo(selected.longitude, 1e-8));
    expect(provider.uploadedPhotos.single.path, photo.path);
    expect(provider.uploadedVoices.single, same(recorder.draft));
    expect(returned, isTrue);
    expectSharedSourceUnchanged();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the creation picker preserves original coordinates', (
    tester,
  ) async {
    await open(tester, createLocation: initial);
    await fillCreate(tester);
    await tap(tester, 'hito-adjust-location');
    await moveSelection(tester);
    await tap(tester, 'hito-location-cancel');
    await tap(tester, 'hito-add-publish');
    final request = provider.requests.single;
    expect(request.ubicacion, initial.label);
    expect(double.parse(request.latitud), initial.point.latitude);
    expect(double.parse(request.longitud), initial.point.longitude);
    expectSharedSourceUnchanged();
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing picker cancel keeps texts and omits location update', (
    tester,
  ) async {
    var calls = 0;
    await open(
      tester,
      edit: (title, description, closing, location) async {
        calls++;
        expect(title, 'Título editado de prueba');
        expect(description, detail.descripcion);
        expect(closing, detail.notaCierre);
        expect(location, isNull);
      },
    );
    await tester.enterText(key('hito-edit-title'), 'Título editado de prueba');
    await tap(tester, 'hito-edit-location');
    await moveSelection(tester);
    await tap(tester, 'hito-location-cancel');
    expect(value(tester, 'hito-edit-title'), 'Título editado de prueba');
    expect(calls, 0);
    await tap(tester, 'hito-edit-save');
    expect(calls, 1);
    expect(returned, isTrue);
    expectSharedSourceUnchanged();
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed edit retains chosen point and text for explicit retry', (
    tester,
  ) async {
    final attempts = <HitoLocationDraft?>[];
    final submittedText = <List<String>>[];
    await open(
      tester,
      edit: (title, description, closing, location) async {
        attempts.add(location);
        submittedText.add([title, description, closing]);
        if (attempts.length == 1) throw StateError('Synthetic save failure');
      },
    );
    await tester.enterText(key('hito-edit-title'), 'Título nuevo');
    await tester.enterText(key('hito-edit-description'), 'Descripción nueva.');
    await tester.enterText(key('hito-edit-closing'), 'Cierre nuevo.');
    await tap(tester, 'hito-edit-location');
    final selected = await moveSelection(tester);
    await tap(tester, 'hito-location-confirm');
    await tap(tester, 'hito-edit-save');
    expect(completed, isFalse);
    expect(attempts, hasLength(1));
    expect(attempts.single!.point.latitude, closeTo(selected.latitude, 1e-8));
    expect(attempts.single!.point.longitude, closeTo(selected.longitude, 1e-8));
    expect(attempts.single!.label, 'Punto seleccionado en el mapa');
    expect(find.textContaining('Tu borrador sigue aquí'), findsOneWidget);
    expect(value(tester, 'hito-edit-title'), 'Título nuevo');
    expect(value(tester, 'hito-edit-description'), 'Descripción nueva.');
    expect(value(tester, 'hito-edit-closing'), 'Cierre nuevo.');
    await tap(tester, 'hito-edit-location');
    expect(
      camera(tester).camera.center.latitude,
      closeTo(selected.latitude, 1e-8),
    );
    expect(
      camera(tester).camera.center.longitude,
      closeTo(selected.longitude, 1e-8),
    );
    await moveSelection(tester);
    await tap(tester, 'hito-location-cancel');
    await tap(tester, 'hito-edit-save');
    expect(attempts, hasLength(2));
    expect(attempts.last, same(attempts.first));
    expect(submittedText.first, [
      'Título nuevo',
      'Descripción nueva.',
      'Cierre nuevo.',
    ]);
    expect(submittedText.last, submittedText.first);
    expect(returned, isTrue);
    expectSharedSourceUnchanged();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling edited form never saves a confirmed map adjustment', (
    tester,
  ) async {
    var calls = 0;
    await open(
      tester,
      edit: (_, _, _, _) async {
        calls++;
      },
    );
    await tap(tester, 'hito-edit-location');
    await moveSelection(tester);
    await tap(tester, 'hito-location-confirm');
    await tap(tester, 'hito-edit-cancel');
    expect(calls, 0);
    expect(returned, isFalse);
    expectSharedSourceUnchanged();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid original accepts explicit confirmation without movement',
    (tester) async {
      HitoLocationDraft? saved;
      await open(
        tester,
        locationNeedsConfirmation: true,
        edit: (_, _, _, location) async {
          saved = location;
        },
      );
      await tap(tester, 'hito-edit-location');
      await tap(tester, 'hito-location-confirm');
      await tap(tester, 'hito-edit-save');
      expect(saved, same(initial));
      expect(returned, isTrue);
      expectSharedSourceUnchanged();
      expect(tester.takeException(), isNull);
    },
  );
}
