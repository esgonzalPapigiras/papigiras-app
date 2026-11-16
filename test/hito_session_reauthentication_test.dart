import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
// Test-only in-memory store shipped by the existing shared_preferences plugin.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class _DelayedTokenRemoval extends InMemorySharedPreferencesStore {
  _DelayedTokenRemoval() : super.empty();
  final removed = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> remove(String key) async {
    final result = await super.remove(key);
    if (key == 'flutter.token' && !removed.isCompleted) {
      removed.complete();
      await release.future;
    }
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tour = TourSales.fromCoordinatorTour(
    coordinator: LabFixtures.coordinator,
    tour: LabFixtures.tour,
  );
  Map<String, Object> login({int id = 1, bool mustChange = false}) => {
    ...LabFixtures.coordinator.toJson(),
    'coordinatorId': id,
    'token': 'synthetic-renewed',
    'mustChangePassword': mustChange,
  };
  final assigned = {'tourId': tour.tourSalesId, 'assignmentId': 1};
  Future<SharedPreferences> seed() async {
    SharedPreferences.setMockInitialValues({
      'token': 'synthetic-old',
      'tokenExpiry': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'coordinatorData': jsonEncode(LabFixtures.coordinator.toJson()),
      'userRole': 'coordinator',
      'labSessionRevision': LabSession.revision,
      'isLoggedIn': true,
      'selectedTourId': tour.tourSalesId,
    });
    return SharedPreferences.getInstance();
  }

  Future<void> renew(CoordinatorProviders provider) =>
      provider.reauthenticateHitoDraft(
        rut: '11111111-1',
        password: 'synthetic-password',
        expectedTour: tour,
      );
  CoordinatorProviders provider(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final value = CoordinatorProviders(
      client: LabApiClient(
        notifyOnUnauthorized: false,
        transport: MockClient(handler),
      ),
    );
    addTearDown(value.dispose);
    return value;
  }

  setUp(() async {
    LabMode.useFixturesForTests(false);
    await seed();
  });

  test(
    'preflight rejects missing, expired, wrong-role and wrong-owner sessions',
    () async {
      final prefs = await SharedPreferences.getInstance();
      expect(await LabSession.hasActiveCoordinator(tour.coordinatorId), isTrue);
      expect(await LabSession.hasActiveCoordinator(999), isFalse);
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String(),
      );
      expect(
        await LabSession.hasActiveCoordinator(tour.coordinatorId),
        isFalse,
      );
      await seed();
      await (await SharedPreferences.getInstance()).remove('token');
      expect(
        await LabSession.hasActiveCoordinator(tour.coordinatorId),
        isFalse,
      );
      await seed();
      final fresh = await SharedPreferences.getInstance();
      await fresh.setString('userRole', 'coordinator');
      await fresh.setString('labSessionRevision', 'old-revision');
      expect(
        await LabSession.hasActiveCoordinator(tour.coordinatorId),
        isFalse,
      );
      await fresh.setString('labSessionRevision', LabSession.revision);
      await fresh.setString('userRole', 'father');
      expect(
        await LabSession.hasActiveCoordinator(tour.coordinatorId),
        isFalse,
      );
    },
  );

  test(
    'renewal verifies candidate assignment before installing same owner for only12hours',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final startGeneration = LabSession.generation;
      final expiryEvents = LabSession.expired.value;
      final calls = <String>[];
      final value = provider((request) async {
        calls.add(request.url.path);
        expect(prefs.getString('token'), 'synthetic-old');
        if (request.method == 'POST') {
          expect(request.url.path, '/app/services/lab/mobile/login');
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'role': 'coordinator',
            'rut': '11111111-1',
            'password': 'synthetic-password',
          });
          return http.Response(jsonEncode(login()), 200);
        }
        expect(request.headers['Authorization'], 'synthetic-renewed');
        expect(
          request.url.path,
          '/app/services/coordinator/tours/${tour.tourSalesId}',
        );
        return http.Response(jsonEncode(assigned), 200);
      });
      await renew(value);
      expect(calls, hasLength(2));
      expect(prefs.getString('token'), 'synthetic-renewed');
      final remaining = DateTime.parse(
        prefs.getString('tokenExpiry')!,
      ).difference(DateTime.now());
      expect(remaining, lessThanOrEqualTo(const Duration(hours: 12)));
      expect(remaining, greaterThan(const Duration(hours: 11, minutes: 59)));
      expect(LabSession.generation, greaterThan(startGeneration));
      expect(LabSession.expired.value, expiryEvents);
      expect(prefs.getInt('selectedTourId'), tour.tourSalesId);
      expect(
        jsonDecode(prefs.getString('loginData')!)['coordinatorId'],
        tour.coordinatorId,
      );
      expect(prefs.getString('userPassword'), isNull);
    },
  );

  test(
    'another account or mandatory-password-change cannot replace draft identity',
    () async {
      for (final result in [login(id: 999), login(mustChange: true)]) {
        var calls = 0;
        final value = provider((request) async {
          calls++;
          return http.Response(jsonEncode(result), 200);
        });
        await expectLater(
          renew(value),
          throwsA(isA<CoordinatorReauthenticationException>()),
        );
        expect(calls, 1);
        expect(
          (await SharedPreferences.getInstance()).getString('token'),
          'synthetic-old',
        );
      }
    },
  );

  test(
    'wrong password and revoked assignment retain existing credentials and no mutation',
    () async {
      for (final status in [401, 403]) {
        final expiryEvents = LabSession.expired.value;
        final value = provider((request) async {
          if (request.method == 'POST')
            return status == 401
                ? http.Response('', 401)
                : http.Response(jsonEncode(login()), 200);
          return http.Response('', 403);
        });
        await expectLater(renew(value), throwsException);
        expect(
          (await SharedPreferences.getInstance()).getString('token'),
          'synthetic-old',
        );
        expect(LabSession.expired.value, expiryEvents);
      }
    },
  );

  test('logout during candidate validation prevents stale renewal', () async {
    final pending = Completer<http.Response>(), reached = Completer<void>();
    final value = provider((request) async {
      if (request.method == 'POST')
        return http.Response(jsonEncode(login()), 200);
      reached.complete();
      return pending.future;
    });
    final operation = renew(value);
    final failure = expectLater(operation, throwsA(isA<FormatException>()));
    await reached.future;
    await LabSession.clear(await SharedPreferences.getInstance());
    pending.complete(http.Response(jsonEncode(assigned), 200));
    await failure;
    expect((await SharedPreferences.getInstance()).getString('token'), isNull);
  });

  test(
    'draft401 still revokes tokens and generation; only navigation notification differs',
    () async {
      for (final notify in [false, true]) {
        final prefs = await seed();
        final generation = LabSession.generation,
            events = LabSession.expired.value;
        final client = LabApiClient(
          notifyOnUnauthorized: notify,
          transport: MockClient((_) async => http.Response('', 401)),
        );
        await expectLater(
          client.get(
            LabApi.uri('/app/services/create-hito'),
            headers: {'Authorization': 'synthetic-old'},
          ),
          throwsA(isA<LabApiException>()),
        );
        expect(prefs.getString('token'), isNull);
        expect(prefs.getBool('isLoggedIn'), isFalse);
        expect(LabSession.generation, greaterThan(generation));
        expect(LabSession.expired.value, events + (notify ? 1 : 0));
        client.close();
      }
    },
  );

  test(
    '403 does not invalidate a valid session or trigger navigation',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final generation = LabSession.generation,
          events = LabSession.expired.value;
      final client = LabApiClient(
        transport: MockClient((_) async => http.Response('', 403)),
      );
      addTearDown(client.close);
      await expectLater(
        client.post(
          LabApi.uri('/app/services/create-hito'),
          headers: {'Authorization': 'synthetic-old'},
        ),
        throwsA(isA<LabApiException>()),
      );
      expect(prefs.getString('token'), 'synthetic-old');
      expect(LabSession.generation, generation);
      expect(LabSession.expired.value, events);
    },
  );
  test(
    'expired loader cannot erase the expiry installed during renewal',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String(),
      );
      final originalStore = SharedPreferencesStorePlatform.instance;
      final delayed = _DelayedTokenRemoval();
      SharedPreferencesStorePlatform.instance = delayed;
      addTearDown(
        () => SharedPreferencesStorePlatform.instance = originalStore,
      );
      final value = provider((_) async => http.Response('', 500));
      await delayed.removed.future;
      final generation = LabSession.generation;
      await LabSession.renewCoordinator(
        login: CoordinatorLogin.fromJson(login()),
        expectedTour: tour,
        expectedGeneration: generation,
      );
      final renewedExpiry = prefs.getString('tokenExpiry');
      delayed.release.complete();
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('token'), 'synthetic-renewed');
      expect(prefs.getString('tokenExpiry'), renewedExpiry);
      expect(await value.hasHitoSession(tour.coordinatorId), isTrue);
    },
  );
  test(
    'candidate response for another tour or missing assignment cannot renew',
    () async {
      for (final candidate in [
        {'tourId': 999, 'assignmentId': 1},
        {'tourId': tour.tourSalesId, 'assignmentId': 0},
      ]) {
        final value = provider(
          (request) async => http.Response(
            jsonEncode(request.method == 'POST' ? login() : candidate),
            200,
          ),
        );
        await expectLater(renew(value), throwsA(isA<FormatException>()));
        expect(
          (await SharedPreferences.getInstance()).getString('token'),
          'synthetic-old',
        );
      }
    },
  );

  test(
    'late401 from a prior generation cannot revoke renewed even identical token',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final response = Completer<http.Response>(), sent = Completer<void>();
      final client = LabApiClient(
        transport: MockClient((_) async {
          sent.complete();
          return response.future;
        }),
      );
      addTearDown(client.close);
      final events = LabSession.expired.value;
      final oldRequest = client.get(
        LabApi.uri('/app/services/coordinator/me'),
        headers: {'Authorization': 'synthetic-old'},
      );
      final failure = expectLater(oldRequest, throwsA(isA<LabApiException>()));
      await sent.future;
      await LabSession.renewCoordinator(
        login: CoordinatorLogin.fromJson({
          ...login(),
          'token': 'synthetic-old',
        }),
        expectedTour: tour,
        expectedGeneration: LabSession.generation,
      );
      response.complete(http.Response('', 401));
      await failure;
      expect(prefs.getString('token'), 'synthetic-old');
      expect(await LabSession.hasActiveCoordinator(tour.coordinatorId), isTrue);
      expect(LabSession.expired.value, events);
    },
  );
}
