import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/runtime/api_destination.dart';

void main() {
  test(
    'connected transport keeps credentials on its compiled origin',
    () async {
      if (!AppEnvironment.connected) return;
      var calls = 0;
      final api = LabApiClient(
        transport: MockClient((request) async {
          calls++;
          expect(request.url.origin, AppEnvironment.destination!.origin.origin);
          expect(request.followRedirects, isFalse);
          expect(request.headers['authorization'], 'Bearer test-only');
          expect(request.headers.containsKey('cookie'), isFalse);
          expect(request.body, '{}');
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.close);
      final target = LabApi.uri('/app/services/passengers/list', {
        'tourId': '1',
      });
      expect(target.scheme, 'https');
      expect(LabSession.revision, contains(AppEnvironment.apiUrl));
      await api.post(
        target,
        headers: {
          'authorization': 'Bearer test-only',
          'cookie': 'do-not-send',
          'content-type': 'application/json',
        },
      );
      await expectLater(
        api.get(target.replace(host: 'other.example.test')),
        throwsA(isA<SocketException>()),
      );
      expect(calls, 1);
    },
    skip: !AppEnvironment.connected
        ? 'Run with PAPIGIRAS_API_URL for connected-mode coverage'
        : false,
  );

  test(
    'connected redirect never forwards a session or becomes success',
    () async {
      final api = LabApiClient(
        transport: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://other.example.test'},
          ),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.get(LabApi.uri('/app/services/coordinator/me')),
        throwsA(isA<LabApiException>()),
      );
    },
    skip: !AppEnvironment.connected
        ? 'Run with PAPIGIRAS_API_URL for connected-mode coverage'
        : false,
  );
}
