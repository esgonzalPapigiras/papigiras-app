import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:papigiras_app/documents/internal_documents_repository.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

const _tour = 910001;
const _id = '00000000-0000-4000-8000-000000000016';
const _token = 'synthetic-private-documents-session';
const _base = '/app/services/internal-documents';

Map<String, Object?> _metadata({
  int tour = _tour,
  int size = 4,
  InternalDocumentCategory category = InternalDocumentCategory.general,
}) => {
  'id': _id,
  'tourId': tour,
  'category': category.wireValue,
  'name': 'Documento ficticio',
  'originalName': 'prueba.pdf',
  'storedName': 'documento-20261105-GIRA-LAB-$_id.pdf',
  'contentType': 'application/pdf',
  'sizeBytes': size,
  'createdAt': '2026-11-05T15:00:00Z',
  'activityId': category == InternalDocumentCategory.voucher ? 910050 : null,
  'activityName': category == InternalDocumentCategory.voucher
      ? 'Actividad ficticia'
      : null,
};

InternalDocumentFile _file({int bytes = 4, String extension = 'pdf'}) =>
    InternalDocumentFile(
      fileName: 'prueba.$extension',
      contentType: internalDocumentMime(extension),
      bytes: Uint8List(bytes),
    );

http.StreamedResponse _json(Object value, {int status = 200}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(value))),
      status,
      headers: {'content-type': 'application/json'},
    );

class _Transport extends http.BaseClient {
  _Transport(this.handler);
  final Future<http.StreamedResponse> Function(
    http.BaseRequest request,
    http.ByteStream body,
  )
  handler;
  final requests = <http.BaseRequest>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return handler(request, request.finalize());
  }
}

void _expectAuthorized(http.BaseRequest request) {
  expect(request.url.origin, 'http://127.0.0.1:8084');
  expect(request.headers['authorization'], _token);
  expect(request.followRedirects, isFalse);
  expect(request.maxRedirects, 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = LabOfflineHttpOverrides();
    LabMode.useFixturesForTests(false);
    SharedPreferences.setMockInitialValues({
      'token': _token,
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

  CoordinatorProviders providerFor(_Transport transport) {
    final provider = CoordinatorProviders(
      client: LabApiClient(transport: transport),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  Future<InternalTourDocument> upload(
    CoordinatorProviders provider, {
    InternalDocumentFile? file,
    InternalDocumentCategory category = InternalDocumentCategory.general,
    int? activityId,
    void Function(double)? onProgress,
  }) => provider.uploadInternalDocument(
    tourId: _tour,
    name: '  Documento ficticio  ',
    category: category,
    activityId: activityId,
    file: file ?? _file(),
    onProgress: onProgress,
  );

  test(
    'lista privada GET autenticada conserva metadatos sin API pública',
    () async {
      final transport = _Transport((request, body) async {
        _expectAuthorized(request);
        expect(request.method, 'GET');
        expect(request.url, LabApi.uri(_base, {'tourId': '$_tour'}));
        expect(await body.toBytes(), isEmpty);
        return _json([_metadata()]);
      });
      final records = await providerFor(transport).listInternalDocuments(_tour);
      expect(records.single.id, _id);
      expect(records.single.tourId, _tour);
      expect(records.single.name, 'Documento ficticio');
      expect(records.single.createdAt, DateTime.utc(2026, 11, 5, 15));
      expect(transport.requests, hasLength(1));
    },
  );

  test('actividades usa el endpoint privado con itineraryId como ID', () async {
    final transport = _Transport((request, body) async {
      _expectAuthorized(request);
      expect(request.method, 'GET');
      expect(
        request.url,
        LabApi.uri('$_base/activities', {'tourId': '$_tour'}),
      );
      await body.drain<void>();
      return _json([
        {'id': 910050, 'name': 'Actividad ficticia'},
      ]);
    });
    final records = await providerFor(
      transport,
    ).getInternalDocumentActivities(_tour);
    expect(records.single.itineraryId, 910050);
    expect(records.single.itinerary, 'Actividad ficticia');
  });

  for (final extension in ['pdf', 'jpg', 'docx', 'xlsx']) {
    test(
      'multipart $extension envía MIME, nombre y campos de gira sin rutas',
      () async {
        final transport = _Transport((request, body) async {
          _expectAuthorized(request);
          expect(request.method, 'POST');
          expect(request.url, LabApi.uri(_base));
          final multipart = request as http.MultipartRequest;
          expect(multipart.fields, {
            'tourId': '$_tour',
            'name': 'Documento ficticio',
            'category': 'GENERAL',
          });
          expect(multipart.files.single.field, 'file');
          expect(multipart.files.single.filename, 'prueba.$extension');
          expect(
            multipart.files.single.contentType.toString(),
            internalDocumentMime(extension),
          );
          final bytes = await body.toBytes();
          expect(bytes.length, request.contentLength);
          final text = latin1.decode(bytes);
          expect(
            text,
            contains('content-type: ${internalDocumentMime(extension)}'),
          );
          expect(text, contains('name="file"; filename="prueba.$extension"'));
          return _json(_metadata(), status: 201);
        });
        final provider = providerFor(transport);
        var notifications = 0;
        provider.addListener(() => notifications++);
        final result = await upload(
          provider,
          file: _file(extension: extension),
          activityId: 910050,
        );
        expect(result.id, _id);
        expect(notifications, 1);
        expect(transport.requests, hasLength(1));
      },
    );
  }

  test(
    'voucher incluye ID de actividad; general nunca envía ese campo',
    () async {
      final transport = _Transport((request, body) async {
        final multipart = request as http.MultipartRequest;
        expect(multipart.fields, {
          'tourId': '$_tour',
          'name': 'Documento ficticio',
          'category': 'VOUCHER',
          'activityId': '910050',
        });
        await body.drain<void>();
        return _json(
          _metadata(category: InternalDocumentCategory.voucher),
          status: 201,
        );
      });
      final result = await upload(
        providerFor(transport),
        category: InternalDocumentCategory.voucher,
        activityId: 910050,
      );
      expect(result.activityId, 910050);
    },
  );

  test(
    'voucher sin actividad omite el campo multipart y conserva el nombre',
    () async {
      final transport = _Transport((request, body) async {
        _expectAuthorized(request);
        final multipart = request as http.MultipartRequest;
        expect(multipart.fields, {
          'tourId': '$_tour',
          'name': 'Documento ficticio',
          'category': 'VOUCHER',
        });
        await body.drain<void>();
        return _json({
          ..._metadata(category: InternalDocumentCategory.voucher),
          'activityId': null,
          'activityName': null,
        }, status: 201);
      });
      final result = await upload(
        providerFor(transport),
        category: InternalDocumentCategory.voucher,
      );
      expect(result.activityId, isNull);
      expect(result.activityName, isNull);
    },
  );

  test('lista de otra gira se rechaza y nunca habilita descarga', () async {
    final transport = _Transport((request, body) async {
      expect(request.url.path, _base);
      await body.drain<void>();
      return _json([_metadata(tour: 910002)]);
    });
    final provider = providerFor(transport);
    await expectLater(
      provider.listInternalDocuments(_tour),
      throwsFormatException,
    );
    await expectLater(
      provider.downloadInternalDocument(tourId: _tour, documentId: _id),
      throwsFormatException,
    );
    expect(transport.requests, hasLength(2));
    expect(
      transport.requests.every((request) => request.url.path == _base),
      isTrue,
    );
  });

  test(
    'respuesta de upload de otra gira no notifica éxito ni se cachea',
    () async {
      final transport = _Transport((request, body) async {
        await body.drain<void>();
        return request.method == 'POST'
            ? _json(_metadata(tour: 910002), status: 201)
            : _json([]);
      });
      final provider = providerFor(transport);
      var notifications = 0;
      provider.addListener(() => notifications++);
      await expectLater(upload(provider), throwsFormatException);
      expect(notifications, 0);
      await expectLater(
        provider.downloadInternalDocument(tourId: _tour, documentId: _id),
        throwsStateError,
      );
      expect(transport.requests.map((request) => request.url.path), [
        _base,
        _base,
      ]);
    },
  );

  test(
    '10 MiB exactos se aceptan; exceso y validaciones fallan sin transporte',
    () async {
      final transport = _Transport((request, body) async {
        await body.drain<void>();
        return _json(_metadata(size: internalDocumentMaxBytes), status: 201);
      });
      final provider = providerFor(transport);
      for (final file in [
        _file(bytes: internalDocumentMaxBytes + 1),
        _file(bytes: 0),
      ]) {
        await expectLater(
          upload(provider, file: file),
          throwsA(isA<InternalDocumentValidationException>()),
        );
      }
      await expectLater(
        upload(
          provider,
          category: InternalDocumentCategory.voucher,
          activityId: 0,
        ),
        throwsA(isA<InternalDocumentValidationException>()),
      );
      expect(transport.requests, isEmpty);
      await upload(provider, file: _file(bytes: internalDocumentMaxBytes));
      expect(transport.requests, hasLength(1));
    },
  );

  test(
    'descarga consulta metadatos autorizados y devuelve bytes con nombre del servidor',
    () async {
      final transport = _Transport((request, body) async {
        _expectAuthorized(request);
        expect(request.method, 'GET');
        expect(request.url.queryParameters, {'tourId': '$_tour'});
        await body.drain<void>();
        if (request.url.path == _base) return _json([_metadata()]);
        expect(request.url.path, '$_base/$_id');
        return http.StreamedResponse(
          Stream.fromIterable([
            [1, 2],
            [3, 4],
          ]),
          200,
          contentLength: 4,
        );
      });
      final provider = providerFor(transport);
      final result = await provider.downloadInternalDocument(
        tourId: _tour,
        documentId: _id,
      );
      expect(result.bytes, [1, 2, 3, 4]);
      expect(result.fileName, _metadata()['storedName']);
      expect(result.contentType, 'application/pdf');
      await provider.downloadInternalDocument(tourId: _tour, documentId: _id);
      expect(transport.requests.map((request) => request.url.path), [
        _base,
        '$_base/$_id',
        '$_base/$_id',
      ]);
    },
  );

  for (final mode in ['advertised-oversize', 'stream-oversize', 'incomplete']) {
    test(
      'descarga $mode rechaza bytes y no devuelve un archivo parcial',
      () async {
        var chunksRead = 0;
        Stream<List<int>> responseBytes() async* {
          chunksRead++;
          if (mode == 'incomplete') {
            yield [1, 2];
          } else {
            yield Uint8List(internalDocumentMaxBytes);
            chunksRead++;
            yield [1];
            chunksRead++;
            yield [2];
          }
        }

        final transport = _Transport((request, body) async {
          await body.drain<void>();
          if (request.url.path == _base) return _json([_metadata()]);
          return http.StreamedResponse(
            responseBytes(),
            200,
            contentLength: mode == 'advertised-oversize'
                ? internalDocumentMaxBytes + 1
                : null,
          );
        });
        await expectLater(
          providerFor(
            transport,
          ).downloadInternalDocument(tourId: _tour, documentId: _id),
          throwsFormatException,
        );
        expect(transport.requests, hasLength(2));
        if (mode == 'stream-oversize') expect(chunksRead, 2);
        if (mode == 'advertised-oversize')
          expect(
            chunksRead,
            lessThan(3),
            reason:
                'La cabecera ya excede el límite; cancelar sin drenar contenido ilimitado.',
          );
      },
    );
  }

  for (final operation in ['list', 'upload', 'download', 'activities']) {
    test(
      '403 en $operation no filtra respuesta privada ni reintenta con otra API',
      () async {
        final transport = _Transport((request, body) async {
          _expectAuthorized(request);
          await body.drain<void>();
          if (operation == 'download' && request.url.path == _base)
            return _json([_metadata()]);
          return http.StreamedResponse(
            Stream.value(utf8.encode('PRIVATE_SYNTHETIC_BODY')),
            403,
          );
        });
        final provider = providerFor(transport);
        var notifications = 0;
        provider.addListener(() => notifications++);
        final Future<Object?> result = switch (operation) {
          'list' => provider.listInternalDocuments(_tour),
          'upload' => upload(provider),
          'download' => provider.downloadInternalDocument(
            tourId: _tour,
            documentId: _id,
          ),
          _ => provider.getInternalDocumentActivities(_tour),
        };
        await expectLater(
          result,
          throwsA(
            isA<LabApiException>()
                .having((error) => error.statusCode, 'status', 403)
                .having(
                  (error) => error.toString(),
                  'safe message',
                  isNot(contains('PRIVATE_SYNTHETIC_BODY')),
                ),
          ),
        );
        expect(transport.requests, hasLength(operation == 'download' ? 2 : 1));
        expect(notifications, 0);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString('token'), _token);
      },
    );
  }

  test(
    '100% representa bytes enviados: espera confirmación HTTP antes de éxito',
    () async {
      final response = Completer<http.StreamedResponse>();
      final sent = Completer<void>();
      final progress = <double>[];
      final transport = _Transport((request, body) async {
        final bytes = await body.toBytes();
        expect(bytes.length, request.contentLength);
        sent.complete();
        return response.future;
      });
      final provider = providerFor(transport);
      var completed = false;
      var notifications = 0;
      provider.addListener(() => notifications++);
      final result = upload(provider, onProgress: progress.add).then((value) {
        completed = true;
        return value;
      });
      await sent.future;
      expect(progress.first, 0);
      expect(progress.last, 1);
      expect(progress.any((value) => value > 0 && value < 1), isTrue);
      expect(progress.every((value) => value >= 0 && value <= 1), isTrue);
      expect(List<double>.from(progress)..sort(), progress);
      expect(completed, isFalse);
      expect(notifications, 0);
      response.complete(_json(_metadata(), status: 201));
      await result;
      expect(completed, isTrue);
      expect(notifications, 1);
    },
  );

  test(
    'fixtures exige repositorio explícito en todas las operaciones privadas',
    () async {
      final transport = _Transport((request, body) async {
        await body.drain<void>();
        return _json([]);
      });
      final provider = providerFor(transport);
      LabMode.useFixturesForTests(true);
      await expectLater(
        provider.listInternalDocuments(_tour),
        throwsStateError,
      );
      await expectLater(upload(provider), throwsStateError);
      await expectLater(
        provider.downloadInternalDocument(tourId: _tour, documentId: _id),
        throwsStateError,
      );
      await expectLater(
        provider.getInternalDocumentActivities(_tour),
        throwsStateError,
      );
      expect(transport.requests, isEmpty);
    },
  );
}
