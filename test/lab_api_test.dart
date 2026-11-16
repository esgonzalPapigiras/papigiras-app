import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/mode.dart';

void main() {
  test('runtime defaults to the real local API, never fixtures', () {
    expect(LabMode.fixturesForTests, isFalse);
  });

  test(
    'only the exact localhost API origin and application routes are allowed',
    () async {
      var calls = 0;
      final client = LabApiClient(
        transport: MockClient((request) async {
          calls++;
          expect(request.followRedirects, isFalse);
          expect(request.maxRedirects, 0);
          expect(request.headers['Authorization'], 'Bearer lab-test');
          expect(request.headers.containsKey('cookie'), isFalse);
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.close);
      await client.post(
        LabApi.uri('/app/services/coordinator/login'),
        headers: {
          'Authorization': 'Bearer lab-test',
          'cookie': 'never-forward',
        },
        body: '{}',
      );
      expect(calls, 1);
      for (final url in [
        'https://example.invalid/app/services/coordinator/login',
        'http://127.0.0.1:80/app/services/coordinator/login',
        'http://localhost:8084/app/services/coordinator/login',
        'http://127.0.0.1:8084/api/admin',
        'http://user@127.0.0.1:8084/app/services/coordinator/login',
      ]) {
        await expectLater(
          client.get(Uri.parse(url)),
          throwsA(isA<SocketException>()),
        );
      }
      expect(calls, 1);
    },
  );

  test(
    'redirects and server failures never return successful fixture data',
    () async {
      final client = LabApiClient(
        transport: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://example.invalid'},
          ),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.get(LabApi.uri('/app/services/coordinator/me')),
        throwsA(isA<Exception>()),
      );
      final offline = LabApiClient(
        transport: MockClient(
          (_) async => throw const SocketException('offline'),
        ),
      );
      addTearDown(offline.close);
      await expectLater(
        offline.get(LabApi.uri('/app/services/coordinator/me')),
        throwsA(
          predicate(
            (e) => e.toString().contains(
              'servidor Papigiras LAB no está disponible',
            ),
          ),
        ),
      );
    },
  );
}
