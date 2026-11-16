import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/ranking/coordinator_ranking_repository.dart';

const fixtureCoordinator = 910001;
Map<String, dynamic> entry(int id, int rank) => {
  'rank': rank,
  'coordinatorId': id,
  'firstName': 'Persona',
  'lastName': 'Demo',
  'photoAvailable': true,
  'bestTourId': 910001,
  'hitoCount': 3,
  'photoCount': 12,
  'likeCount': 4,
  'score': 50,
};
Map<String, dynamic> page({
  int season = 2025,
  int offset = 0,
  int limit = 50,
  int total = 1,
  bool hasMore = false,
  List<Map<String, dynamic>>? entries,
  Map<String, dynamic>? mine,
}) => {
  'season': season,
  'availableSeasons': [2025, 2026],
  'generatedAt': '2026-11-15T12:00:00Z',
  'rule': {'version': '1', 'hitoPoints': 10, 'photoPoints': 1, 'likePoints': 2},
  'totalParticipants': total,
  'currentCoordinatorId': fixtureCoordinator,
  'myEntry': mine,
  'entries': entries ?? [entry(fixtureCoordinator, 1)],
  'limit': limit,
  'offset': offset,
  'hasMore': hasMore,
  'unattributedHitoCount': 0,
};

Future<SharedPreferences> seed() async {
  SharedPreferences.setMockInitialValues({
    'token': 'synthetic-coordinator-session',
    'tokenExpiry': DateTime.now()
        .add(const Duration(hours: 1))
        .toIso8601String(),
    'coordinatorData': jsonEncode({'coordinatorId': fixtureCoordinator}),
    'isLoggedIn': true,
    'userRole': 'coordinator',
    'labSessionRevision': LabSession.revision,
  });
  return SharedPreferences.getInstance();
}

HttpCoordinatorRankingRepository repository(
  Future<http.Response> Function(http.Request) handler,
) => HttpCoordinatorRankingRepository(
  clientFactory: () => LabApiClient(transport: MockClient(handler)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(seed);

  test(
    'local GET parses rule, best trip, own entry and exact server counts',
    () async {
      final repo = repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.origin, 'http://127.0.0.1:8084');
        expect(request.url.path, '/app/services/coordinator/ranking');
        expect(request.url.queryParameters, {
          'season': '2025',
          'limit': '50',
          'offset': '0',
        });
        expect(
          request.headers['authorization'],
          'synthetic-coordinator-session',
        );
        expect(request.body, isEmpty);
        return http.Response(
          jsonEncode(page(mine: entry(fixtureCoordinator, 1))),
          200,
        );
      });
      final result = await repo.load(season: 2025);
      expect(result.rule.hitoPoints, 10);
      expect(result.rule.photoPoints, 1);
      expect(result.rule.likePoints, 2);
      expect(result.myEntry!.coordinatorId, fixtureCoordinator);
      expect(result.entries.single.displayName, 'Persona Demo');
      expect(result.entries.single.bestTourId, 910001);
      expect(result.entries.single.score, 50);
      expect(result.nextOffset, 1);
      expect(result.availableSeasons, [2025, 2026]);
    },
  );

  test('historical coverage is explicit and survives pagination', () {
    final first = CoordinatorRankingPage.fromJson(
      page(total: 2, hasMore: true)..['unattributedHitoCount'] = 2035,
    );
    final second = CoordinatorRankingPage.fromJson(
      page(total: 2, offset: 1, entries: [entry(910002, 2)])
        ..['unattributedHitoCount'] = 2035,
    );
    expect(first.unattributedHitoCount, 2035);
    expect(first.mergeNext(second).unattributedHitoCount, 2035);
    // Coverage is not a ranking participant or a contribution by any author.
    expect(first.totalParticipants, 2);
    expect(first.entries.single.hitoCount, 3);
    expect(first.entries.single.score, 50);
  });

  test(
    'empty season and coordinator without activity remain explicit',
    () async {
      final repo = repository(
        (_) async =>
            http.Response(jsonEncode(page(total: 0, entries: [])), 200),
      );
      final result = await repo.load(season: 2025);
      expect(result.entries, isEmpty);
      expect(result.myEntry, isNull);
      expect(result.totalParticipants, 0);
      expect(result.hasMore, isFalse);
    },
  );

  test('stable pages preserve server positions and raw cursor', () {
    final first = CoordinatorRankingPage.fromJson(
      page(
        limit: 2,
        total: 5,
        hasMore: true,
        entries: [entry(910001, 1), entry(910002, 2)],
      ),
    );
    final second = CoordinatorRankingPage.fromJson(
      page(
        limit: 2,
        offset: 2,
        total: 5,
        hasMore: true,
        entries: [entry(910003, 3), entry(910004, 4)],
      ),
    );
    final combined = first.mergeNext(second);
    expect(combined.entries.map((e) => e.coordinatorId), [
      910001,
      910002,
      910003,
      910004,
    ]);
    expect(combined.nextOffset, 4);
    final last = combined.mergeNext(
      CoordinatorRankingPage.fromJson(
        page(limit: 2, offset: 4, total: 5, entries: [entry(910005, 5)]),
      ),
    );
    expect(last.entries.map((e) => e.rank), [1, 2, 3, 4, 5]);
    expect(last.hasMore, isFalse);
    expect(() => combined.mergeNext(second), throwsFormatException);
  });

  test(
    'changed order between pages requests reload, never duplicates people',
    () {
      final first = CoordinatorRankingPage.fromJson(
        page(
          limit: 2,
          total: 4,
          hasMore: true,
          entries: [entry(910001, 1), entry(910002, 2)],
        ),
      );
      // A new contribution moves the former second coordinator to third place.
      final next = CoordinatorRankingPage.fromJson(
        page(
          limit: 2,
          offset: 2,
          total: 4,
          entries: [entry(910002, 3), entry(910004, 4)],
        ),
      );
      expect(
        () => first.mergeNext(next),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Recarga'),
          ),
        ),
      );
      expect(first.entries.map((e) => e.rank), [1, 2]);
    },
  );

  test('changed own standing or participant total requests reload', () {
    final first = CoordinatorRankingPage.fromJson(
      page(total: 2, hasMore: true, mine: entry(910001, 1)),
    );
    final changes = [
      {'totalParticipants': 3},
      {
        'myEntry': {...entry(910001, 1), 'score': 52, 'likeCount': 5},
      },
      {'myEntry': null},
    ];
    for (final change in changes) {
      final next = CoordinatorRankingPage.fromJson(
        page(
          total: 2,
          offset: 1,
          mine: entry(910001, 1),
          entries: [entry(910002, 2)],
        )..addAll(change),
      );
      expect(() => first.mergeNext(next), throwsFormatException);
    }
  });

  test('never merges different season, identity, rule or initial page', () {
    final first = CoordinatorRankingPage.fromJson(
      page(hasMore: true, total: 2),
    );
    for (final change in [
      {'season': 2026},
      {'currentCoordinatorId': 910002},
      {
        'rule': {
          'version': '2',
          'hitoPoints': 20,
          'photoPoints': 1,
          'likePoints': 2,
        },
      },
      {'offset': 0},
    ]) {
      final json = page(offset: 1, total: 2, entries: [entry(910002, 2)])
        ..addAll(change);
      expect(
        () => first.mergeNext(CoordinatorRankingPage.fromJson(json)),
        throwsFormatException,
      );
    }
  });

  test('invalid payload never fabricates zeros or participant identities', () {
    for (final change in [
      {
        'entries': [entry(0, 1)],
      },
      {
        'entries': [
          {...entry(910001, 1), 'score': null},
        ],
      },
      {
        'entries': [
          {...entry(910001, 1), 'likeCount': -1},
        ],
      },
      {
        'entries': [entry(910001, 1), entry(910001, 2)],
        'totalParticipants': 2,
      },
      {'entries': [], 'hasMore': true},
      {'myEntry': entry(910002, 1)},
      {'generatedAt': 'not-a-date'},
      {'unattributedHitoCount': null},
      {'unattributedHitoCount': -1},
      {
        'entries': [entry(910001, 2)],
      },
      {
        'entries': [entry(910001, 1), entry(910002, 1)],
        'totalParticipants': 2,
      },
    ]) {
      expect(
        () => CoordinatorRankingPage.fromJson(page()..addAll(change)),
        throwsFormatException,
      );
    }
  });

  test('rejects wrong season/current account/offset from endpoint', () async {
    for (final change in [
      {'season': 2026},
      {'currentCoordinatorId': 910002},
      {'offset': 50},
      {'limit': 10},
    ]) {
      final repo = repository(
        (_) async => http.Response(jsonEncode(page()..addAll(change)), 200),
      );
      await expectLater(repo.load(season: 2025), throwsFormatException);
    }
  });

  test('invalid local pagination never sends a request', () async {
    var requests = 0;
    final repo = repository((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    await expectLater(repo.load(season: 0), throwsArgumentError);
    await expectLater(repo.load(season: 2025, limit: 101), throwsArgumentError);
    await expectLater(repo.load(season: 2025, offset: -1), throwsArgumentError);
    expect(requests, 0);
  });

  test('attorney role and expired coordinator cannot read ranking', () async {
    var requests = 0;
    final repo = repository((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', 'father');
    await expectLater(repo.load(season: 2025), throwsA(isA<LabApiException>()));
    await prefs.setString('userRole', 'coordinator');
    await prefs.setString(
      'tokenExpiry',
      DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String(),
    );
    await expectLater(repo.load(season: 2025), throwsA(isA<LabApiException>()));
    expect(requests, 0);
  });

  test('rejects response after token changes in the same generation', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final repo = repository((_) {
      started.complete();
      return response.future;
    });
    final pending = repo.load(season: 2025);
    final assertion = expectLater(pending, throwsA(isA<LabApiException>()));
    await started.future;
    final prefs = await SharedPreferences.getInstance();
    final generation = LabSession.generation;
    await prefs.setString('token', 'synthetic-other-session');
    expect(LabSession.generation, generation);
    response.complete(http.Response(jsonEncode(page()), 200));
    await assertion;
  });

  test(
    'rejects response after sign-out even with identical new credential',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final repo = repository((_) {
        started.complete();
        return response.future;
      });
      final pending = repo.load(season: 2025);
      final assertion = expectLater(pending, throwsA(isA<LabApiException>()));
      await started.future;
      await LabSession.clear(await SharedPreferences.getInstance());
      await seed();
      response.complete(http.Response(jsonEncode(page()), 200));
      await assertion;
    },
  );

  test(
    'photo cache separates seasons, deduplicates requests and allows refresh',
    () async {
      var requests = 0;
      final repo = repository((request) async {
        requests++;
        expect(
          request.url.path,
          '/app/services/coordinator/ranking/910002/picture',
        );
        expect(
          request.headers['authorization'],
          'synthetic-coordinator-session',
        );
        expect(request.url.queryParameters.containsKey('season'), isTrue);
        return http.Response.bytes(
          [255, 216, 255, 217],
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });
      final results = await Future.wait([
        repo.loadPicture(season: 2025, coordinatorId: 910002),
        repo.loadPicture(season: 2025, coordinatorId: 910002),
      ]);
      expect(requests, 1);
      expect(results.first, [255, 216, 255, 217]);
      await repo.loadPicture(season: 2025, coordinatorId: 910002);
      expect(requests, 1);
      await repo.loadPicture(season: 2026, coordinatorId: 910002);
      expect(requests, 2);
      await repo.loadPicture(
        season: 2025,
        coordinatorId: 910002,
        refresh: true,
      );
      expect(requests, 3);
    },
  );

  test(
    '204 photo absence is cached without substituting another portrait',
    () async {
      var requests = 0;
      final repo = repository((_) async {
        requests++;
        return http.Response('', 204);
      });
      expect(
        await repo.loadPicture(season: 2025, coordinatorId: 910002),
        isNull,
      );
      expect(
        await repo.loadPicture(season: 2025, coordinatorId: 910002),
        isNull,
      );
      expect(requests, 1);
    },
  );

  test('cached photos are not returned after token replacement', () async {
    var requests = 0;
    final repo = repository((_) async {
      requests++;
      return http.Response('', 204);
    });
    await repo.loadPicture(season: 2025, coordinatorId: 910002);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', 'synthetic-new-session');
    await expectLater(
      repo.loadPicture(season: 2025, coordinatorId: 910002),
      throwsA(isA<LabApiException>()),
    );
    expect(requests, 1);
  });

  test('in-flight photos cannot leak across logout/session change', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final repo = repository((_) {
      started.complete();
      return response.future;
    });
    final pending = repo.loadPicture(season: 2025, coordinatorId: 910002);
    final assertion = expectLater(pending, throwsA(isA<LabApiException>()));
    await started.future;
    await LabSession.clear(await SharedPreferences.getInstance());
    response.complete(
      http.Response.bytes(
        [255, 216, 255],
        200,
        headers: {'content-type': 'image/jpeg'},
      ),
    );
    await assertion;
  });

  test(
    'malformed or failed photos are retryable and never cached as images',
    () async {
      var requests = 0;
      final repo = repository((_) async {
        requests++;
        if (requests == 1)
          return http.Response(
            '<html>wrong</html>',
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        if (requests == 2) return http.Response('unavailable', 500);
        return http.Response('', 204);
      });
      await expectLater(
        repo.loadPicture(season: 2025, coordinatorId: 910002),
        throwsFormatException,
      );
      await expectLater(
        repo.loadPicture(season: 2025, coordinatorId: 910002),
        throwsA(isA<LabApiException>()),
      );
      expect(
        await repo.loadPicture(season: 2025, coordinatorId: 910002),
        isNull,
      );
      expect(requests, 3);
    },
  );

  test(
    '403 remains identifiable without changing role or signing out',
    () async {
      final repo = repository((_) async => http.Response('', 403));
      await expectLater(
        repo.load(season: 2025),
        throwsA(
          isA<LabApiException>().having(
            (e) => e.statusCode,
            'permission status',
            403,
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('userRole'), 'coordinator');
      expect(prefs.getBool('isLoggedIn'), isTrue);
      expect(prefs.getString('token'), 'synthetic-coordinator-session');
    },
  );

  test(
    'ranking server errors remain errors, not a misleading empty ranking',
    () async {
      final repo = repository((_) async => http.Response('unavailable', 503));
      await expectLater(
        repo.load(season: 2025),
        throwsA(isA<LabApiException>()),
      );
    },
  );
}
