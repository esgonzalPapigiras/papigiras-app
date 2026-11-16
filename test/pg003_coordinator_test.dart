import 'package:papigiras_app/voice/hito_publish_progress.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorProfile.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorTourSelection.dart';
import 'package:papigiras_app/pages/coordinator/detailbinnacleCoodinator.dart';
import 'package:papigiras_app/pages/coordinator/listPassenger.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/viewProgram.dart';
import 'package:papigiras_app/utils/LocationService.dart';

import 'support/map_tiles.dart';

class _CountingHitoProvider extends CoordinatorProviders {
  int creates = 0;
  int uploads = 0;
  int deletes = 0;
  Completer<void>? pendingDelete;
  bool partialPhotoFailure = false;
  String? photoPayload;
  @override
  Future<ConsolidatedTourSalesDTO> addHito(RequestHito request) async {
    creates++;
    return super.addHito(request);
  }

  @override
  Future<void> deleteHito(String idHito, String idTour) async {
    deletes++;
    await pendingDelete?.future;
    await super.deleteHito(idHito, idTour);
  }

  @override
  Future<void> addHitoFoto(
    int hito,
    String tourId,
    List<XFile> files, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    uploads++;
    if (partialPhotoFailure) {
      onProgress?.call(
        const HitoPublishProgress('Cargando fotos…', fraction: 0.25),
      );
      LabFixtures.photos[hito] = [photoPayload!];
      throw const FormatException('Fallo de transporte ficticio');
    }
    await super.addHitoFoto(hito, tourId, files, onProgress: onProgress);
  }
}

class _FixturePicker extends ImagePicker {
  _FixturePicker(this.file);
  final XFile file;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async => [file];
}

void main() {
  final tour = TourSales.fromCoordinatorTour(
    coordinator: LabFixtures.coordinator,
    tour: LabFixtures.tour,
  );
  setUp(() async {
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    LabMapTiles.testProvider = TestMapTileProvider.new;
    await (await SharedPreferences.getInstance()).clear();
  });
  tearDown(() {
    LabMapTiles.testProvider = null;
    LabMode.useFixturesForTests(false);
  });
  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    bool narrow = false,
  }) async {
    tester.view.physicalSize = Size(narrow ? 320 : 393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocationService(),
        child: MaterialApp(
          theme: papiTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('read-only hito exposes no delete action', (tester) async {
    await show(
      tester,
      DetalleBitacoraCoordScreen(idHito: '1', login: tour, canModify: false),
    );
    expect(find.text('Eliminar hito'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancelling hito deletion preserves the fixture and detail', (
    tester,
  ) async {
    await show(
      tester,
      DetalleBitacoraCoordScreen(idHito: '1', login: tour, canModify: true),
    );
    final count = LabFixtures.hitos.length;
    await tester.ensureVisible(find.text('Eliminar hito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar hito'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(LabFixtures.hitos.length, count);
    expect(find.text('Llegada al hotel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed deletion stays on hito and blocks another pending request',
    (tester) async {
      final provider = _CountingHitoProvider()
        ..pendingDelete = Completer<void>();
      addTearDown(provider.dispose);
      await show(
        tester,
        DetalleBitacoraCoordScreen(
          idHito: '1',
          login: tour,
          canModify: true,
          provider: provider,
        ),
      );
      final count = LabFixtures.hitos.length;
      await tester.ensureVisible(find.text('Eliminar hito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar hito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(provider.deletes, 1);
      final pending = find.ancestor(
        of: find.text('Eliminando hito…'),
        matching: find.bySubtype<TextButton>(),
      );
      expect(tester.widget<TextButton>(pending).onPressed, isNull);
      provider.pendingDelete!.completeError(StateError('Rechazo ficticio'));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleBitacoraCoordScreen), findsOneWidget);
      expect(LabFixtures.hitos.length, count);
      expect(
        find.text('No pudimos eliminar el hito. Vuelve a intentarlo.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty hito form cannot create a record', (tester) async {
    await show(tester, HitoAddCoordScreen(login: tour));
    final count = LabFixtures.hitos.length;
    await tester.ensureVisible(find.text('Publicar hito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar hito'));
    await tester.pumpAndSettle();
    expect(LabFixtures.hitos.length, count);
    expect(find.byType(HitoAddCoordScreen), findsOneWidget);
    expect(find.text('Escribe un título.'), findsOneWidget);
    expect(find.text('Escribe una descripción.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  Future<void> openForm(
    WidgetTester tester,
    _CountingHitoProvider provider, {
    ImagePicker? picker,
  }) async {
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            child: const Text('Crear hito de prueba'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HitoAddCoordScreen(
                  login: tour,
                  provider: provider,
                  picker: picker,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Crear hito de prueba'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Prueba de publicación',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Descripción ficticia',
    );
  }

  testWidgets('hito without photos skips the multipart endpoint', (
    tester,
  ) async {
    final provider = _CountingHitoProvider();
    addTearDown(provider.dispose);
    await openForm(tester, provider);
    await tester.ensureVisible(find.text('Publicar hito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar hito'));
    await tester.pumpAndSettle();
    expect(provider.creates, 1);
    expect(provider.uploads, 0);
    expect(find.text('Crear hito de prueba'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'ambiguous photo upload directs to review without replaying files',
    (tester) async {
      late Directory directory;
      late File file;
      late String payload;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('pg003-photo-');
        final bytes = await rootBundle.load('assets/logo-letras-papigiras.png');
        payload = base64Encode(bytes.buffer.asUint8List());
        file = await File(
          '${directory.path}/foto-ficticia.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
      });
      addTearDown(
        () => tester.runAsync(() => directory.delete(recursive: true)),
      );
      final provider = _CountingHitoProvider()
        ..partialPhotoFailure = true
        ..photoPayload = payload;
      addTearDown(provider.dispose);
      await openForm(
        tester,
        provider,
        picker: _FixturePicker(XFile(file.path)),
      );
      await tester.ensureVisible(find.text('Galería'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Galería'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Publicar hito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar hito'));
      await tester.pumpAndSettle();
      expect(provider.creates, 1);
      expect(provider.uploads, 1);
      final review = find.text('Ver bitácora');
      expect(review.hitTestable(), findsOneWidget);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(provider.creates, 1);
      expect(provider.uploads, 1);
      expect(find.byType(BitacoraCoordScreen), findsOneWidget);
      expect(find.text('Prueba de publicación'), findsOneWidget);
      expect(LabFixtures.photos.values.single.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'compact coordinator dashboard keeps primary navigation visible and details available',
    (tester) async {
      await show(
        tester,
        Padding(
          padding: const EdgeInsets.only(top: 96),
          child: TravelCoordinatorDashboard(login: tour),
        ),
      );
      expect(find.text('Nuevo hito').hitTestable(), findsOneWidget);
      expect(find.text('Contador').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('family-tab-diary')).hitTestable(),
        findsOneWidget,
      );
      final progress = find.bySemanticsLabel('Avance de la gira');
      expect(progress, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('coordinator-trip-details')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('10/11/2026', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('16/11/2026', findRichText: true),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Cerrar'));
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      final roster = find.byKey(const ValueKey('home-passenger-list'));
      await tester.ensureVisible(roster);
      await tester.pumpAndSettle();
      expect(find.text('Alumnos'), findsOneWidget);
      expect(find.text('Acompañantes'), findsOneWidget);
      await tester.tap(roster);
      await tester.pumpAndSettle();
      expect(find.byType(ListPassengerCoordScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(TravelCoordinatorDashboard), findsOneWidget);
      expect(tour.tourSalesInit, '2026-11-10');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  final screens = <String, Widget Function()>{
    'coordinator dashboard': () => TravelCoordinatorDashboard(login: tour),
    'tour choice': () => const CoordinatorTourSelectionScreen(
      coordinator: LabFixtures.coordinator,
    ),
    'profile': () => const CoordinatorProfileScreen(),
    'hito': () =>
        DetalleBitacoraCoordScreen(idHito: '1', login: tour, canModify: true),
    'binnacle': () => BitacoraCoordScreen(login: tour),
    'passenger list': () => ListPassengerCoordScreen(login: tour),
    'bus and crew': () => BusCrewCoorScreen(login: tour),
    'program': () => ViewProgramCoordScreen(login: tour),
    'new hito': () => HitoAddCoordScreen(login: tour),
  };
  for (final entry in screens.entries) {
    testWidgets(
      '${entry.key} supports 320px and large text with synthetic data',
      (tester) async {
        await show(tester, entry.value(), narrow: true);
        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
