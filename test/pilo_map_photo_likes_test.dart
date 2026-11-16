import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/likes/photo_likes_repository.dart';
import 'package:papigiras_app/likes/photo_likes_store.dart';
import 'package:papigiras_app/likes/photo_likes_widgets.dart';
import 'package:papigiras_app/maps/pilo_map_area_carousel.dart';
import 'package:papigiras_app/maps/pilo_map_expanded_card.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

import 'support/map_tiles.dart';

const _tour = 910001, _firstHito = 910101, _secondHito = 910102;
const _firstPhoto = 910201, _lastPhoto = 910203, _secondHitoPhoto = 910204;

/// Real HTTP repository/store with an isolated wire-contract fixture.
/// No socket, production identity or persisted business data is involved.
class _LikesApi {
  int reads = 0;
  final writes = <Map<String, dynamic>>[];
  final photos = <int, PhotoLikeState>{
    _firstPhoto: const PhotoLikeState(
      photoId: _firstPhoto,
      hitoId: _firstHito,
      likeCount: 4,
      likedByMe: false,
    ),
    _lastPhoto: const PhotoLikeState(
      photoId: _lastPhoto,
      hitoId: _firstHito,
      likeCount: 1,
      likedByMe: false,
    ),
    _secondHitoPhoto: const PhotoLikeState(
      photoId: _secondHitoPhoto,
      hitoId: _secondHito,
      likeCount: 2,
      likedByMe: false,
    ),
  };
  int total(int hito) => photos.values
      .where((photo) => photo.hitoId == hito)
      .fold(0, (sum, photo) => sum + photo.likeCount);
  Map<String, Object> json(PhotoLikeState photo) => {
    'photoId': photo.photoId,
    'hitoId': photo.hitoId,
    'likeCount': photo.likeCount,
    'likedByMe': photo.likedByMe,
  };
  LabApiClient client() => LabApiClient(
    transport: MockClient((request) async {
      expect(request.url.origin, 'http://127.0.0.1:8084');
      expect(request.url.path, '/app/services/photo-likes');
      expect(request.headers['authorization'], 'Bearer synthetic-map-session');
      if (request.method == 'GET') {
        reads++;
        expect(request.url.queryParameters, {'tourId': '$_tour'});
        return http.Response(
          jsonEncode({
            'tourId': _tour,
            'canLike': true,
            'photos': photos.values.map(json).toList(),
            'hitos': [
              for (final id in [_firstHito, _secondHito])
                {'hitoId': id, 'totalLikes': total(id)},
            ],
          }),
          200,
        );
      }
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(
        body.keys,
        unorderedEquals(['tourId', 'hitoId', 'photoId', 'liked']),
      );
      expect(body['tourId'], _tour);
      final id = body['photoId'] as int;
      expect(body['hitoId'], photos[id]!.hitoId);
      writes.add(body);
      final photo = photos[id]!.withLiked(body['liked'] as bool);
      photos[id] = photo;
      return http.Response(
        jsonEncode({...json(photo), 'hitoLikeCount': total(photo.hitoId)}),
        200,
      );
    }),
  );
}

class _MapFixtures extends CoordinatorProviders {
  final image = base64Encode(TileProvider.transparentImage);
  @override
  Future<List<PositionCoordinator>> uniqueID(String code) async => [];
  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String code) async => [
    _row(_firstHito, '-33.45', '-70.65', '12:00'),
    _row(_secondHito, '-33.451', '-70.654', '11:00'),
  ];
  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tour) async =>
      DetailHitoList(
        titulo: 'Hito de prueba',
        descripcion: 'Descripción breve de ejemplo.',
        images: hito == '$_firstHito' ? [image, image, image] : [image],
        // The middle item is legacy media without a stable photo ID.
        imageIds: hito == '$_firstHito'
            ? [_firstPhoto, null, _lastPhoto]
            : [_secondHitoPhoto],
      );
}

ConsolidatedTourSalesDTO _row(
  int id,
  String latitude,
  String longitude,
  String time,
) => ConsolidatedTourSalesDTO(
  binnacleDetailId: id,
  binnacleTitulo: 'Hito de prueba',
  binnacleDescripcion: 'Descripción breve de ejemplo.',
  binnacleUbicacion: 'Lugar de ejemplo',
  binnacleNotaCierre: '',
  binnacleLatitud: latitude,
  binnacleLongitud: longitude,
  binnacleHora: time,
  binnacleFecha: '14/11/2026',
  author: null,
  canModify: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> flushTransport(
    WidgetTester tester,
    bool Function() pending,
  ) async {
    // HTTP's response stream may finish in the real event queue even after
    // widget animations settle. Await confirmation, not optimistic UI alone.
    for (var turn = 0; turn < 50 && pending(); turn++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });
      await tester.pumpAndSettle();
    }
    expect(pending(), isFalse, reason: 'Mock HTTP response did not settle');
  }

  for (final fromPin in [false, true]) {
    testWidgets(
      'map ${fromPin ? 'pin' : 'area count'} likes only expanded photos and preserves camera',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'token': 'Bearer synthetic-map-session',
          'tokenExpiry': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'userRole': 'father',
        });
        await SharedPreferences.getInstance();
        LabMode.useFixturesForTests(true);
        final originalHttp = HttpOverrides.current;
        HttpOverrides.global = LabOfflineHttpOverrides();
        LabMapTiles.testProvider = TestMapTileProvider.new;
        final provider = _MapFixtures();
        final controller = TripMapController(
          tourCode: _tour,
          provider: provider,
        );
        final api = _LikesApi();
        final store = PhotoLikesStore(
          tourId: _tour,
          repository: HttpPhotoLikesRepository(clientFactory: api.client),
        );
        addTearDown(() {
          controller.dispose();
          provider.dispose();
          store.dispose();
          HttpOverrides.global = originalHttp;
          LabMapTiles.testProvider = null;
          LabMode.useFixturesForTests(false);
        });
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await controller.refresh();
        controller.clearSelection();
        await tester.pumpWidget(
          PhotoLikesScope(
            store: store,
            child: MaterialApp(
              theme: PiloFamilyTheme.theme(ThemeData()),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: TripMapView(
                  controller: controller,
                  expanded: true,
                  edgeToEdge: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final camera = tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!;
        camera.move(const LatLng(-33.45, -70.65), 16);
        await tester.pumpAndSettle();
        final beforeCenter = camera.camera.center;
        final beforeZoom = camera.camera.zoom;
        void expectCameraUnchanged() {
          expect(camera.camera.center, beforeCenter);
          expect(camera.camera.zoom, beforeZoom);
        }

        final open = fromPin
            ? find.byKey(const ValueKey('trip-pin-$_firstHito'))
            : find.byKey(const ValueKey('pilo-map-area-count'));
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(find.byType(PiloMapAreaCarousel), findsOneWidget);
        expect(controller.selectedId, _firstHito);
        expect(find.byType(PhotoLikeButton), findsNothing);
        expect(api.reads, 0);
        expectCameraUnchanged();

        final handle = find.byKey(const ValueKey('pilo-map-area-handle'));
        await tester.tap(handle);
        await tester.pumpAndSettle();
        await flushTransport(tester, () => store.loading);
        expect(find.byType(PiloMapExpandedCard), findsWidgets);
        Finder heart(int id) =>
            find.byKey(ValueKey('photo-like-$id')).hitTestable();
        expect(heart(_firstPhoto), findsOneWidget);
        expect(store.error, isNull);
        expect(
          store.loaded,
          isTrue,
          reason: 'loading=${store.loading}, reads=${api.reads}',
        );
        expect(store.canLike, isTrue);
        expect(api.reads, 1);
        await tester.tap(heart(_firstPhoto));
        await tester.pumpAndSettle();
        await flushTransport(tester, () => store.isBusy(_firstPhoto));
        expect(store.photo(_firstPhoto)!.likedByMe, isTrue);
        expect(api.photos[_firstPhoto]!.likeCount, 5);
        expect(store.totalForHito(_firstHito), 6);
        expectCameraUnchanged();

        final card = find.byKey(
          const ValueKey('pilo-map-area-hito-$_firstHito'),
        );
        final photoPages = find.descendant(
          of: card,
          matching: find.byKey(const ValueKey('pilo-map-expanded-photos')),
        );
        await tester.drag(photoPages, const Offset(-280, 0));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: card, matching: find.text('2/3')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.byType(PhotoLikeButton)),
          findsNothing,
        );
        expect(controller.selectedId, _firstHito);
        expectCameraUnchanged();

        await tester.drag(photoPages, const Offset(-280, 0));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: card, matching: find.text('3/3')),
          findsOneWidget,
        );
        expect(heart(_lastPhoto), findsOneWidget);
        await tester.tap(heart(_lastPhoto));
        await tester.pumpAndSettle();
        await flushTransport(tester, () => store.isBusy(_lastPhoto));
        expect(store.photo(_lastPhoto)!.likedByMe, isTrue);
        expect(store.totalForHito(_firstHito), 7);
        expect(api.writes.map((body) => body['photoId']), [
          _firstPhoto,
          _lastPhoto,
        ]);
        expectCameraUnchanged();

        await tester.tap(find.byKey(const ValueKey('pilo-map-area-next')));
        await tester.pumpAndSettle();
        expect(controller.selectedId, _secondHito);
        expect(controller.recenterOnSelection, isFalse);
        expect(heart(_secondHitoPhoto), findsOneWidget);
        await tester.tap(heart(_secondHitoPhoto));
        await tester.pumpAndSettle();
        await flushTransport(tester, () => store.isBusy(_secondHitoPhoto));
        expect(api.writes.last, {
          'tourId': _tour,
          'hitoId': _secondHito,
          'photoId': _secondHitoPhoto,
          'liked': true,
        });
        expect(store.totalForHito(_secondHito), 3);
        expectCameraUnchanged();

        await tester.tap(handle);
        await tester.pumpAndSettle();
        expect(find.byType(PhotoLikeButton), findsNothing);
        expect(find.byType(PiloMapExpandedCard), findsNothing);
        expect(api.reads, 1);
        expect(api.writes, hasLength(3));
        expectCameraUnchanged();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
