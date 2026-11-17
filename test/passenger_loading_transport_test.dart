import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

void main() {
  test(
    'roster and counter load large tours with explicit JSON request body',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', 'Bearer synthetic-test');
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      );
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/app/services/passengers/list');
            expect(request.body, '{}');
            expect(request.contentLength, 2);
            expect(request.headers['authorization'], 'Bearer synthetic-test');
            final count = request.url.queryParameters['tourId'] == '940001'
                ? 49
                : 114;
            return http.Response(
              jsonEncode(
                List.generate(
                  count,
                  (i) => {
                    'passengerId': 9400001 + i,
                    'passengerName': 'Persona de prueba $i',
                    'passengerSex': i.isEven ? 'M' : 'F',
                    'passengerverificate': false,
                    'statusMedicalRecord': i.isEven ? 'OK' : '',
                  },
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      addTearDown(provider.dispose);
      expect(await provider.getListPassenger('940001'), hasLength(49));
      expect(await provider.getListPassenger('910001'), hasLength(114));
    },
  );

  test(
    'existing JSON, GET and non-JSON bodies retain their contents',
    () async {
      final received = <http.Request>[];
      final client = LabApiClient(
        transport: MockClient((request) async {
          received.add(request);
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.close);
      final uri = LabApi.uri('/app/services/passengers/list');
      await client.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: '{"value":1}',
      );
      await client.get(uri, headers: {'content-type': 'application/json'});
      await client.post(uri, headers: {'content-type': 'text/plain'});
      expect(received.map((r) => r.body).toList(), ['{"value":1}', '', '']);
    },
  );

  test('multipart file uploads are not replaced by empty JSON', () async {
    final client = LabApiClient(
      transport: MockClient((request) async {
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        expect(request.body, contains('synthetic-file-content'));
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    final upload =
        http.MultipartRequest(
            'POST',
            LabApi.uri('/app/services/create-hito/fotos'),
          )
          ..files.add(
            http.MultipartFile.fromString(
              'images',
              'synthetic-file-content',
              filename: 'fixture.txt',
            ),
          );
    await (await client.send(upload)).stream.drain<void>();
  });
}
