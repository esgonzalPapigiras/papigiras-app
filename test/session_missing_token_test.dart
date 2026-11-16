import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

// PG-020: all credentials and preferences below are synthetic in-memory data.
// MockClient never opens a socket or contacts the LAB/production server.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> seed({
    String? token,
    bool? loggedIn = true,
    bool expired = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (token != null) 'token': token,
      if (token != null)
        'tokenExpiry': DateTime.now()
            .add(Duration(hours: expired ? -1 : 1))
            .toIso8601String(),
      if (loggedIn != null) 'isLoggedIn': loggedIn,
      'userRole': 'coordinator',
      'coordinatorData': '{"coordinatorId":910001}',
      'loginData': '{"tourSalesId":910001}',
      'selectedTourId': 910001,
      'labSessionRevision': LabSession.revision,
      'coordinatorLocationSharingEnabled': false,
      'unrelatedPreference': 'retained',
    });
    return SharedPreferences.getInstance();
  }

  Map<String, Object?> snapshot(SharedPreferences prefs) => {
    for (final key in prefs.getKeys()) key: prefs.get(key),
  };

  void expectRevoked(
    SharedPreferences prefs,
    int generation,
    int events, {
    bool notify = true,
  }) {
    for (final key in LabSession.keys) {
      expect(prefs.containsKey(key), isFalse, reason: 'Revoked key: $key');
    }
    expect(prefs.getBool('isLoggedIn'), isFalse);
    expect(prefs.getString('unrelatedPreference'), 'retained');
    expect(LabSession.generation, generation + 1);
    expect(LabSession.expired.value, events + (notify ? 1 : 0));
  }

  Future<void> expectDenied(
    Future<http.Response> request, {
    int status = 401,
  }) => expectLater(
    request,
    throwsA(
      isA<LabApiException>().having((e) => e.statusCode, 'statusCode', status),
    ),
  );

  setUp(() => LabMode.useFixturesForTests(false));

  test(
    'expired passenger request returns to access instead of retrying tokenless',
    () async {
      final prefs = await seed(token: 'synthetic-expired-token', expired: true);
      final generation = LabSession.generation;
      final events = LabSession.expired.value;
      var requests = 0;
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((request) async {
            requests++;
            expect(request.method, 'POST');
            expect(request.url.path, '/app/services/passengers/list');
            expect(request.url.queryParameters['tourId'], '910001');
            expect(request.headers['authorization'], '');
            return http.Response('', 403);
          }),
        ),
      );
      addTearDown(provider.dispose);
      await expectLater(
        provider.getListPassenger('910001'),
        throwsA(isA<LabApiException>()),
      );
      expect(requests, 1);
      expectRevoked(prefs, generation, events);
    },
  );

  for (final status in [401, 403]) {
    for (final requestToken in <String?>[null, '']) {
      for (final storedToken in <String?>[null, '']) {
        test(
          '$status with ${requestToken == null ? 'absent' : 'empty'} header '
          'clears marked session with ${storedToken == null ? 'absent' : 'empty'} stored token',
          () async {
            final prefs = await seed(token: storedToken);
            final generation = LabSession.generation;
            final events = LabSession.expired.value;
            final client = LabApiClient(
              transport: MockClient((_) async => http.Response('', status)),
            );
            addTearDown(client.close);
            await expectDenied(
              client.post(
                LabApi.uri('/app/services/passengers/list', {
                  'tourId': '910001',
                }),
                headers: {
                  if (requestToken != null) 'Authorization': requestToken,
                },
              ),
              status: status,
            );
            expectRevoked(prefs, generation, events);
          },
        );
      }
    }
  }

  test('late tokenless 401 cannot clear a newer session generation', () async {
    final prefs = await seed();
    final response = Completer<http.Response>();
    final sent = Completer<void>();
    final client = LabApiClient(
      transport: MockClient((_) async {
        sent.complete();
        return response.future;
      }),
    );
    addTearDown(client.close);
    final failure = expectDenied(
      client.get(LabApi.uri('/app/services/coordinator/me')),
    );
    await sent.future;
    await LabSession.clear(prefs);
    // Keep the token absent to isolate the generation guard from token matching.
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userRole', 'coordinator');
    final before = snapshot(prefs);
    final generation = LabSession.generation;
    final events = LabSession.expired.value;
    response.complete(http.Response('', 401));
    await failure;
    expect(snapshot(prefs), before);
    expect(LabSession.generation, generation);
    expect(LabSession.expired.value, events);
  });

  test(
    'tokenless 401 cannot revoke a token installed while request was pending',
    () async {
      final prefs = await seed();
      final response = Completer<http.Response>();
      final sent = Completer<void>();
      final client = LabApiClient(
        transport: MockClient((_) async {
          sent.complete();
          return response.future;
        }),
      );
      addTearDown(client.close);
      final failure = expectDenied(
        client.get(LabApi.uri('/app/services/coordinator/me')),
      );
      await sent.future;
      // Do not advance generation here: independently exercise the token guard.
      await prefs.setString('token', 'synthetic-new-token');
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      );
      final before = snapshot(prefs);
      final generation = LabSession.generation;
      final events = LabSession.expired.value;
      response.complete(http.Response('', 401));
      await failure;
      expect(snapshot(prefs), before);
      expect(LabSession.generation, generation);
      expect(LabSession.expired.value, events);
    },
  );

  for (final status in [401, 403]) {
    for (final loggedIn in <bool?>[false, null]) {
      test(
        'wrong login $status with isLoggedIn=$loggedIn does not trigger session exit',
        () async {
          final prefs = await seed(loggedIn: loggedIn);
          final before = snapshot(prefs);
          final generation = LabSession.generation;
          final events = LabSession.expired.value;
          final client = LabApiClient(
            transport: MockClient((_) async => http.Response('', status)),
          );
          addTearDown(client.close);
          await expectDenied(
            client.post(LabApi.uri('/app/services/lab/mobile/login')),
            status: status,
          );
          expect(snapshot(prefs), before);
          expect(LabSession.generation, generation);
          expect(LabSession.expired.value, events);
        },
      );
    }
  }

  test(
    'draft tokenless 401 revokes session without navigation notification',
    () async {
      final prefs = await seed();
      final generation = LabSession.generation;
      final events = LabSession.expired.value;
      final client = LabApiClient(
        notifyOnUnauthorized: false,
        transport: MockClient((_) async => http.Response('', 401)),
      );
      addTearDown(client.close);
      await expectDenied(client.post(LabApi.uri('/app/services/create-hito')));
      expectRevoked(prefs, generation, events, notify: false);
    },
  );

  test(
    'matching nonempty token keeps the existing revocation behavior',
    () async {
      final prefs = await seed(token: 'synthetic-current-token');
      final generation = LabSession.generation;
      final events = LabSession.expired.value;
      final client = LabApiClient(
        transport: MockClient((_) async => http.Response('', 401)),
      );
      addTearDown(client.close);
      await expectDenied(
        client.get(
          LabApi.uri('/app/services/coordinator/me'),
          headers: {'Authorization': 'synthetic-current-token'},
        ),
      );
      expectRevoked(prefs, generation, events);
    },
  );

  test(
    'unrelated nonempty token cannot revoke a marked tokenless session',
    () async {
      final prefs = await seed();
      final before = snapshot(prefs);
      final generation = LabSession.generation;
      final events = LabSession.expired.value;
      await LabSession.invalidateIfCurrent(
        'synthetic-other-token',
        expectedGeneration: generation,
      );
      expect(snapshot(prefs), before);
      expect(LabSession.generation, generation);
      expect(LabSession.expired.value, events);
    },
  );

  test(
    'tokenless invalidation without captured generation is ignored',
    () async {
      final prefs = await seed();
      final before = snapshot(prefs);
      final generation = LabSession.generation;
      final events = LabSession.expired.value;
      await LabSession.invalidateIfCurrent('');
      expect(snapshot(prefs), before);
      expect(LabSession.generation, generation);
      expect(LabSession.expired.value, events);
    },
  );

  test(
    'authenticated 403 preserves session and does not trigger navigation',
    () async {
      final prefs = await seed(token: 'synthetic-current-token');
      final before = snapshot(prefs);
      final generation = LabSession.generation;
      final events = LabSession.expired.value;
      final client = LabApiClient(
        transport: MockClient((_) async => http.Response('', 403)),
      );
      addTearDown(client.close);
      await expectDenied(
        client.post(
          LabApi.uri('/app/services/passengers/list'),
          headers: {'Authorization': 'synthetic-current-token'},
        ),
        status: 403,
      );
      expect(snapshot(prefs), before);
      expect(LabSession.generation, generation);
      expect(LabSession.expired.value, events);
    },
  );
}
