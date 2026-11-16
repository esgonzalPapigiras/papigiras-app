import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/maps/trip_binnacle_timeline.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/gallery/trip_gallery_controller.dart';
import 'package:papigiras_app/gallery/trip_gallery_screen.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/likes/photo_likes_repository.dart';
import 'package:papigiras_app/likes/photo_likes_store.dart';
import 'package:papigiras_app/likes/photo_likes_widgets.dart';
import 'package:papigiras_app/maps/pilo_map_expanded_card.dart';
import 'package:papigiras_app/maps/trip_hito_content.dart';
import 'package:papigiras_app/maps/trip_hito_detail.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

const tour = 910001, hito = 910101, firstPhoto = 910201, lastPhoto = 910203;

class _Reactions implements PhotoLikesRepository {
  int loads = 0;
  final bool canLike;
  _Reactions({this.canLike = true});
  final calls = <({int tour, int hito, int photo, bool liked})>[];
  final values = <int, PhotoLikeState>{
    firstPhoto: const PhotoLikeState(
      photoId: firstPhoto,
      hitoId: hito,
      likeCount: 4,
      likedByMe: false,
    ),
    lastPhoto: const PhotoLikeState(
      photoId: lastPhoto,
      hitoId: hito,
      likeCount: 1,
      likedByMe: false,
    ),
  };
  int get total => values.values.fold(0, (sum, photo) => sum + photo.likeCount);
  @override
  Future<PhotoLikesSnapshot> load(int tourId) async {
    loads++;
    expect(tourId, tour);
    return PhotoLikesSnapshot(
      canLike: canLike,
      photos: values.values.toList(),
      hitoTotals: {hito: total},
    );
  }

  @override
  Future<PhotoLikeResult> setLiked({
    required int tourId,
    required int hitoId,
    required int photoId,
    required bool liked,
  }) async {
    calls.add((tour: tourId, hito: hitoId, photo: photoId, liked: liked));
    values[photoId] = values[photoId]!.withLiked(liked);
    return PhotoLikeResult(photo: values[photoId]!, hitoLikeCount: total);
  }
}

class _Photos extends CoordinatorProviders {
  final DetailHitoList detail;
  _Photos(this.detail);
  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourCode) async => [
    _row(),
  ];
  @override
  Future<DetailHitoList> getHitoComplete(String hitoId, String tourId) async =>
      detail;
}

ConsolidatedTourSalesDTO _row() => ConsolidatedTourSalesDTO(
  binnacleDetailId: hito,
  binnacleTitulo: 'Paseo de ejemplo',
  binnacleDescripcion: 'Texto de la foto',
  binnacleUbicacion: 'Mirador de ejemplo',
  binnacleNotaCierre: '',
  binnacleLatitud: '-33.45',
  binnacleLongitud: '-70.65',
  binnacleHora: '12:00',
  binnacleFecha: '14/11/2026',
  author: null,
  canModify: false,
);

class _Gallery extends TripGalleryController {
  _Gallery(CoordinatorProviders provider)
    : super(tourId: tour, provider: provider);
  @override
  Future<Uint8List?> thumbnail(TripGalleryPhoto photo) async =>
      Uint8List.fromList(TileProvider.transparentImage);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final capture = Platform.environment['PILO_LIKES_CAPTURE'] == '1';
  setUpAll(() async {
    if (!capture) return;
    await Future.wait([
      for (final name in [
        'CupertinoIcons',
        'packages/cupertino_icons/CupertinoIcons',
      ])
        (FontLoader(name)..addFont(
              rootBundle.load(
                'packages/cupertino_icons/assets/CupertinoIcons.ttf',
              ),
            ))
            .load(),
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
  Future<void> captureFixture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('likes-fixture-capture')),
          )
          .toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final folder = Directory('registro-local/PILO-FOTO-LIKES-R2/evidencia');
        await folder.create(recursive: true);
        await File(
          '${folder.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  final encoded = base64Encode(TileProvider.transparentImage);
  late _Reactions reactions;
  late PhotoLikesStore store;
  late DetailHitoList detail;
  setUp(() {
    LabMode.useFixturesForTests(true);
    reactions = _Reactions();
    detail = DetailHitoList(
      titulo: 'Paseo de ejemplo',
      fecha: '14/11/2026',
      images: [encoded, encoded, encoded],
      imageIds: [firstPhoto, null, lastPhoto],
    );
  });
  tearDown(() {
    store.dispose();
    LabMode.useFixturesForTests(false);
  });

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(393, 852),
  }) async {
    store = PhotoLikesStore(tourId: tour, repository: reactions);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      PhotoLikesScope(
        store: store,
        child: MaterialApp(
          theme: capture
              ? PiloFamilyTheme.theme(ThemeData(fontFamily: 'Inter'))
              : null,
          builder: capture
              ? (context, child) => RepaintBoundary(
                  key: const ValueKey('likes-fixture-capture'),
                  child: child!,
                )
              : null,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder heart(int id) => find.byKey(ValueKey('photo-like-$id')).hitTestable();
  void expectViewer(WidgetTester tester, int index) {
    final gallery = tester.widget<TripPhotoGallery>(
      find.byType(TripPhotoGallery),
    );
    expect(gallery.tourId, tour);
    expect(gallery.hitoId, hito);
    expect(gallery.imageIds, [firstPhoto, null, lastPhoto]);
    expect(gallery.initialIndex, index);
    expect(find.byType(InteractiveViewer), findsWidgets);
  }

  testWidgets(
    'hito photo reactions remain separate from zoom and carry server identities across pages',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await show(
          tester,
          TripHitoContent(
            detail: detail,
            tourId: tour,
            hitoId: hito,
            familyStyle: true,
          ),
        );
        expect(
          tester.getSemantics(heart(firstPhoto)).label,
          contains('4 me gusta'),
        );
        expect(
          tester.getSize(heart(firstPhoto)).height,
          greaterThanOrEqualTo(44),
        );
        await tester.tap(heart(firstPhoto));
        await tester.pumpAndSettle();
        expect(reactions.calls.single, (
          tour: tour,
          hito: hito,
          photo: firstPhoto,
          liked: true,
        ));
        expect(find.byType(TripPhotoGallery), findsNothing);
        expect(store.totalForHito(hito), 6);
        await tester.tap(find.byKey(const ValueKey('trip-content-photo-0')));
        await tester.pumpAndSettle();
        expectViewer(tester, 0);
        expect(
          tester.getSemantics(heart(firstPhoto)).label,
          contains('Quitar Me gusta'),
        );
        await tester.tap(find.byTooltip('Foto siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('2 de 3'), findsOneWidget);
        expect(heart(firstPhoto), findsNothing);
        expect(heart(lastPhoto), findsNothing);
        await tester.tap(find.byTooltip('Foto siguiente'));
        await tester.pumpAndSettle();
        await tester.tap(heart(lastPhoto));
        await tester.pumpAndSettle();
        expect(reactions.calls.last.photo, lastPhoto);
        expect(store.totalForHito(hito), 7);
        await tester.tap(find.byTooltip('Cerrar fotos'));
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(find.byKey(const ValueKey('hito-like-$hito')))
              .label,
          '7 me gusta en las fotos de este hito',
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'Pilo timeline reveals larger photos and photo reactions only when expanded',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final provider = _Photos(detail);
      final controller = TripMapController(tourCode: tour, provider: provider);
      try {
        await controller.refresh();
        await show(
          tester,
          TripBinnacleTimeline(
            tourId: tour,
            controller: controller,
            showAuthor: false,
            onOpenDetail: (_) async {},
            familyHeader: (_) => const Text('Bitácora'),
          ),
        );
        final card = find.byKey(const ValueKey('timeline-card-$hito'));
        final pager = find.byKey(const ValueKey('trip-inline-photos'));
        final toggle = find.byKey(const ValueKey('trip-timeline-toggle'));
        final aggregate = find.byKey(const ValueKey('hito-like-$hito'));
        final title = find.text('Paseo de ejemplo');
        final compactHeight = tester.getSize(card).height;
        final compactPhotoSize = tester.getSize(pager);
        Offset titlePosition() =>
            tester.getTopLeft(title) - tester.getTopLeft(card);
        final initialTitlePosition = titlePosition();
        expect(find.byType(PhotoLikeButton), findsNothing);
        expect(tester.getSemantics(aggregate).label, startsWith('5 me gusta'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(titlePosition(), initialTitlePosition);
        expect(tester.getSize(pager).height, inInclusiveRange(180, 220));
        expect(
          tester.getSize(pager).width,
          greaterThan(compactPhotoSize.width * 2),
        );
        expect(tester.getSize(card).height, greaterThan(compactHeight));
        expect(heart(firstPhoto), findsOneWidget);
        await tester.tap(heart(firstPhoto));
        await tester.pumpAndSettle();
        expect(store.photo(firstPhoto)!.likedByMe, isTrue);
        expect(tester.getSemantics(aggregate).label, startsWith('6 me gusta'));
        expect(find.byTooltip('Reducir hito'), findsOneWidget);
        await tester.drag(pager, Offset(-tester.getSize(pager).width * .9, 0));
        await tester.pumpAndSettle();
        expect(find.text('2/3'), findsOneWidget);
        expect(find.byType(PhotoLikeButton), findsNothing);
        await tester.drag(pager, Offset(-tester.getSize(pager).width * .9, 0));
        await tester.pumpAndSettle();
        expect(find.text('3/3'), findsOneWidget);
        expect(heart(lastPhoto), findsOneWidget);
        await tester.tap(heart(lastPhoto));
        await tester.pumpAndSettle();
        expect(reactions.calls.last.photo, lastPhoto);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byType(PhotoLikeButton), findsNothing);
        expect(tester.getSize(card).height, closeTo(compactHeight, .1));
        expect(tester.getSemantics(aggregate).label, startsWith('7 me gusta'));
        expect(find.text('3/3'), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(heart(lastPhoto), findsOneWidget);
        expect(tester.getSize(pager).height, inInclusiveRange(180, 220));
        expect(find.byType(TripPhotoGallery), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        provider.dispose();
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'collage hearts stay accessible and viewer retains photo sharing and download',
    (tester) async {
      final provider = _Photos(detail);
      final gallery = _Gallery(provider);
      await gallery.refresh();
      await show(
        tester,
        TripGalleryScreen(
          tourId: tour,
          departure: '2026-11-14',
          controller: gallery,
        ),
        size: const Size(320, 740),
      );
      final semantics = tester.ensureSemantics();
      try {
        expect(heart(firstPhoto), findsOneWidget);
        expect(heart(lastPhoto), findsOneWidget);
        expect(
          tester.getSemantics(heart(firstPhoto)).label,
          contains('Me gusta'),
        );
        await tester.tap(heart(firstPhoto));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('gallery-viewer')), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('gallery-photo-$hito:photo-$firstPhoto')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('gallery-viewer')), findsOneWidget);
        expect(find.byTooltip('Compartir foto'), findsOneWidget);
        expect(find.byTooltip('Descargar foto'), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsWidgets);
        await tester.tap(find.byTooltip('Foto siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('2 / 3'), findsOneWidget);
        expect(heart(firstPhoto), findsNothing);
        expect(heart(lastPhoto), findsNothing);
        await tester.tap(find.byTooltip('Foto siguiente'));
        await tester.pumpAndSettle();
        await tester.tap(heart(lastPhoto));
        await tester.pumpAndSettle();
        expect(reactions.calls.map((c) => c.photo), [firstPhoto, lastPhoto]);
        await tester.tap(find.byTooltip('Cerrar fotos'));
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(heart(lastPhoto)).label,
          contains('2 me gusta'),
        );
        final loadedBeforeRefresh = reactions.loads;
        reactions.values[lastPhoto] = const PhotoLikeState(
          photoId: lastPhoto,
          hitoId: hito,
          likeCount: 8,
          likedByMe: true,
        );
        await tester.tap(find.byTooltip('Actualizar galería'));
        await tester.pumpAndSettle();
        expect(reactions.loads, loadedBeforeRefresh + 1);
        expect(store.photo(lastPhoto)!.likeCount, 8);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        gallery.dispose();
        provider.dispose();
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'expanded map carousel follows the current photo and opens the same identity',
    (tester) async {
      final provider = _Photos(detail);
      final controller = TripMapController(tourCode: tour, provider: provider);
      final entry = TripMapData.from([_row()]).entries.single;
      await show(
        tester,
        SizedBox(
          height: 420,
          child: PiloMapExpandedCard(
            entry: entry,
            controller: controller,
            detail: Future.value(detail),
            active: true,
          ),
        ),
      );
      expect(heart(firstPhoto), findsOneWidget);
      final counter = find.text('1/3');
      expect(
        tester.getTopLeft(counter).dy,
        lessThan(tester.getTopLeft(heart(firstPhoto)).dy),
      );
      await tester.drag(
        find.byKey(const ValueKey('pilo-map-expanded-photos')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(heart(firstPhoto), findsNothing);
      expect(heart(lastPhoto), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('pilo-map-expanded-photos')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(heart(lastPhoto));
      await tester.pumpAndSettle();
      expect(reactions.calls.single.photo, lastPhoto);
      await tester.tap(find.byKey(const ValueKey('pilo-map-expanded-photos')));
      await tester.pumpAndSettle();
      expectViewer(tester, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      provider.dispose();
    },
  );

  testWidgets(
    'standalone map hito detail carries photo identities to the full viewer',
    (tester) async {
      final provider = _Photos(detail);
      final controller = TripMapController(tourCode: tour, provider: provider);
      await controller.refresh();
      final entry = TripMapData.from([_row()]).entries.single;
      await show(
        tester,
        TripHitoDetail(controller: controller, entry: entry, pilo: true),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('photo-like-$firstPhoto')),
      );
      await tester.pumpAndSettle();
      await tester.tap(heart(firstPhoto));
      await tester.pumpAndSettle();
      expect(reactions.calls.single.photo, firstPhoto);
      expect(find.byType(TripPhotoGallery), findsNothing);
      await tester.tap(find.bySemanticsLabel('Abrir foto 1 de 3'));
      await tester.pumpAndSettle();
      expectViewer(tester, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      provider.dispose();
    },
  );

  testWidgets('read-only coordinator photo counts have no reaction mutation', (
    tester,
  ) async {
    reactions = _Reactions(canLike: false);
    await show(
      tester,
      TripHitoContent(detail: detail, tourId: tour, hitoId: hito),
    );
    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester.getSemantics(heart(firstPhoto)).label,
        '4 me gusta en esta foto',
      );
      await tester.tap(heart(firstPhoto));
      await tester.pumpAndSettle();
      expect(reactions.calls, isEmpty);
      expect(find.byType(TripPhotoGallery), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'missing photo identities keep images viewable without inventing reactions',
    (tester) async {
      await show(
        tester,
        TripHitoContent(
          detail: DetailHitoList(images: [encoded, encoded]),
          tourId: tour,
          hitoId: hito,
        ),
      );
      expect(find.byType(PhotoLikeButton), findsNothing);
      await tester.tap(find.byKey(const ValueKey('trip-content-photo-0')));
      await tester.pumpAndSettle();
      expect(find.byType(TripPhotoGallery), findsOneWidget);
      expect(find.byType(PhotoLikeButton), findsNothing);
      await tester.tap(find.byTooltip('Foto siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2'), findsOneWidget);
      expect(reactions.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  if (capture)
    testWidgets('synthetic likes visual fixtures', (tester) async {
      final pictures = <String>[];
      await tester.runAsync(() async {
        for (var i = 0; i < 3; i++) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 720, 480),
            Paint()
              ..color = [
                const Color(0xffb4d9e1),
                const Color(0xffc7dfd3),
                const Color(0xffe8d3b5),
              ][i],
          );
          canvas.drawCircle(
            Offset(535 - i * 45.0, 115),
            44,
            Paint()..color = const Color(0xfff5eed3),
          );
          final mountains = Path()
            ..moveTo(0, 300)
            ..lineTo(170, 120)
            ..lineTo(305, 270)
            ..lineTo(460, 135)
            ..lineTo(720, 320)
            ..close();
          canvas.drawPath(mountains, Paint()..color = const Color(0xff718e82));
          canvas.drawRect(
            const Rect.fromLTWH(0, 285, 720, 195),
            Paint()..color = const Color(0xff7ea9b5),
          );
          final shore = Path()
            ..moveTo(0, 360)
            ..quadraticBezierTo(260, 320, 720, 455)
            ..lineTo(720, 480)
            ..lineTo(0, 480)
            ..close();
          canvas.drawPath(shore, Paint()..color = const Color(0xffd9ddc7));
          final recording = recorder.endRecording();
          final image = await recording.toImage(720, 480);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            pictures.add(base64Encode(bytes!.buffer.asUint8List()));
          } finally {
            image.dispose();
            recording.dispose();
          }
        }
      });
      detail = DetailHitoList(
        titulo: 'Una tarde junto al lago',
        descripcion:
            'Compartimos una caminata y un lindo momento junto al agua.',
        fecha: '14/11/2026',
        hora: '16:20',
        ubicacion: 'Mirador de ejemplo',
        images: pictures,
        imageIds: [firstPhoto, null, lastPhoto],
      );
      final provider = _Photos(detail);
      final gallery = TripGalleryController(tourId: tour, provider: provider);
      await gallery.refresh();
      await tester.runAsync(
        () => Future.wait(gallery.photos.map(gallery.thumbnail)),
      );
      await show(
        tester,
        TripGalleryScreen(
          tourId: tour,
          departure: '2026-11-12',
          controller: gallery,
        ),
      );
      await captureFixture(tester, 'galeria-likes-fixture');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      gallery.dispose();
      store.dispose();
      final controller = TripMapController(tourCode: tour, provider: provider);
      await controller.refresh();
      await show(
        tester,
        TripBinnacleTimeline(
          tourId: tour,
          controller: controller,
          showAuthor: false,
          onOpenDetail: (_) async {},
          familyHeader: (_) => PiloSectionBar(title: 'Bitácora', onBack: () {}),
        ),
      );
      await captureFixture(tester, 'bitacora-compacta-likes-fixture');
      await tester.tap(find.text('Una tarde junto al lago'));
      await tester.pumpAndSettle();
      await captureFixture(tester, 'bitacora-likes-fixture');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      provider.dispose();
    });
}
