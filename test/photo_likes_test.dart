import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/likes/photo_likes_repository.dart';
import 'package:papigiras_app/likes/photo_likes_store.dart';
import 'package:papigiras_app/likes/photo_likes_widgets.dart';

const _tour = 910001;
const _hito = 910101;
const _otherHito = 910102;
const _photo = 910201;
const _otherPhoto = 910202;
const _image =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==';

PhotoLikeState _state({
  int id = _photo,
  int hito = _hito,
  int count = 2,
  bool liked = false,
}) => PhotoLikeState(
  photoId: id,
  hitoId: hito,
  likeCount: count,
  likedByMe: liked,
);

PhotoLikesSnapshot _snapshot({bool canLike = true}) => PhotoLikesSnapshot(
  canLike: canLike,
  photos: [
    _state(),
    _state(id: _otherPhoto, count: 3),
  ],
  hitoTotals: {_hito: 5, _otherHito: 0},
);

PhotoLikeResult _result({
  int id = _photo,
  int count = 3,
  bool liked = true,
  int total = 6,
}) => PhotoLikeResult(
  photo: _state(id: id, count: count, liked: liked),
  hitoLikeCount: total,
);

class _Write {
  _Write(this.tourId, this.hitoId, this.photoId, this.liked);
  final int tourId, hitoId, photoId;
  final bool liked;
}

class _Repository implements PhotoLikesRepository {
  final reads = <int>[];
  final writes = <_Write>[];
  Future<PhotoLikesSnapshot> Function(int)? onLoad;
  Future<PhotoLikeResult> Function(_Write)? onWrite;

  @override
  Future<PhotoLikesSnapshot> load(int tourId) {
    reads.add(tourId);
    return onLoad?.call(tourId) ?? Future.value(_snapshot());
  }

  @override
  Future<PhotoLikeResult> setLiked({
    required int tourId,
    required int hitoId,
    required int photoId,
    required bool liked,
  }) {
    final write = _Write(tourId, hitoId, photoId, liked);
    writes.add(write);
    return onWrite?.call(write) ?? Future.value(_result());
  }
}

Future<void> _turn() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late PhotoLikesStore store;
  int generation = 1;

  setUp(() {
    generation = 1;
    repository = _Repository();
    store = PhotoLikesStore(
      tourId: _tour,
      repository: repository,
      sessionGeneration: () => generation,
    );
  });

  tearDown(() => store.dispose());

  test(
    'invalid image in the middle drops its identity together with its bytes',
    () {
      final detail = DetailHitoList.fromJson({
        'images': [_image, 'invalid-image', _image],
        'imageIds': [_photo, 910299, _otherPhoto],
      });
      expect(detail.images, [_image, _image]);
      expect(detail.imageIds, [_photo, _otherPhoto]);
      expect(detail.photoIdAt(0), _photo);
      expect(detail.photoIdAt(1), _otherPhoto);
      expect(detail.photoIdAt(-1), isNull);
      expect(detail.photoIdAt(2), isNull);
      final restored = DetailHitoList.fromJson(detail.toJson());
      expect(restored.imageIds, detail.imageIds);
      expect(restored.images, detail.images);
    },
  );

  test(
    'legacy or invalid photo identities never invent an identity for a like',
    () {
      expect(
        DetailHitoList.fromJson({
          'images': [_image],
        }).imageIds,
        [null],
      );
      final detail = DetailHitoList.fromJson({
        'images': List.filled(5, _image),
        'imageIds': [0, -1, 910201.5, null],
      });
      expect(detail.images, hasLength(5));
      expect(detail.imageIds, List.filled(5, null));
      expect(DetailHitoList(images: [_image]).photoIdAt(0), isNull);
    },
  );

  test(
    'concurrent loads coalesce and preserve photo and hito totals',
    () async {
      final response = Completer<PhotoLikesSnapshot>();
      repository.onLoad = (_) => response.future;
      final reads = [store.load(), store.load(), store.load()];
      await _turn();
      expect(repository.reads, [_tour]);
      expect(store.loading, isTrue);
      expect(store.canLike, isFalse);
      response.complete(_snapshot());
      await Future.wait(reads);
      expect(store.loaded, isTrue);
      expect(store.loading, isFalse);
      expect(store.canLike, isTrue);
      expect(store.photo(_photo)?.likeCount, 2);
      expect(store.photo(_otherPhoto)?.likeCount, 3);
      expect(store.totalForHito(_hito), 5);
      expect(store.totalForHito(_otherHito), 0);
      expect(store.photo(919999), isNull);
      expect(store.totalForHito(919999), isNull);
      await store.load();
      expect(repository.reads, [_tour]);
    },
  );

  test(
    'load failure stays unknown and can be retried without fake zeros',
    () async {
      repository.onLoad = (_) =>
          Future.error(StateError('Synthetic read failure'));
      await store.load();
      expect(store.loaded, isFalse);
      expect(store.loading, isFalse);
      expect(store.canLike, isFalse);
      expect(store.photo(_photo), isNull);
      expect(store.totalForHito(_hito), isNull);
      expect(store.error, isNotNull);
      repository.onLoad = null;
      await store.load();
      expect(store.loaded, isTrue);
      expect(store.error, isNull);
      expect(repository.reads, [_tour, _tour]);
    },
  );

  test('server read-only permission keeps totals and blocks writes', () async {
    repository.onLoad = (_) async => _snapshot(canLike: false);
    await store.load();
    expect(store.totalForHito(_hito), 5);
    expect(store.canLike, isFalse);
    expect(await store.toggle(_photo, _hito), isFalse);
    expect(repository.writes, isEmpty);
    expect(store.photo(_photo)?.likedByMe, isFalse);
  });

  test('unknown photos and mismatched hitos never issue a write', () async {
    await store.load();
    expect(await store.toggle(919999, _hito), isFalse);
    expect(await store.toggle(_photo, _otherHito), isFalse);
    expect(repository.writes, isEmpty);
    expect(store.totalForHito(_hito), 5);
  });

  test(
    'like is optimistic and repeated taps cannot duplicate the request',
    () async {
      await store.load();
      final response = Completer<PhotoLikeResult>();
      repository.onWrite = (_) => response.future;
      final operation = store.toggle(_photo, _hito);
      await _turn();
      expect(store.photo(_photo)?.likedByMe, isTrue);
      expect(store.photo(_photo)?.likeCount, 3);
      expect(store.totalForHito(_hito), 6);
      expect(store.isBusy(_photo), isTrue);
      expect(store.isBusy(_otherPhoto), isFalse);
      final repeated = List.generate(8, (_) => store.toggle(_photo, _hito));
      await _turn();
      expect(repository.writes, hasLength(1));
      final sent = repository.writes.single;
      expect(
        (sent.tourId, sent.hitoId, sent.photoId, sent.liked),
        (_tour, _hito, _photo, true),
      );
      response.complete(_result(count: 8, total: 11));
      expect(await operation, isTrue);
      await Future.wait(repeated);
      expect(store.isBusy(_photo), isFalse);
      expect(store.photo(_photo)?.likeCount, 8);
      expect(store.totalForHito(_hito), 11);
    },
  );

  test('unlike sends desired false and subtracts once', () async {
    repository.onLoad = (_) async => PhotoLikesSnapshot(
      canLike: true,
      photos: [_state(count: 1, liked: true)],
      hitoTotals: {_hito: 1},
    );
    await store.load();
    final response = Completer<PhotoLikeResult>();
    repository.onWrite = (_) => response.future;
    final operation = store.toggle(_photo, _hito);
    await _turn();
    expect(store.photo(_photo)?.likedByMe, isFalse);
    expect(store.photo(_photo)?.likeCount, 0);
    expect(store.totalForHito(_hito), 0);
    expect(repository.writes.single.liked, isFalse);
    response.complete(_result(count: 0, total: 0, liked: false));
    expect(await operation, isTrue);
    expect(store.totalForHito(_hito), 0);
  });

  test(
    'failed like restores the photo and aggregate and permits retry',
    () async {
      await store.load();
      final response = Completer<PhotoLikeResult>();
      repository.onWrite = (_) => response.future;
      final operation = store.toggle(_photo, _hito);
      await _turn();
      expect(store.totalForHito(_hito), 6);
      response.completeError(StateError('Synthetic write failure'));
      expect(await operation, isFalse);
      expect(store.isBusy(_photo), isFalse);
      expect(store.photo(_photo)?.likeCount, 2);
      expect(store.photo(_photo)?.likedByMe, isFalse);
      expect(store.totalForHito(_hito), 5);
      expect(store.error, isNotNull);
      repository.onWrite = null;
      expect(await store.toggle(_photo, _hito), isTrue);
      expect(store.photo(_photo)?.likedByMe, isTrue);
    },
  );

  test(
    'mismatched acknowledgement cannot attach another photo reaction',
    () async {
      await store.load();
      repository.onWrite = (_) async => _result(id: _otherPhoto);
      expect(await store.toggle(_photo, _hito), isFalse);
      expect(store.photo(_photo)?.likedByMe, isFalse);
      expect(store.photo(_photo)?.likeCount, 2);
      expect(store.photo(_otherPhoto)?.likedByMe, isFalse);
      expect(store.totalForHito(_hito), 5);
      expect(store.error, isA<FormatException>());
    },
  );

  test(
    'duplicate photo identities in a refresh cannot replace valid prior state',
    () async {
      await store.load();
      repository.onLoad = (_) async => PhotoLikesSnapshot(
        canLike: true,
        photos: [
          _state(),
          _state(hito: _otherHito, count: 20),
        ],
        hitoTotals: {_hito: 2, _otherHito: 20},
      );
      await store.load(force: true);
      expect(store.photo(_photo)?.hitoId, _hito);
      expect(store.photo(_photo)?.likeCount, 2);
      expect(store.totalForHito(_hito), 5);
      expect(store.error, isA<FormatException>());
    },
  );

  test(
    'concurrent photos sum optimistically and serialize aggregate acknowledgements',
    () async {
      await store.load();
      final first = Completer<PhotoLikeResult>();
      final second = Completer<PhotoLikeResult>();
      repository.onWrite = (write) =>
          write.photoId == _photo ? first.future : second.future;
      final a = store.toggle(_photo, _hito);
      final b = store.toggle(_otherPhoto, _hito);
      await _turn();
      expect(store.photo(_photo)?.likeCount, 3);
      expect(store.photo(_otherPhoto)?.likeCount, 4);
      expect(store.totalForHito(_hito), 7);
      expect(repository.writes, hasLength(1));
      first.complete(_result(total: 6));
      expect(await a, isTrue);
      await _turn();
      expect(repository.writes, hasLength(2));
      expect(store.totalForHito(_hito), 7);
      second.complete(_result(id: _otherPhoto, count: 4, total: 7));
      expect(await b, isTrue);
      expect(store.totalForHito(_hito), 7);
      expect(store.isBusy(_photo), isFalse);
      expect(store.isBusy(_otherPhoto), isFalse);
    },
  );

  test(
    'failure of a queued photo does not undo another accepted like',
    () async {
      await store.load();
      final first = Completer<PhotoLikeResult>();
      final second = Completer<PhotoLikeResult>();
      repository.onWrite = (write) =>
          write.photoId == _photo ? first.future : second.future;
      final a = store.toggle(_photo, _hito);
      final b = store.toggle(_otherPhoto, _hito);
      await _turn();
      first.complete(_result());
      expect(await a, isTrue);
      await _turn();
      second.completeError(StateError('Synthetic second write failure'));
      expect(await b, isFalse);
      expect(store.photo(_photo)?.likedByMe, isTrue);
      expect(store.photo(_photo)?.likeCount, 3);
      expect(store.photo(_otherPhoto)?.likedByMe, isFalse);
      expect(store.photo(_otherPhoto)?.likeCount, 3);
      expect(store.totalForHito(_hito), 6);
    },
  );

  test('slow GET cannot overwrite a newer accepted like', () async {
    await store.load();
    final response = Completer<PhotoLikesSnapshot>();
    repository.onLoad = (_) => response.future;
    final refresh = store.load(force: true);
    await _turn();
    expect(await store.toggle(_photo, _hito), isTrue);
    response.complete(_snapshot());
    await refresh;
    expect(store.photo(_photo)?.likedByMe, isTrue);
    expect(store.photo(_photo)?.likeCount, 3);
    expect(store.totalForHito(_hito), 6);
  });

  test(
    'two tours keep independent state and route writes to their own tour',
    () async {
      final otherRepository = _Repository();
      final other = PhotoLikesStore(
        tourId: 910002,
        repository: otherRepository,
        sessionGeneration: () => generation,
      );
      addTearDown(other.dispose);
      await Future.wait([store.load(), other.load()]);
      expect(await other.toggle(_photo, _hito), isTrue);
      expect(otherRepository.writes.single.tourId, 910002);
      expect(repository.writes, isEmpty);
      expect(store.photo(_photo)?.likedByMe, isFalse);
      expect(store.totalForHito(_hito), 5);
      expect(other.totalForHito(_hito), 6);
    },
  );

  test(
    'session change discards an outstanding read and disables old store',
    () async {
      final response = Completer<PhotoLikesSnapshot>();
      repository.onLoad = (_) => response.future;
      final loading = store.load();
      await _turn();
      generation++;
      response.complete(_snapshot());
      await loading;
      expect(store.canLike, isFalse);
      expect(store.photo(_photo), isNull);
      expect(await store.toggle(_photo, _hito), isFalse);
      expect(repository.writes, isEmpty);
    },
  );

  test(
    'session change rejects old POST and queued writes without touching new login',
    () async {
      await store.load();
      final response = Completer<PhotoLikeResult>();
      repository.onWrite = (_) => response.future;
      final first = store.toggle(_photo, _hito);
      final queued = store.toggle(_otherPhoto, _hito);
      await _turn();
      expect(repository.writes, hasLength(1));
      generation++;
      final newRepository = _Repository();
      final newLogin = PhotoLikesStore(
        tourId: _tour,
        repository: newRepository,
        sessionGeneration: () => generation,
      );
      addTearDown(newLogin.dispose);
      await newLogin.load();
      response.complete(_result(count: 9, total: 12));
      expect(await first, isFalse);
      expect(await queued, isFalse);
      expect(repository.writes, hasLength(1));
      expect(store.canLike, isFalse);
      expect(newLogin.photo(_photo)?.likeCount, 2);
      expect(newLogin.photo(_photo)?.likedByMe, isFalse);
      expect(newLogin.totalForHito(_hito), 5);
    },
  );

  Future<void> showLikes(
    WidgetTester tester, {
    VoidCallback? onOpenPhoto,
    bool reducedMotion = false,
    double textScale = 1,
    double? likeWidth,
    int tourId = _tour,
    bool duplicatePhoto = false,
  }) async {
    // Construct the store's serialized Future chain inside the widget test's
    // fake async zone; the setUp instance belongs to normal service tests.
    store.dispose();
    store = PhotoLikesStore(
      tourId: _tour,
      repository: repository,
      sessionGeneration: () => generation,
    );
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      PhotoLikesScope(
        store: store,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reducedMotion,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Column(
              children: [
                GestureDetector(
                  onTap: onOpenPhoto,
                  child: Container(
                    key: const ValueKey('photo-parent'),
                    height: 180,
                    width: 240,
                    color: Colors.grey,
                    alignment: Alignment.topRight,
                    child: SizedBox(
                      width: likeWidth,
                      child: PhotoLikeButton(
                        tourId: tourId,
                        hitoId: _hito,
                        photoId: _photo,
                      ),
                    ),
                  ),
                ),
                if (duplicatePhoto)
                  PhotoLikeButton(
                    tourId: tourId,
                    hitoId: _hito,
                    photoId: _photo,
                  ),
                HitoLikeCount(tourId: tourId, hitoId: _hito),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder like() => find.byKey(const ValueKey('photo-like-$_photo'));
  Finder aggregate() => find.byKey(const ValueKey('hito-like-$_hito'));
  String label(WidgetTester tester, Finder target) =>
      tester.widget<Semantics>(target).properties.label!;

  testWidgets(
    'photo reaction does not open its parent and synchronizes other presentations',
    (tester) async {
      var opened = 0;
      await showLikes(
        tester,
        onOpenPhoto: () => opened++,
        duplicatePhoto: true,
      );
      expect(repository.reads, [_tour]);
      expect(like(), findsNWidgets(2));
      expect(
        label(tester, aggregate()),
        '5 me gusta en las fotos de este hito',
      );
      await tester.tap(like().first);
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(repository.writes, hasLength(1));
      expect(label(tester, like().first), contains('Quitar Me gusta'));
      expect(label(tester, like().last), contains('3 me gusta'));
      expect(
        label(tester, aggregate()),
        '6 me gusta en las fotos de este hito',
      );
      final parent = tester.getRect(find.byKey(const ValueKey('photo-parent')));
      await tester.tapAt(parent.bottomLeft + const Offset(20, -20));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'busy reaction still consumes rapid taps rather than opening the photo',
    (tester) async {
      var opened = 0;
      await showLikes(tester, onOpenPhoto: () => opened++);
      final response = Completer<PhotoLikeResult>();
      repository.onWrite = (_) => response.future;
      await tester.tap(like());
      await tester.pump();
      expect(store.isBusy(_photo), isTrue);
      await tester.tap(like());
      await tester.tap(like());
      expect(opened, 0);
      expect(repository.writes, hasLength(1));
      response.complete(_result());
      await tester.pumpAndSettle();
      expect(store.isBusy(_photo), isFalse);
    },
  );

  testWidgets(
    'readonly counts expose no reaction or aggregate action to accessibility',
    (tester) async {
      repository.onLoad = (_) async => _snapshot(canLike: false);
      await showLikes(tester);
      final photoSemantics = tester.widget<Semantics>(like()).properties;
      expect(photoSemantics.label, '2 me gusta en esta foto');
      expect(photoSemantics.button, isFalse);
      expect(photoSemantics.onTap, isNull);
      expect(photoSemantics.toggled, isNull);
      final totalSemantics = tester.widget<Semantics>(aggregate()).properties;
      expect(totalSemantics.label, '5 me gusta en las fotos de este hito');
      expect(totalSemantics.onTap, isNull);
      await tester.tap(like());
      await tester.tap(aggregate());
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'legacy capability exposes a renewal action instead of a dead heart',
    (tester) async {
      repository.onLoad = (_) async => PhotoLikesSnapshot(
        canLike: false,
        requiresReauthentication: true,
        photos: [_state()],
        hitoTotals: {_hito: 2},
      );
      await showLikes(tester);
      final properties = tester.widget<Semantics>(like()).properties;
      expect(properties.button, isTrue);
      expect(properties.onTap, isNotNull);
      expect(properties.label, contains('Activa tus Me gusta'));
      expect(store.canLike, isFalse);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'reaction has a touch target and accessible toggle with reduced motion',
    (tester) async {
      await showLikes(tester, reducedMotion: true, textScale: 2);
      expect(tester.getSize(like()).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(like()).width, greaterThanOrEqualTo(44));
      var properties = tester.widget<Semantics>(like()).properties;
      expect(properties.button, isTrue);
      expect(properties.toggled, isFalse);
      expect(properties.onTap, isNotNull);
      properties.onTap!();
      await tester.pumpAndSettle();
      properties = tester.widget<Semantics>(like()).properties;
      expect(properties.toggled, isTrue);
      expect(properties.label, contains('Quitar Me gusta'));
      final animation = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animation.duration, Duration.zero);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'widget read failure shows retry instead of invented zero likes',
    (tester) async {
      repository.onLoad = (_) =>
          Future.error(StateError('Synthetic load error'));
      await showLikes(tester);
      expect(label(tester, like()), 'Reintentar likes de esta foto');
      expect(find.text('0'), findsNothing);
      repository.onLoad = null;
      await tester.tap(like());
      await tester.pumpAndSettle();
      expect(label(tester, like()), contains('2 me gusta'));
      expect(repository.reads, [_tour, _tour]);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'three digit photo count fits a narrow thumbnail with large text',
    (tester) async {
      repository.onLoad = (_) async => PhotoLikesSnapshot(
        canLike: true,
        photos: [_state(count: 100)],
        hitoTotals: {_hito: 100},
      );
      await showLikes(tester, textScale: 2, likeWidth: 78);
      expect(label(tester, like()), contains('100 me gusta'));
      expect(tester.getSize(like()).width, 78);
      expect(tester.getSize(like()).height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'widget failed write restores counters and explains the failure',
    (tester) async {
      await showLikes(tester);
      repository.onWrite = (_) =>
          Future.error(StateError('Synthetic write error'));
      await tester.tap(like());
      await tester.pumpAndSettle();
      expect(label(tester, like()), contains('2 me gusta'));
      expect(
        label(tester, aggregate()),
        '5 me gusta en las fotos de este hito',
      );
      expect(
        find.text('No se pudo guardar tu Me gusta. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(store.isBusy(_photo), isFalse);
    },
  );

  testWidgets(
    'injected store from another tour cannot leak a photo or its count',
    (tester) async {
      await showLikes(tester, tourId: 910002);
      expect(like(), findsNothing);
      expect(aggregate(), findsNothing);
      expect(repository.reads, isEmpty);
      expect(repository.writes, isEmpty);
    },
  );

  group('isolated HTTP contract', () {
    const token = 'synthetic-photo-likes-test-token';
    late SharedPreferences prefs;
    final sent = <http.Request>[];
    final snapshotJson = <String, Object>{
      'canLike': true,
      'photos': [
        {
          'photoId': _photo,
          'hitoId': _hito,
          'likeCount': 2,
          'likedByMe': false,
        },
      ],
      'hitos': [
        {'hitoId': _hito, 'totalLikes': 2},
      ],
    };
    final resultJson = <String, Object>{
      'photoId': _photo,
      'hitoId': _hito,
      'likeCount': 3,
      'likedByMe': true,
      'hitoLikeCount': 3,
    };

    HttpPhotoLikesRepository httpRepository(
      Future<http.Response> Function(http.Request) respond,
    ) => HttpPhotoLikesRepository(
      clientFactory: () => LabApiClient(
        transport: MockClient((request) {
          sent.add(request);
          return respond(request);
        }),
      ),
    );

    setUp(() async {
      sent.clear();
      SharedPreferences.setMockInitialValues({
        'token': token,
        'tokenExpiry': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'isLoggedIn': true,
        'userRole': 'father',
        'labSessionRevision': LabSession.revision,
      });
      prefs = await SharedPreferences.getInstance();
    });

    test(
      'GET reads one tour with authorization, no user identity query or body',
      () async {
        final repo = httpRepository(
          (_) async => http.Response(jsonEncode(snapshotJson), 200),
        );
        final snapshot = await repo.load(_tour);
        expect(snapshot.canLike, isTrue);
        expect(snapshot.photos.single.photoId, _photo);
        expect(snapshot.photos.single.likeCount, 2);
        expect(snapshot.hitoTotals, {_hito: 2});
        final request = sent.single;
        expect(request.method, 'GET');
        expect(request.url.host, '127.0.0.1');
        expect(request.url.port, 8084);
        expect(request.url.path, '/app/services/photo-likes');
        expect(request.url.queryParameters, {'tourId': '$_tour'});
        expect(request.body, isEmpty);
        expect(request.headers['authorization'], token);
        expect(request.followRedirects, isFalse);
      },
    );

    test(
      'legacy attorney session requests renewal without granting likes',
      () async {
        final repo = httpRepository(
          (_) async => http.Response(
            jsonEncode({...snapshotJson, 'canLike': false}),
            200,
          ),
        );
        final result = await repo.load(_tour);
        expect(result.canLike, isFalse);
        expect(result.requiresReauthentication, isTrue);
        final legacy = PhotoLikesStore(tourId: _tour, repository: repo);
        await legacy.load();
        expect(legacy.requiresReauthentication, isTrue);
        expect(await legacy.toggle(_photo, _hito), isFalse);
        expect(sent.every((r) => r.method == 'GET'), isTrue);
        legacy.dispose();
      },
    );

    test(
      'coordinator and student readonly sessions never request attorney renewal',
      () async {
        for (final role in ['coordinator', 'passenger']) {
          await prefs.setString('userRole', role);
          final repo = httpRepository(
            (_) async => http.Response(
              jsonEncode({...snapshotJson, 'canLike': false}),
              200,
            ),
          );
          final result = await repo.load(_tour);
          expect(result.canLike, isFalse);
          expect(result.requiresReauthentication, isFalse);
        }
      },
    );

    test(
      'POST carries desired state and only three resource identifiers',
      () async {
        final repo = httpRepository(
          (_) async => http.Response(jsonEncode(resultJson), 200),
        );
        final result = await repo.setLiked(
          tourId: _tour,
          hitoId: _hito,
          photoId: _photo,
          liked: true,
        );
        expect(result.photo.likedByMe, isTrue);
        expect(result.photo.likeCount, 3);
        expect(result.hitoLikeCount, 3);
        final request = sent.single;
        expect(request.method, 'POST');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['authorization'], token);
        expect(jsonDecode(request.body), {
          'tourId': _tour,
          'hitoId': _hito,
          'photoId': _photo,
          'liked': true,
        });
        expect(request.url.toString(), isNot(contains(token)));
        expect(request.body, isNot(contains(token)));
      },
    );

    for (final invalid in ['missing token', 'expired token']) {
      test('$invalid is rejected without creating a transport', () async {
        if (invalid == 'missing token') {
          await prefs.remove('token');
        } else {
          await prefs.setString(
            'tokenExpiry',
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          );
        }
        var clients = 0;
        final repo = HttpPhotoLikesRepository(
          clientFactory: () {
            clients++;
            return LabApiClient(
              transport: MockClient((_) async => http.Response('{}', 200)),
            );
          },
        );
        await expectLater(
          repo.load(_tour),
          throwsA(
            isA<LabApiException>().having(
              (error) => error.statusCode,
              'status',
              401,
            ),
          ),
        );
        expect(clients, 0);
      });
    }

    test(
      'authenticated 403 is a permission failure without discarding login',
      () async {
        final repo = httpRepository((_) async => http.Response('', 403));
        final before = LabSession.generation;
        await expectLater(
          repo.setLiked(
            tourId: _tour,
            hitoId: _hito,
            photoId: _photo,
            liked: true,
          ),
          throwsA(
            isA<LabApiException>().having(
              (error) => error.statusCode,
              'status',
              403,
            ),
          ),
        );
        expect(sent, hasLength(1));
        expect(prefs.getString('token'), token);
        expect(LabSession.generation, before);
      },
    );

    test(
      '401 revokes only the captured session and never retries anonymously',
      () async {
        final repo = httpRepository((_) async => http.Response('', 401));
        final before = LabSession.generation;
        await expectLater(repo.load(_tour), throwsA(isA<LabApiException>()));
        expect(sent, hasLength(1));
        expect(prefs.getString('token'), isNull);
        expect(LabSession.generation, before + 1);
      },
    );

    test(
      'response from previous generation is rejected even if login reuses token',
      () async {
        final response = Completer<http.Response>();
        final requested = Completer<void>();
        final repo = httpRepository((_) {
          requested.complete();
          return response.future;
        });
        final loading = expectLater(
          repo.load(_tour),
          throwsA(isA<LabApiException>()),
        );
        await requested.future;
        await LabSession.clear(prefs);
        await prefs.setString('token', token);
        await prefs.setString(
          'tokenExpiry',
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        );
        response.complete(http.Response(jsonEncode(snapshotJson), 200));
        await loading;
        expect(prefs.getString('token'), token);
        expect(sent, hasLength(1));
      },
    );

    test(
      'malformed aggregate contract is a visible error, not fabricated empty counts',
      () async {
        for (final malformed in <Object>[
          [],
          {'canLike': true, 'photos': []},
          {'canLike': 'true', 'photos': [], 'hitos': []},
          {
            'canLike': true,
            'photos': [
              {
                'photoId': -1,
                'hitoId': _hito,
                'likeCount': 2,
                'likedByMe': false,
              },
            ],
            'hitos': [],
          },
          {
            'canLike': true,
            'photos': [],
            'hitos': [
              {'hitoId': _hito, 'totalLikes': -1},
            ],
          },
        ]) {
          final repo = httpRepository(
            (_) async => http.Response(jsonEncode(malformed), 200),
          );
          await expectLater(repo.load(_tour), throwsFormatException);
        }
      },
    );
  });
}
