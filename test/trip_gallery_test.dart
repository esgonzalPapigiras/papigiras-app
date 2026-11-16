import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/gallery/trip_gallery_controller.dart';
import 'package:papigiras_app/gallery/trip_gallery_screen.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ConsolidatedTourSalesDTO row(int id, String date, {String time = '12:00'}) =>
    ConsolidatedTourSalesDTO(
      binnacleDetailId: id,
      binnacleTitulo: 'Hito ficticio $id',
      binnacleDescripcion: 'No mostrar descripción',
      binnacleUbicacion: '',
      binnacleNotaCierre: '',
      binnacleLatitud: '',
      binnacleLongitud: '',
      binnacleHora: time,
      binnacleFecha: date,
      author: null,
      canModify: false,
    );

class PhotosProvider extends CoordinatorProviders {
  PhotosProvider(this.rows, {this.picture = ''});
  List<ConsolidatedTourSalesDTO> rows;
  String picture;
  final requests = <int>[];
  final counts = <int, int>{};
  final pictures = <int, String>{};
  final missing = <int, int>{};
  final imageIds = <int, List<int?>>{};
  final imageLists = <int, List<String>>{};
  int? failId;
  bool failList = false;
  Completer<DetailHitoList>? pending;
  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourCode) async {
    expect(tourCode, '910001');
    if (failList) throw StateError('fixture');
    return rows;
  }

  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tourId) async {
    expect(tourId, '910001');
    final id = int.parse(hito);
    requests.add(id);
    if (id == failId) throw StateError('fixture');
    if (pending != null) return pending!.future;
    return DetailHitoList(
      images:
          imageLists[id] ??
          List.filled(counts[id] ?? 1, pictures[id] ?? picture),
      imageIds: imageIds[id] ?? const [],
      missingImageCount: missing[id] ?? 0,
    );
  }
}

// Isolate photo-detail pagination from asynchronous thumbnail encoding.
class _FixedThumbnailController extends TripGalleryController {
  _FixedThumbnailController(PhotosProvider provider, this.bytes)
    : super(tourId: 910001, provider: provider);

  final Uint8List bytes;

  @override
  Future<Uint8List?> thumbnail(TripGalleryPhoto photo) async => bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'calendar days use departure and do not invent days for missing/pre-trip dates',
    () {
      expect(
        TripGalleryDay(DateTime.utc(2026, 10, 28), []).title('2026-10-26'),
        'Día 3',
      );
      expect(
        TripGalleryDay(DateTime.utc(2026, 10, 25), []).title('2026-10-26'),
        '25 oct 2026',
      );
      expect(
        TripGalleryDay(DateTime.utc(2026, 10, 28), []).title(''),
        '28 oct 2026',
      );
      expect(TripGalleryDay(null, []).title('2026-10-26'), 'Sin fecha');
      expect(galleryCalendarDate('2026-02-30'), isNull);
      expect(
        galleryCalendarDate('2026-10-28T23:00:00-03:00'),
        DateTime.utc(2026, 10, 28),
      );
    },
  );
  test(
    'oldest first, tie by ID, unknown dates last, no duplicate hitos',
    () async {
      final p = PhotosProvider([
        row(5, ''),
        row(4, '27/10/2026', time: '14:00'),
        row(3, '27/10/2026'),
        row(2, '27/10/2026'),
        row(1, '26/10/2026'),
        row(1, '26/10/2026'),
      ]);
      final c = TripGalleryController(tourId: 910001, provider: p);
      await c.refresh();
      expect(p.requests, [1, 2, 3, 4]);
      expect(c.hasMore, isTrue);
      await c.loadMore();
      expect(c.photos.map((p) => p.hitoId), [1, 2, 3, 4, 5]);
      expect(c.days.length, 3);
      expect(c.days.last.date, isNull);
      expect(c.hasMore, isFalse);
      c.dispose();
      p.dispose();
    },
  );
  test(
    'no-photo hitos and missing attachments never produce invented tiles',
    () async {
      final p = PhotosProvider([row(1, '26/10/2026'), row(2, '27/10/2026')])
        ..counts[1] = 0
        ..counts[2] = 2
        ..missing[1] = 3;
      final c = TripGalleryController(tourId: 910001, provider: p);
      await c.refresh();
      expect(c.photos.map((p) => p.key), ['2:0', '2:1']);
      expect(c.unavailableImages, 3);
      c.dispose();
      p.dispose();
    },
  );
  test(
    'photo identities preserve null slots and never use the image index',
    () async {
      final p = PhotosProvider([row(1, '26/10/2026')])
        ..counts[1] = 3
        ..imageIds[1] = [910101, null, 910103];
      final c = TripGalleryController(tourId: 910001, provider: p);
      await c.refresh();
      expect(c.photos.map((photo) => photo.photoId), [910101, null, 910103]);
      expect(c.photos.map((photo) => photo.key), [
        '1:photo-910101',
        '1:1',
        '1:photo-910103',
      ]);
      c.dispose();
      p.dispose();
    },
  );
  test(
    'evicted photo details resolve stable IDs after reorder or deletion',
    () async {
      const red =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC';
      const blue =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC';
      final p =
          PhotosProvider([
              row(1, '26/10/2026'),
              row(2, '27/10/2026'),
              row(3, '28/10/2026'),
            ], picture: blue)
            ..imageLists[1] = [red, blue]
            ..imageIds[1] = [910101, 910102];
      final c = TripGalleryController(tourId: 910001, provider: p);
      await c.refresh();
      final original = c.photos.first;
      p.imageLists[1] = [blue, red];
      p.imageIds[1] = [910102, 910101];
      expect(await c.fullImage(original), base64Decode(red));
      // Evict the first hito again before reading a server-side removal.
      await c.fullImage(c.photos.firstWhere((p) => p.hitoId == 2));
      await c.fullImage(c.photos.firstWhere((p) => p.hitoId == 3));
      p.imageLists[1] = [blue];
      p.imageIds[1] = [910102];
      expect(await c.fullImage(original), isNull);
      c.dispose();
      p.dispose();
    },
  );
  test(
    'failure resumes at exact failed hito with previous photos preserved',
    () async {
      final p = PhotosProvider([
        row(1, '26/10/2026'),
        row(2, '27/10/2026'),
        row(3, '28/10/2026'),
      ])..failId = 2;
      final c = TripGalleryController(tourId: 910001, provider: p);
      await c.refresh();
      expect(c.photos.map((p) => p.key), ['1:0']);
      expect(c.error, isNotNull);
      p.failId = null;
      await c.loadMore();
      expect(c.photos.map((p) => p.key), ['1:0', '2:0', '3:0']);
      expect(c.error, isNull);
      c.dispose();
      p.dispose();
    },
  );
  test(
    'refresh reloads metadata; list failure retains previous results and can retry',
    () async {
      final p = PhotosProvider([row(1, '26/10/2026')]);
      final c = TripGalleryController(tourId: 910001, provider: p);
      await c.refresh();
      p.failList = true;
      await c.refresh();
      expect(c.photos.length, 1);
      expect(c.error, isNotNull);
      p.failList = false;
      p.rows = [row(2, '27/10/2026')];
      await c.retry();
      expect(c.photos.map((p) => p.key), ['2:0']);
      c.dispose();
      p.dispose();
    },
  );
  test(
    'closing during a response does not notify or continue the next batch',
    () async {
      final p = PhotosProvider([row(1, '26/10/2026'), row(2, '27/10/2026')])
        ..pending = Completer<DetailHitoList>();
      final c = TripGalleryController(tourId: 910001, provider: p);
      final task = c.refresh();
      await Future<void>.delayed(Duration.zero);
      c.dispose();
      p.pending!.complete(DetailHitoList());
      await task;
      expect(p.requests, [1]);
      p.dispose();
    },
  );
  test(
    'thumbnail is in-memory, valid image, shared across concurrent requests',
    () async {
      final picture = base64Encode(
        (await rootBundle.load('assets/profile.jpg')).buffer.asUint8List(),
      );
      final p = PhotosProvider([row(1, '26/10/2026')], picture: picture);
      final c = TripGalleryController(tourId: 910001, provider: p);
      await c.refresh();
      final images = await Future.wait([
        c.thumbnail(c.photos.first),
        c.thumbnail(c.photos.first),
      ]);
      expect(images[0], isNotEmpty);
      expect(identical(images[0], images[1]), isTrue);
      expect(p.requests, [1]);
      c.dispose();
      p.dispose();
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final setting in [
      (const Size(402, 874), 1.0),
      (const Size(320, 568), 2.0),
    ]) {
      testWidgets('collage, paging, back ${platform.name} $setting', (
        tester,
      ) async {
        tester.view.physicalSize = setting.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final picture = base64Encode(
          (await rootBundle.load('assets/profile.jpg')).buffer.asUint8List(),
        );
        final p =
            PhotosProvider([
                row(1, '26/10/2026'),
                row(2, '27/10/2026'),
              ], picture: picture)
              ..counts[1] = 5
              ..counts[2] = 2;
        final c = TripGalleryController(tourId: 910001, provider: p);
        await c.refresh();
        await tester.runAsync(() => Future.wait(c.photos.map(c.thumbnail)));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(setting.$2)),
              child: child!,
            ),
            home: TripGalleryScreen(
              tourId: 910001,
              departure: '2026-10-26',
              controller: c,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Día 1'), findsOneWidget);
        expect(find.text('No mostrar descripción'), findsNothing);
        final first = find.byKey(const ValueKey('gallery-photo-1:0'));
        final second = find.byKey(const ValueKey('gallery-photo-1:1'));
        expect(
          tester.getSize(first).width,
          greaterThan(tester.getSize(second).width),
        );
        await tester.ensureVisible(first);
        await tester.pumpAndSettle();
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('gallery-viewer')), findsOneWidget);
        expect(find.text('1 / 7'), findsOneWidget);
        await tester.tap(find.byTooltip('Foto siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('2 / 7'), findsOneWidget);
        await tester.drag(
          find.byKey(const ValueKey('gallery-viewer')),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('3 / 7'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar fotos'));
        await tester.pumpAndSettle();
        expect(first, findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Día 2'),
          300,
          scrollable: find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable).first,
          ),
        );
        expect(find.text('Día 2').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        p.dispose();
      });
    }
  }
  testWidgets('dates are reachable before loading their photo details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const picture =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGM4wcAAAAJcAMlDyBJGAAAAAElFTkSuQmCC';
    final provider =
        PhotosProvider([
            row(1, '26/10/2026'),
            row(2, '26/10/2026'),
            row(3, '27/10/2026'),
            row(4, '27/10/2026'),
            row(5, '28/10/2026'),
            row(6, '29/10/2026'),
            row(7, '30/10/2026'),
            row(8, '31/10/2026'),
          ], picture: picture)
          ..counts[2] = 4
          ..counts[4] = 4
          ..counts[7] = 0;
    final controller = _FixedThumbnailController(
      provider,
      base64Decode(picture),
    );
    await controller.refresh();
    expect(provider.requests, [1, 2, 3, 4]);

    await tester.pumpWidget(
      MaterialApp(
        home: TripGalleryScreen(
          tourId: 910001,
          departure: '2026-10-26',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(provider.requests, [1, 2, 3, 4]);

    final lastDate = find.widgetWithText(ChoiceChip, '31 oct.').hitTestable();
    expect(lastDate, findsOneWidget);
    await tester.tap(lastDate);
    await tester.pumpAndSettle();
    expect(provider.requests, [1, 2, 3, 4, 8]);
    expect(find.text('Día 6'), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-photo-1:0')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('gallery-photo-8:0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gallery-viewer')), findsOneWidget);
    expect(find.byKey(const ValueKey('full-8:0')), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar fotos'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '30 oct.'));
    await tester.pumpAndSettle();
    expect(provider.requests, [1, 2, 3, 4, 8, 7]);
    expect(
      find.text('No hay fotos disponibles para esta fecha.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('gallery-photo-8:0')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    provider.dispose();
  });

  testWidgets('photo actions export the currently selected original', (
    tester,
  ) async {
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('pilo-gallery-test-'),
    );
    addTearDown(() => root!.delete(recursive: true));
    const gal = MethodChannel('gal');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const share = MethodChannel('dev.fluttercommunity.plus/share');
    final messenger = tester.binding.defaultBinaryMessenger;
    addTearDown(() {
      for (final channel in [gal, paths, share]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
    // Native calls finish in runAsync's real I/O zone. Deliver their result
    // synchronously so it doesn't wait for the widget test's paused fake clock.
    final shared = Completer<Uint8List>.sync();
    final saved = Completer<Uint8List>.sync();
    messenger.setMockMethodCallHandler(gal, (call) async {
      if (call.method == 'requestAccess') return true;
      expect(call.method, 'putImageBytes');
      saved.complete((call.arguments as Map)['bytes'] as Uint8List);
      return null;
    });
    messenger.setMockMethodCallHandler(paths, (call) async {
      expect(call.method, 'getTemporaryDirectory');
      return root!.path;
    });
    messenger.setMockMethodCallHandler(share, (call) async {
      expect(call.method, 'shareFiles');
      final args = call.arguments as Map;
      expect(args['mimeTypes'], ['image/png']);
      final files = args['paths'] as List;
      shared.complete(File(files.single as String).readAsBytesSync());
      return ''; // Dismissing the system share sheet is not a share.
    });
    final provider = PhotosProvider([
      row(1, '26/10/2026'),
      row(2, '28/10/2026'),
    ]);
    // Solid-color PNG fixtures with distinct dimensions identify each export.
    const first =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGM4wcAAAAJcAMlDyBJGAAAAAElFTkSuQmCC';
    const second =
        'iVBORw0KGgoAAAANSUhEUgAAAAMAAAADCAIAAADZSiLoAAAAD0lEQVR4nGNgYDgBQ5gsAGKOBwnYreR2AAAAAElFTkSuQmCC';
    provider.pictures.addAll({1: first, 2: second});
    final controller = TripGalleryController(
      tourId: 910001,
      provider: provider,
    );
    await controller.refresh();
    await tester.runAsync(
      () => Future.wait(controller.photos.map(controller.thumbnail)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TripGalleryScreen(
          tourId: 910001,
          departure: '2026-10-26',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gallery-photo-1:0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Foto siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(saved.isCompleted, isFalse);
    expect(shared.isCompleted, isFalse);

    VoidCallback enabledAction(String label) {
      final button = find
          .ancestor(
            of: find.byTooltip(label),
            matching: find.byType(IconButton),
          )
          .hitTestable();
      expect(button, findsOneWidget);
      return tester.widget<IconButton>(button).onPressed!;
    }

    // The image codec and filesystem need real asynchronous I/O. Call the
    // enabled widget callback in that zone, outside fake gesture dispatch.
    final download = enabledAction('Descargar foto');
    final downloaded = await tester.runAsync(() async {
      download();
      return saved.future.timeout(const Duration(seconds: 8));
    });
    await tester.pumpAndSettle();
    expect(find.text('Foto guardada en la galería.'), findsOneWidget);
    final sharePhoto = enabledAction('Compartir foto');
    final sent = await tester.runAsync(() async {
      sharePhoto();
      return shared.future.timeout(const Duration(seconds: 8));
    });
    await tester.pumpAndSettle();
    expect(sent, downloaded);
    final data = ByteData.sublistView(downloaded!);
    expect(data.getUint32(16), 3);
    expect(data.getUint32(20), 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    provider.dispose();
  });
  testWidgets('empty gallery has recovery, no empty photo frames', (
    tester,
  ) async {
    final p = PhotosProvider([]);
    final c = TripGalleryController(tourId: 910001, provider: p);
    await c.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: TripGalleryScreen(tourId: 910001, departure: '', controller: c),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay fotos'), findsOneWidget);
    expect(find.byType(InkWell), findsWidgets);
    expect(find.byTooltip('Actualizar galería'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    p.dispose();
  });
}
