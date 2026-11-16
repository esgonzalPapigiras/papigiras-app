import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const token = 'synthetic-edit-session';
  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(false);
    SharedPreferences.setMockInitialValues({
      'token': token,
      'tokenExpiry': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'isLoggedIn': true,
    });
    addTearDown(() {
      HttpOverrides.global = previous;
      LabMode.useFixturesForTests(false);
      SharedPreferences.setMockInitialValues({});
    });
  });

  Future<void> update(
    CoordinatorProviders provider, {
    String hito = '1',
    String tour = '910001',
  }) => provider.updateHito(
    idHito: hito,
    idTour: tour,
    title: '  Título ficticio  ',
    description: '  Descripción ficticia  ',
    closingNote: '  Cierre ficticio  ',
  );

  test(
    '204 envía una única actualización autenticada con sólo IDs y textos',
    () async {
      var requests = 0;
      var notifications = 0;
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((request) async {
            requests++;
            expect(request.method, 'POST');
            expect(request.url, LabApi.uri('/app/services/update-hito'));
            expect(request.url.hasQuery, isFalse);
            expect(request.headers['Authorization'], token);
            expect(
              request.headers['content-type'],
              contains('application/json'),
            );
            expect(request.followRedirects, isFalse);
            expect(request.maxRedirects, 0);
            expect(jsonDecode(request.body), {
              'idHito': 1,
              'idTour': 910001,
              'titulo': 'Título ficticio',
              'descripcion': 'Descripción ficticia',
              'notaCierre': 'Cierre ficticio',
            });
            return http.Response('', 204);
          }),
        ),
      );
      addTearDown(provider.dispose);
      provider.addListener(() => notifications++);
      await update(provider);
      expect(requests, 1);
      expect(notifications, 1);
    },
  );

  test(
    'selected point is sent atomically on the same update request',
    () async {
      var requests = 0;
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((request) async {
            requests++;
            expect(request.url, LabApi.uri('/app/services/update-hito'));
            expect(jsonDecode(request.body), {
              'idHito': 910003,
              'idTour': 910001,
              'titulo': 'Título ficticio',
              'descripcion': 'Descripción ficticia',
              'notaCierre': '',
              'latitud': '-33.45',
              'longitud': '-70.66',
              'ubicacion': 'Punto seleccionado en el mapa',
            });
            return http.Response('', 204);
          }),
        ),
      );
      addTearDown(provider.dispose);
      await provider.updateHito(
        idHito: '910003',
        idTour: '910001',
        title: 'Título ficticio',
        description: 'Descripción ficticia',
        closingNote: '',
        location: HitoLocationDraft.selectedPoint(const LatLng(-33.45, -70.66)),
      );
      expect(requests, 1);
    },
  );

  test('invalid labels cannot send a partial location', () async {
    var requests = 0;
    final provider = CoordinatorProviders(
      client: LabApiClient(
        transport: MockClient((request) async {
          requests++;
          return http.Response('', 204);
        }),
      ),
    );
    addTearDown(provider.dispose);
    for (final label in ['  ', 'x' * 256]) {
      await expectLater(
        provider.updateHito(
          idHito: '910003',
          idTour: '910001',
          title: 'Título ficticio',
          description: 'Descripción ficticia',
          closingNote: '',
          location: HitoLocationDraft(
            point: const LatLng(-33.45, -70.66),
            label: label,
          ),
        ),
        throwsArgumentError,
      );
    }
    expect(requests, 0);
  });

  for (final status in [401, 403, 302, 500]) {
    test(
      '$status no notifica éxito, no reintenta ni sigue redirecciones',
      () async {
        var requests = 0;
        var notifications = 0;
        final provider = CoordinatorProviders(
          client: LabApiClient(
            transport: MockClient((request) async {
              requests++;
              expect(request.followRedirects, isFalse);
              expect(request.maxRedirects, 0);
              return http.Response(
                'DETALLE_PRIVADO_FICTICIO',
                status,
                headers: {'location': 'https://example.invalid/never-open'},
              );
            }),
          ),
        );
        addTearDown(provider.dispose);
        provider.addListener(() => notifications++);
        await expectLater(
          update(provider),
          throwsA(
            isA<LabApiException>()
                .having((error) => error.statusCode, 'status', status)
                .having(
                  (error) => error.toString(),
                  'message',
                  isNot(contains('DETALLE_PRIVADO_FICTICIO')),
                ),
          ),
        );
        expect(requests, 1);
        expect(notifications, 0);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('token'), status == 401 ? isNull : token);
        if (status == 401) expect(prefs.getBool('isLoggedIn'), isFalse);
      },
    );
  }

  test('200 inesperado no se interpreta como guardado confirmado', () async {
    var notifications = 0;
    var requests = 0;
    final provider = CoordinatorProviders(
      client: LabApiClient(
        transport: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      ),
    );
    addTearDown(provider.dispose);
    provider.addListener(() => notifications++);
    await expectLater(update(provider), throwsA(isA<StateError>()));
    expect(requests, 1);
    expect(notifications, 0);
  });

  test(
    'identificadores inválidos se rechazan antes de enviar solicitudes',
    () async {
      var requests = 0;
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((_) async {
            requests++;
            return http.Response('', 204);
          }),
        ),
      );
      addTearDown(provider.dispose);
      for (final id in ['', 'no-es-id', '0', '-1', '1.5']) {
        await expectLater(
          update(provider, hito: id),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          update(provider, tour: id),
          throwsA(isA<ArgumentError>()),
        );
      }
      expect(requests, 0);
    },
  );

  test(
    'modo fixture exige implementación explícita y nunca finge guardar',
    () async {
      var requests = 0;
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((_) async {
            requests++;
            return http.Response('', 204);
          }),
        ),
      );
      addTearDown(provider.dispose);
      LabMode.useFixturesForTests(true);
      await expectLater(update(provider), throwsA(isA<StateError>()));
      expect(requests, 0);
    },
  );
}
