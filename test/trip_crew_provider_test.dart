import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'list contract carries exact tour and every linked coordinator',
    () async {
      final p = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((r) async {
            expect(r.method, 'GET');
            expect(r.url.path, '/app/services/tripulations/coordinators');
            expect(r.url.queryParameters, {'tourId': '910001'});
            return http.Response(
              jsonEncode([
                {'coordinatorId': 910001, 'name': 'Alex LAB', 'rut': 'LAB1'},
                {'coordinatorId': 910002, 'name': 'Camila LAB', 'rut': 'LAB2'},
              ]),
              200,
            );
          }),
        ),
      );
      expect((await p.getCrewCoordinators(910001)).map((m) => m.id), [
        910001,
        910002,
      ]);
      p.dispose();
    },
  );
  test('photo uses association ID and tour; 204 is absence', () async {
    final p = CoordinatorProviders(
      client: LabApiClient(
        transport: MockClient((r) async {
          expect(
            r.url.path,
            '/app/services/tripulations/coordinators/910002/picture',
          );
          expect(r.url.queryParameters, {'tourId': '910001'});
          return http.Response('', 204);
        }),
      ),
    );
    expect(await p.getCrewCoordinatorPicture(910001, 910002), isNull);
    p.dispose();
  });
  test(
    'forbidden photo surfaces error instead of treating payload as image',
    () async {
      final p = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((_) async => http.Response('denied', 404)),
        ),
      );
      await expectLater(
        p.getCrewCoordinatorPicture(910001, 910002),
        throwsA(isA<LabApiException>()),
      );
      p.dispose();
    },
  );
  test('oversized photo is refused', () async {
    final p = CoordinatorProviders(
      client: LabApiClient(
        transport: MockClient(
          (_) async => http.Response.bytes(List.filled(8388609, 0), 200),
        ),
      ),
    );
    await expectLater(
      p.getCrewCoordinatorPicture(910001, 910002),
      throwsFormatException,
    );
    p.dispose();
  });
  test('invalid identity never calls transport', () async {
    final p = CoordinatorProviders(
      client: LabApiClient(
        transport: MockClient((_) async => throw StateError('unexpected')),
      ),
    );
    await expectLater(
      p.getCrewCoordinatorPicture(910001, 0),
      throwsArgumentError,
    );
    await expectLater(p.getCrewCoordinators(0), throwsArgumentError);
    p.dispose();
  });
}
