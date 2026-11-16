import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
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
      'userRole': 'passenger',
    });
  });
  test('student reuses authenticated existing PDF read endpoint', () async {
    final provider = CoordinatorProviders(
      client: LabApiClient(
        transport: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url,
            LabApi.uri('/app/services/get/pdf/medical-records', {
              'tourId': '910001',
              'idPassenger': '910011',
            }),
          );
          expect(request.headers['Authorization'], 'Bearer fixture-only');
          expect(request.body, isEmpty);
          return http.Response('%PDF-1.4 fixture', 200);
        }),
      ),
    );
    addTearDown(provider.dispose);
    expect(
      await provider.getMedicalRecordPdf('910001', '910011'),
      '%PDF-1.4 fixture'.codeUnits,
    );
  });
  for (final status in [403, 404, 500]) {
    test(
      'failed PDF $status never falls back to writes or another endpoint',
      () async {
        var requests = 0;
        final provider = CoordinatorProviders(
          client: LabApiClient(
            transport: MockClient((_) async {
              requests++;
              return http.Response('{}', status);
            }),
          ),
        );
        addTearDown(provider.dispose);
        await expectLater(
          provider.getMedicalRecordPdf('910001', '910011'),
          throwsA(isA<LabApiException>()),
        );
        expect(requests, 1);
      },
    );
  }
  test('non PDF success is rejected before storing a preview', () async {
    final provider = CoordinatorProviders(
      client: LabApiClient(
        transport: MockClient(
          (_) async => http.Response('<html>error</html>', 200),
        ),
      ),
    );
    addTearDown(provider.dispose);
    await expectLater(
      provider.getMedicalRecordPdf('910001', '910011'),
      throwsFormatException,
    );
  });
  test(
    'session changing during fetch prevents stale medical PDF delivery',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((_) {
            started.complete();
            return response.future;
          }),
        ),
      );
      addTearDown(provider.dispose);
      final future = provider.getMedicalRecordPdf('910001', '910011');
      final assertion = expectLater(future, throwsA(isA<StateError>()));
      await started.future;
      await LabSession.clear(await SharedPreferences.getInstance());
      response.complete(http.Response('%PDF-1.4 fixture', 200));
      await assertion;
    },
  );
  test('invalid identity performs no request', () async {
    var requests = 0;
    final provider = CoordinatorProviders(
      client: LabApiClient(
        transport: MockClient((_) async {
          requests++;
          return http.Response('%PDF-1.4 fixture', 200);
        }),
      ),
    );
    addTearDown(provider.dispose);
    await expectLater(
      provider.getMedicalRecordPdf('910001', ''),
      throwsFormatException,
    );
    expect(requests, 0);
  });
}
