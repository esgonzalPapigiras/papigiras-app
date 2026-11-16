import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    LabMode.useFixturesForTests(false);
    SharedPreferences.setMockInitialValues({
      'token': 'Bearer fixture-only',
      'tokenExpiry': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'isLoggedIn': true,
      'userRole': 'father',
    });
  });

  test(
    'guardian password request uses its dedicated endpoint and authenticated identity',
    () async {
      var calls = 0;
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((request) async {
            calls++;
            expect(request.method, 'POST');
            expect(
              request.url,
              LabApi.uri('/app/services/attorney/me/password'),
            );
            expect(request.headers['Authorization'], 'Bearer fixture-only');
            expect(
              request.headers['Content-Type'],
              contains('application/json'),
            );
            expect(jsonDecode(request.body), {
              'currentPassword': 'fixture-current',
              'newPassword': 'fixture-next',
            });
            return http.Response('{}', 200);
          }),
        ),
      );
      addTearDown(provider.dispose);
      await provider.changeAttorneyPassword('fixture-current', 'fixture-next');
      expect(calls, 1);
      expect(
        (await SharedPreferences.getInstance()).getString('token'),
        'Bearer fixture-only',
      );
    },
  );

  test(
    'missing guardian endpoint never falls back to the student endpoint',
    () async {
      final requests = <Uri>[];
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((request) async {
            requests.add(request.url);
            return http.Response('{}', 404);
          }),
        ),
      );
      addTearDown(provider.dispose);
      await expectLater(
        provider.changeAttorneyPassword('fixture-current', 'fixture-next'),
        throwsA(
          predicate(
            (error) => error.toString().contains('aún no está disponible'),
          ),
        ),
      );
      expect(requests, [LabApi.uri('/app/services/attorney/me/password')]);
      expect(
        (await SharedPreferences.getInstance()).getString('token'),
        'Bearer fixture-only',
      );
    },
  );

  for (final status in [400, 403]) {
    test(
      'rejected password request ($status) retains authenticated session',
      () async {
        final provider = CoordinatorProviders(
          client: LabApiClient(
            transport: MockClient((_) async => http.Response('{}', status)),
          ),
        );
        addTearDown(provider.dispose);
        await expectLater(
          provider.changeAttorneyPassword('fixture-current', 'fixture-next'),
          throwsA(isA<Exception>()),
        );
        expect(
          (await SharedPreferences.getInstance()).getString('token'),
          'Bearer fixture-only',
        );
      },
    );
  }

  test(
    'expired JWT still revokes session rather than bypassing protection',
    () async {
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((_) async => http.Response('{}', 401)),
        ),
      );
      addTearDown(provider.dispose);
      await expectLater(
        provider.changeAttorneyPassword('fixture-current', 'fixture-next'),
        throwsA(isA<LabApiException>()),
      );
      expect(
        (await SharedPreferences.getInstance()).getString('token'),
        isNull,
      );
    },
  );
}
