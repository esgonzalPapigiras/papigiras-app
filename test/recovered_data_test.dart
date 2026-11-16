import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ProgramViewDto.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/dto/json_fields.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/local_access.dart';
import 'package:papigiras_app/lab/media_data.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

const image =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==';

void main() {
  test(
    'legacy optional fields and JSON date arrays do not invent identities or locations',
    () {
      final passenger = PassengerList.fromJson({'passengerId': '42'});
      expect(passenger.passengerId, 42);
      expect(passenger.passengerIdentification, '');
      expect(passenger.passengerverificate, isFalse);
      expect(passenger.countMedicalRecordOk, 0);
      final record = PassengersMedicalRecordDTO.fromJson({
        'medicamentos': null,
        'fechaAutorizacion': [2025, 2, 28],
      });
      expect(record.medications, '');
      expect(record.authorizationDate, '2025-02-28');
      expect(record.passengerId, isNull);
      final program = ProgramViewDto.fromJson({
        'activities': [null, 'Visita ficticia', 123],
        'tourInit': [2026, 3, 1],
      });
      expect(program.activities, ['Visita ficticia']);
      expect(program.tourInit, '2026-03-01');
      expect(Document.fromJson({'visibleToAll': null}).documentType, '');
      expect(
        TourTripulation.fromJson({
          'tourSalesId': '7',
          'tourTripulationBusYear': 2020,
        }).tourTripulationBusYear,
        '2020',
      );
      final hito = ConsolidatedTourSalesDTO.fromJson({
        'binnacleDetailId': 9,
        'binnacleLatitud': -33.4,
        'binnacleLongitud': null,
      });
      expect(hito.binnacleLatitud, '-33.4');
      expect(TripMapData.from([hito]).unmappedCount, 1);
      expect(TripMapData.from([hito]).unknownDateCount, 1);
      expect(JsonFields.dateText([2025, 2, 31]), '');
      expect(() => CoordinatorLogin.fromJson({}), throwsFormatException);
      expect(
        () => PassengerList.fromJson({'passengerId': null}),
        throwsFormatException,
      );
      expect(() => JsonFields.id(1.5), throwsFormatException);
    },
  );

  test(
    'recovered image fields never follow remote, local, file or redirect URLs',
    () {
      for (final value in [
        'https://example.invalid/private/photo.jpg',
        'http://127.0.0.1:8084/app/services/photo',
        '//example.invalid/private',
        'file:///private/image',
        'data:text/html;base64,SGVsbG8=',
        'not base64',
        '',
        null,
        12,
      ]) {
        expect(LocalImageData.decode(value), isNull);
        expect(Responseimagepassenger.fromJson({'image': value}).image, '');
      }
      expect(LocalImageData.decode(image), isNotNull);
      expect(LocalImageData.decode('data:image/png;base64,$image'), isNotNull);
      final detail = DetailHitoList.fromJson({
        'images': [null, image, 'https://example.invalid/photo', 12],
      });
      expect(detail.images, [image]);
      expect(DetailHitoList.fromJson({'images': null}).images, isEmpty);
      expect(DetailHitoList.fromJson({}).missingImageCount, 0);
      final partial = DetailHitoList.fromJson({
        'images': [image],
        'missingImageCount': 2,
      });
      expect(partial.images, [image]);
      expect(partial.missingImageCount, 2);
      expect(
        DetailHitoList.fromJson({'missingImageCount': -1}).missingImageCount,
        0,
      );
    },
  );

  test(
    'empty historical lists are safe but malformed responses remain visible failures',
    () async {
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((_) async => http.Response('null', 200)),
        ),
      );
      addTearDown(provider.dispose);
      expect(await provider.getDocument('7'), isEmpty);
      expect(await provider.getBinnacle('7'), isEmpty);
      expect(await provider.getListPassenger('7'), isEmpty);
      final malformed = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient(
            (_) async => http.Response('{"unexpected":true}', 200),
          ),
        ),
      );
      addTearDown(malformed.dispose);
      await expectLater(malformed.getDocument('7'), throwsFormatException);
    },
  );

  test(
    'operator unlock, pagination and role session use only reviewed local paths',
    () async {
      final requests = <http.Request>[];
      final access = LocalAccessClient(
        client: LabApiClient(
          transport: MockClient((request) async {
            requests.add(request);
            expect(request.url.host, '127.0.0.1');
            expect(request.url.port, 8084);
            expect(request.followRedirects, isFalse);
            expect(
              request.url.toString(),
              isNot(contains('synthetic-password')),
            );
            if (request.url.path.endsWith('/operator/login'))
              return http.Response(
                '{"token":"Bearer synthetic-operator"}',
                200,
              );
            expect(
              request.headers['Authorization'],
              'Bearer synthetic-operator',
            );
            if (request.url.path.endsWith('/profiles'))
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'profileId': 42,
                      'label': 'Perfil sintético',
                      'detail': 'Gira de prueba',
                    },
                  ],
                  'offset': 25,
                  'limit': 25,
                  'hasMore': false,
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            return http.Response(
              jsonEncode(LabFixtures.passenger.toJson()),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      addTearDown(access.close);
      await access.unlock('synthetic-password');
      for (final role in ['attorney', 'passenger', 'coordinator']) {
        final page = await access.profiles(
          role,
          query: 'Perfil sintético',
          offset: 25,
        );
        expect(page.items.single.id, 42);
        expect(page.offset, 25);
        expect(page.hasMore, isFalse);
        expect(requests.last.url.queryParameters['role'], role);
        expect(requests.last.url.queryParameters['query'], 'Perfil sintético');
      }
      await access.session('passenger', 42);
      expect(jsonDecode(requests.last.body), {
        'role': 'passenger',
        'profileId': 42,
      });
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      final before = requests.length;
      await expectLater(
        access.profiles('administrator'),
        throwsFormatException,
      );
      await expectLater(access.session('passenger', 0), throwsFormatException);
      expect(requests.length, before);
    },
  );

  test(
    'new local session replaces legacy identity without persisting operator credentials',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', 'Bearer old-fictitious');
      await prefs.setString('loginData', 'old identity');
      await prefs.setInt('selectedTourId', 999);
      await prefs.setStringList('pendingCoordinatorLocations', [
        'synthetic pending',
      ]);
      await prefs.setString('unrelatedPreference', 'preserved');
      await LabSession.savePassenger(LabFixtures.passenger, 'attorney');
      expect(prefs.getString('userRole'), 'father');
      expect(prefs.getString('labSessionRevision'), LabSession.revision);
      expect(prefs.getInt('selectedTourId'), isNull);
      expect(prefs.getStringList('pendingCoordinatorLocations'), isNull);
      expect(prefs.getString('unrelatedPreference'), 'preserved');
      expect(
        prefs.getKeys().any((key) => key.toLowerCase().contains('password')),
        isFalse,
      );
      expect(
        prefs.getKeys().any((key) => key.toLowerCase().contains('operator')),
        isFalse,
      );
    },
  );

  test(
    '401 invalidates only the rejected active session, not a newer login',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', 'Bearer current');
      await prefs.setString('loginData', 'synthetic session');
      final client = LabApiClient(
        transport: MockClient(
          (_) async => http.Response('sensitive error never returned', 401),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.get(
          LabApi.uri('/app/services/coordinator/me'),
          headers: {'Authorization': 'Bearer previous'},
        ),
        throwsException,
      );
      expect(prefs.getString('token'), 'Bearer current');
      await expectLater(
        client.get(
          LabApi.uri('/app/services/coordinator/me'),
          headers: {'Authorization': 'Bearer current'},
        ),
        throwsException,
      );
      expect(prefs.getString('token'), isNull);
      expect(prefs.getString('loginData'), isNull);
      expect(prefs.getBool('isLoggedIn'), isFalse);
    },
  );
  test(
    'QR roster is loaded through the local API with the active JWT',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', 'Bearer synthetic-qr-session');
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      );
      var calls = 0;
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((request) async {
            calls++;
            expect(request.method, 'POST');
            expect(
              request.url,
              LabApi.uri('/app/services/passengers/list', {'tourId': '42'}),
            );
            expect(
              request.headers['Authorization'],
              'Bearer synthetic-qr-session',
            );
            expect(request.followRedirects, isFalse);
            return http.Response(
              '[{"passengerId":7,"passengerName":"Demo"}]',
              200,
            );
          }),
        ),
      );
      addTearDown(provider.dispose);
      final roster = await provider.getListPassenger('42');
      expect(roster.single.passengerId, 7);
      expect(calls, 1);
    },
  );
}
