import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/runtime/api_destination.dart';

void main() {
  for (final role in ['coordinator', 'attorney', 'passenger']) {
    test(
      '$role login preserves the official contract without URL credentials',
      () async {
        var calls = 0;
        final provider = CoordinatorProviders(
          client: LabApiClient(
            transport: MockClient((request) async {
              calls++;
              expect(request.url.path, '/app/services/$role/login');
              expect(request.url.query, isEmpty);
              expect(request.url.userInfo, isEmpty);
              expect(request.method, 'POST');
              if (role == 'coordinator') {
                expect(jsonDecode(request.body), {
                  'rut': '990000018',
                  'password': 'test-only',
                });
              } else {
                expect(
                  request.headers['content-type'],
                  startsWith('application/x-www-form-urlencoded'),
                );
                expect(Uri.splitQueryString(request.body), {
                  'user': '990000018',
                  'password': 'test-only',
                });
              }
              return http.Response(
                jsonEncode({
                  'coordinatorId': 1,
                  'rut': '990000018',
                  'token': 'Bearer test-only',
                  'passengerId': 1,
                  'tourId': 2,
                  'tokenKey': 'Bearer test-only',
                  'isActive': true,
                }),
                200,
              );
            }),
          ),
        );
        addTearDown(provider.dispose);
        if (role == 'coordinator') {
          expect(
            (await provider.loginCoordinator(
              '990000018',
              'test-only',
            )).coordinatorId,
            1,
          );
        } else if (role == 'attorney') {
          expect(
            (await provider.validateLoginUserFather(
              '990000018',
              'test-only',
            ))!.passengerId,
            1,
          );
        } else {
          expect(
            (await provider.validateLoginUserPassenger(
              '990000018',
              'test-only',
            ))!.passengerId,
            1,
          );
        }
        expect(calls, 1);
      },
      skip: !AppEnvironment.connected
          ? 'Requires the connected build configuration'
          : false,
    );
  }
}
