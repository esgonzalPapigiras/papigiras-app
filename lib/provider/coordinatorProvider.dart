import 'package:papigiras_app/maps/hito_location_draft.dart';
import '../lab/session.dart';
import '../crew/crew_coordinator.dart';
import '../dto/TourSales.dart';
import '../documents/internal_documents_repository.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../voice/hito_publish_progress.dart';
import '../voice/voice_note_draft.dart';
import '../voice/voice_note_metadata.dart';
import '../dto/json_fields.dart';
import 'dart:typed_data';
import '../lab/api_http.dart';
import '../lab/mode.dart';
import '../lab/fixture_provider.dart';
import '../lab/media.dart';
import '../utils/PDFViewer.dart';
import '../utils/medical_pdf_name.dart';
import '../lab/preferences.dart';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/dto/Itinerary.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/dto/ProgramViewDto.dart';
import 'package:papigiras_app/dto/RequestActivities.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/binnacleaddlist.dart';
import 'package:papigiras_app/dto/positionMap.dart';
import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/dto/requestMedicalRecord.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/dto/updateMedicalRecord.dart';
import 'dart:convert';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';

class CoordinatorProviders
    with ChangeNotifier
    implements InternalDocumentsRepository {
  final LabApiClient _http;
  final _fixtures = FixtureCoordinatorProviders();
  String? _token;
  String? get token => _token;
  @override
  void dispose() {
    _http.close();
    _fixtures.dispose();
    super.dispose();
  }

  CoordinatorProviders({LabApiClient? client, bool preserveHitoDraft = false})
    : _http = client ?? LabApiClient(notifyOnUnauthorized: !preserveHitoDraft) {
    _loadToken();
  }

  Future<String?> _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? tokenExpiryStr = prefs.getString('tokenExpiry');
    if (token != null && tokenExpiryStr != null) {
      final tokenExpiry = DateTime.tryParse(tokenExpiryStr);
      final now = DateTime.now();
      if (tokenExpiry == null || tokenExpiry.isBefore(now)) {
        final generation = LabSession.generation;
        if (prefs.getString('token') == token &&
            prefs.getString('tokenExpiry') == tokenExpiryStr) {
          await prefs.remove('token');
          // A renewal may complete while the old removal is awaiting storage.
          // Never delete the new session's expiry from stale asynchronous work.
          if (LabSession.generation == generation &&
              prefs.getString('token') == null &&
              prefs.getString('tokenExpiry') == tokenExpiryStr) {
            await prefs.remove('tokenExpiry');
          }
        }
        return null;
      } else {
        _token = token;
        return token;
      }
    } else {
      return null;
    }
  }

  Future<void> checkLoginStatus(BuildContext context) async {
    if (LabMode.fixturesForTests) return _fixtures.checkLoginStatus(context);
    String? token = await _loadToken();
    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<CoordinatorLogin> loginCoordinator(String rut, String password) async {
    if (LabMode.fixturesForTests)
      return _fixtures.loginCoordinator(rut, password);
    return CoordinatorLogin.fromJson(
      await _loginLocal('coordinator', rut, password),
    );
  }

  Future<bool> hasHitoSession(int coordinatorId) async {
    if (LabMode.fixturesForTests) return true;
    return LabSession.hasActiveCoordinator(coordinatorId);
  }

  Future<void> reauthenticateHitoDraft({
    required String rut,
    required String password,
    required TourSales expectedTour,
  }) async {
    final generation = LabSession.generation;
    final login = await loginCoordinator(rut, password);
    if (login.coordinatorId != expectedTour.coordinatorId ||
        login.token.isEmpty) {
      throw const CoordinatorReauthenticationException(
        'Ingresa con la misma cuenta de coordinación que abrió este hito.',
      );
    }
    if (login.mustChangePassword) {
      throw const CoordinatorReauthenticationException(
        'Esta cuenta requiere cambiar su contraseña desde el acceso. Tu borrador sigue aquí.',
      );
    }
    // Check role and assignment using candidate token; never install another
    // account's session or reuse cached assignment before the server confirms.
    try {
      final response = await _http.get(
        LabApi.uri(
          '/app/services/coordinator/tours/${expectedTour.tourSalesId}',
        ),
        headers: {'Authorization': login.token},
      );
      final tour = CoordinatorTourDetail.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
      if (tour.tourId != expectedTour.tourSalesId || tour.assignmentId <= 0) {
        throw const FormatException('Asignación inválida.');
      }
      await LabSession.renewCoordinator(
        login: login,
        expectedTour: expectedTour,
        expectedGeneration: generation,
      );
    } on LabApiException catch (error) {
      if (error.statusCode == 403 || error.statusCode == 404) {
        throw const CoordinatorReauthenticationException(
          'Esta cuenta ya no tiene acceso a la gira. Conservamos tu borrador.',
        );
      }
      rethrow;
    }
  }

  // LAB-only contract. No imported passwords, operator token or URL credentials.
  Future<Map<String, dynamic>> _loginLocal(
    String role,
    String rut,
    String password,
  ) async {
    try {
      final response = await _http.post(
        LabApi.uri('/app/services/lab/mobile/login'),
        body: jsonEncode({'role': role, 'rut': rut, 'password': password}),
        headers: {'Content-Type': 'application/json'},
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } on LabApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        throw Exception(
          'Revisa el RUT y la contraseña. La cuenta debe estar habilitada en la copia local.',
        );
      }
      rethrow;
    }
  }

  Future<List<CoordinatorTour>> getCoordinatorTours() async {
    if (LabMode.fixturesForTests) return _fixtures.getCoordinatorTours();
    final token = await _loadToken();
    final url = LabApi.uri('/app/services/coordinator/me/tours');
    final response = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(_readError(response, 'No se pudieron cargar las giras'));
    }
    final decoded = JsonFields.records(
      jsonDecode(utf8.decode(response.bodyBytes)),
    );
    return decoded.map((item) => CoordinatorTour.fromJson(item)).toList();
  }

  Future<CoordinatorTourDetail> getCoordinatorTourDetail(int tourId) async {
    if (LabMode.fixturesForTests)
      return _fixtures.getCoordinatorTourDetail(tourId);
    final token = await _loadToken();
    final url = LabApi.uri('/app/services/coordinator/tours/$tourId');
    final response = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(_readError(response, 'No se pudo cargar la gira'));
    }
    return CoordinatorTourDetail.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<CoordinatorProfile> getCoordinatorProfile() async {
    if (LabMode.fixturesForTests) return _fixtures.getCoordinatorProfile();
    final token = await _loadToken();
    final url = LabApi.uri('/app/services/coordinator/me');
    final response = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(_readError(response, 'No se pudo cargar el perfil'));
    }
    return CoordinatorProfile.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<Uint8List?> getCoordinatorPicture() async {
    if (LabMode.fixturesForTests) return _fixtures.getCoordinatorPicture();
    final profile = await getCoordinatorProfile();
    if (!profile.hasPicture) return null;
    final token = await _loadToken();
    final response = await _http.get(
      LabApi.uri('/app/services/coordinator/me/picture'),
      headers: {'Authorization': token ?? ''},
    );
    return response.bodyBytes.isEmpty ? null : response.bodyBytes;
  }

  Future<void> updateCoordinatorPicture(XFile image) async {
    if (LabMode.fixturesForTests)
      return _fixtures.updateCoordinatorPicture(image);
    final token = await _loadToken();
    final request = http.MultipartRequest(
      'POST',
      LabApi.uri('/app/services/coordinator/me/picture'),
    );
    if (token != null) request.headers['Authorization'] = token;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await LabMedia.compressForUpload(image),
        filename: 'profile.jpg',
      ),
    );
    final response = await _http.send(request);
    await response.stream.drain<void>();
    notifyListeners();
  }

  Future<void> changeCoordinatorPassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.changeCoordinatorPassword(currentPassword, newPassword);
    final token = await _loadToken();
    final url = LabApi.uri('/app/services/coordinator/me/password');
    final response = await _http.post(
      url,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(_readError(response, 'No se pudo cambiar la contraseña'));
    }
  }

  /// Changes only the guardian credential. Identity comes from the authenticated
  /// guardian session; no passenger ID or RUT is sent and no shared endpoint is used.
  Future<void> changeAttorneyPassword(
    String currentPassword,
    String newPassword,
  ) async {
    final token = await _loadToken();
    try {
      await _http.post(
        LabApi.uri('/app/services/attorney/me/password'),
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? '',
        },
      );
    } on LabApiException catch (error) {
      if (error.statusCode == 404) {
        throw Exception(
          'El cambio de contraseña del apoderado aún no está disponible. Inténtalo más tarde.',
        );
      }
      if (error.statusCode == 400) {
        throw Exception(
          'Revisa tu contraseña actual. La nueva debe tener al menos 6 caracteres.',
        );
      }
      if (error.statusCode == 403) {
        throw Exception(
          'No se pudo verificar el acceso para cambiar la contraseña.',
        );
      }
      rethrow;
    }
  }

  String _readError(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            fallback;
      }
    } catch (_) {}
    return fallback;
  }

  Future<List<CrewCoordinator>> getCrewCoordinators(int tourId) async {
    if (tourId <= 0) throw ArgumentError('Gira inválida.');
    final token = await _loadToken();
    final response = await _http.get(
      LabApi.uri('/app/services/tripulations/coordinators', {
        'tourId': '$tourId',
      }),
      headers: {'Authorization': token ?? ''},
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('Tripulación inválida.');
    return decoded
        .map(
          (item) =>
              CrewCoordinator.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<Uint8List?> getCrewCoordinatorPicture(
    int tourId,
    int coordinatorId,
  ) async {
    if (tourId <= 0 || coordinatorId <= 0)
      throw ArgumentError('Coordinador o gira inválidos.');
    final token = await _loadToken();
    final response = await _http.send(
      http.Request(
        'GET',
        LabApi.uri(
          '/app/services/tripulations/coordinators/$coordinatorId/picture',
          {'tourId': '$tourId'},
        ),
      )..headers['Authorization'] = token ?? '',
    );
    if (response.statusCode == 204) {
      await response.stream.drain<void>();
      return null;
    }
    if (response.statusCode != 200 || (response.contentLength ?? 0) > 8388608) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('No pudimos cargar la foto.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > 8388608)
        throw const FormatException('Foto demasiado grande.');
      bytes.add(chunk);
    }
    return bytes.isEmpty ? null : bytes.takeBytes();
  }

  Future<List<TourTripulation>> getTripulation(String tourCode) async {
    if (LabMode.fixturesForTests) return _fixtures.getTripulation(tourCode);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/tripulations', {'tourId': tourCode});
    final resp = await _http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      final decorespoCreate = JsonFields.records(
        json.decode(utf8.decode(resp.bodyBytes)),
      );
      return decorespoCreate
          .map((job) => new TourTripulation.fromJson(job))
          .toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<Itinerary>> getItineray(String tourCode) async {
    if (LabMode.fixturesForTests) return _fixtures.getItineray(tourCode);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/binnacle', {'tourId': tourCode});
    final resp = await _http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      final decorespoCreate = JsonFields.records(
        json.decode(utf8.decode(resp.bodyBytes)),
      );
      return decorespoCreate.map((job) => new Itinerary.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<ActivitiesList>> getItinerayGuardados(String tourCode) async {
    if (LabMode.fixturesForTests)
      return _fixtures.getItinerayGuardados(tourCode);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/get/create-activities', {
      'tourId': tourCode,
    });
    final resp = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      final decorespoCreate = JsonFields.records(
        json.decode(utf8.decode(resp.bodyBytes)),
      );
      return decorespoCreate
          .map((job) => new ActivitiesList.fromJson(job))
          .toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> activitiesCreate(RequestActivities tourCode) async {
    if (LabMode.fixturesForTests) return _fixtures.activitiesCreate(tourCode);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/create-activities');
    final resp = await _http.post(
      url,
      body: jsonEncode(tourCode.toJson()),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      notifyListeners();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<ConsolidatedTourSalesDTO> addHito(RequestHito tourCode) async {
    if (LabMode.fixturesForTests) return _fixtures.addHito(tourCode);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/create-hito');
    final resp = await _http.post(
      url,
      body: jsonEncode(tourCode.toJson()),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(
        utf8.decode(resp.bodyBytes),
      );
      ConsolidatedTourSalesDTO login = new ConsolidatedTourSalesDTO.fromJson(
        decorespoCreate,
      );
      notifyListeners();
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> addHitoFoto(
    int hito,
    String tourId,
    List<XFile> imageFiles, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    if (LabMode.fixturesForTests)
      return _fixtures.addHitoFoto(hito, tourId, imageFiles);
    final token = await _loadToken();
    onProgress?.call(const HitoPublishProgress('Preparando fotos…'));
    final request =
        _ProgressMultipartRequest(
            'POST',
            LabApi.uri('/app/services/create-hito/fotos'),
            onProgress: (sent, total) => onProgress?.call(
              HitoPublishProgress(
                sent == total
                    ? 'Confirmando carga de fotos…'
                    : 'Cargando fotos…',
                fraction: sent / total,
              ),
            ),
          )
          ..fields['hitoId'] = hito.toString()
          ..fields['tourId'] = tourId;
    if (token != null) request.headers['Authorization'] = token;
    for (final file in imageFiles) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          await LabMedia.compressForUpload(file),
          filename: '${file.name.split('.').first}.jpg',
        ),
      );
    }
    final response = await _http.send(request);
    await response.stream.drain<void>();
    notifyListeners();
  }

  Future<VoiceNoteMetadata> addHitoVoice(
    int hitoId,
    int tourId,
    VoiceNoteDraft voice, {
    ValueChanged<HitoPublishProgress>? onProgress,
  }) async {
    if (LabMode.fixturesForTests)
      throw StateError('Esta prueba requiere un provider explícito.');
    if (hitoId <= 0 || tourId <= 0)
      throw ArgumentError('Hito o gira inválidos.');
    final bytes = await voice.file.readAsBytes();
    if (bytes.length > 2097152 ||
        bytes.length < 44 ||
        voice.duration > const Duration(seconds: 60)) {
      throw ArgumentError('La nota de voz excede el límite permitido.');
    }
    final token = await _loadToken();
    final request = _ProgressMultipartRequest(
      'POST',
      LabApi.uri('/app/services/hitos/$hitoId/audio', {'tourId': '$tourId'}),
      onProgress: (sent, total) => onProgress?.call(
        HitoPublishProgress(
          sent == total ? 'Confirmando nota de voz…' : 'Cargando nota de voz…',
          fraction: sent / total,
        ),
      ),
    );
    if (token != null) request.headers['Authorization'] = token;
    request.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        bytes,
        filename: 'nota-de-voz.wav',
        contentType: http.MediaType('audio', 'wav'),
      ),
    );
    final response = await _http.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200 && response.statusCode != 201)
      throw const FormatException('No se confirmó la nota de voz.');
    final metadata = VoiceNoteMetadata.parse(jsonDecode(body));
    if (metadata == null) throw const FormatException('Nota de voz inválida.');
    notifyListeners();
    return metadata;
  }

  /// Downloads only when Play is pressed. Native audio receives a local file.
  Future<File> readHitoVoice(
    int hitoId,
    int tourId,
    VoiceNoteMetadata metadata,
  ) async {
    if (LabMode.fixturesForTests)
      throw StateError('Esta prueba requiere un provider explícito.');
    if (hitoId <= 0 || tourId <= 0)
      throw ArgumentError('Hito o gira inválidos.');
    final token = await _loadToken();
    final request = http.Request(
      'GET',
      LabApi.uri('/app/services/hitos/$hitoId/audio', {'tourId': '$tourId'}),
    );
    if (token != null) request.headers['Authorization'] = token;
    final response = await _http.send(request);
    if (response.statusCode != 200 || (response.contentLength ?? 0) > 2097152) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('No pudimos cargar la nota de voz.');
    }
    final data = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (data.length + chunk.length > 2097152)
        throw const FormatException('Audio demasiado grande.');
      data.add(chunk);
    }
    final bytes = data.takeBytes();
    if (bytes.length != metadata.sizeBytes ||
        bytes.length < 44 ||
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      throw const FormatException('La nota de voz está incompleta.');
    }
    final root = await getTemporaryDirectory();
    final directory = await Directory(root.path).createTemp('papigiras-voice-');
    final file = File('${directory.path}/nota.wav');
    try {
      return await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<Uint8List?> getHitoAuthorPicture(int hitoId, int tourId) async {
    if (LabMode.fixturesForTests) return null;
    if (hitoId <= 0 || tourId <= 0)
      throw ArgumentError('Hito o gira inválidos.');
    final token = await _loadToken();
    final response = await _http.send(
      http.Request(
        'GET',
        LabApi.uri('/app/services/hitos/$hitoId/author-picture', {
          'tourId': '$tourId',
        }),
      )..headers['Authorization'] = token ?? '',
    );
    if (response.statusCode == 204) {
      await response.stream.drain<void>();
      return null;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > 8388608)
        throw const FormatException('Foto demasiado grande.');
      bytes.add(chunk);
    }
    return bytes.isEmpty ? null : bytes.takeBytes();
  }

  final Map<String, InternalTourDocument> _internalDocuments = {};
  @override
  Future<List<InternalTourDocument>> listInternalDocuments(int tourId) async {
    if (LabMode.fixturesForTests)
      throw StateError('Esta prueba requiere un provider explícito.');
    if (tourId <= 0) throw ArgumentError('Gira inválida.');
    final token = await _loadToken();
    final response = await _http.get(
      LabApi.uri('/app/services/internal-documents', {'tourId': '$tourId'}),
      headers: {'Authorization': token ?? ''},
    );
    final records = JsonFields.records(
      jsonDecode(utf8.decode(response.bodyBytes)),
    ).map(InternalTourDocument.fromJson).toList();
    if (records.any((item) => item.tourId != tourId))
      throw const FormatException('Documento ajeno a la gira solicitada.');
    _internalDocuments.removeWhere((_, item) => item.tourId == tourId);
    for (final item in records) {
      _internalDocuments[item.id] = item;
    }
    return records;
  }

  @override
  Future<List<Itinerary>> getInternalDocumentActivities(int tourId) async {
    if (LabMode.fixturesForTests)
      throw StateError('Esta prueba requiere un provider explícito.');
    if (tourId <= 0) throw ArgumentError('Gira inválida.');
    final token = await _loadToken();
    final response = await _http.get(
      LabApi.uri('/app/services/internal-documents/activities', {
        'tourId': '$tourId',
      }),
      headers: {'Authorization': token ?? ''},
    );
    return JsonFields.records(jsonDecode(utf8.decode(response.bodyBytes)))
        .map(
          (item) => Itinerary(
            itineraryId: JsonFields.id(item['id']),
            itinerary: JsonFields.text(item['name']),
          ),
        )
        .toList();
  }

  @override
  Future<InternalTourDocument> uploadInternalDocument({
    required int tourId,
    required String name,
    required InternalDocumentCategory category,
    int? activityId,
    required InternalDocumentFile file,
    void Function(double)? onProgress,
  }) async {
    if (LabMode.fixturesForTests)
      throw StateError('Esta prueba requiere un provider explícito.');
    validateInternalDocumentFile(file);
    if (tourId <= 0 ||
        name.trim().isEmpty ||
        name.trim().runes.length > 120 ||
        (activityId != null && activityId <= 0)) {
      throw const InternalDocumentValidationException(
        'Escribe un nombre válido para el documento.',
      );
    }
    final token = await _loadToken();
    final request =
        _ProgressMultipartRequest(
            'POST',
            LabApi.uri('/app/services/internal-documents'),
            onProgress: (sent, total) => onProgress?.call(sent / total),
          )
          ..fields['tourId'] = '$tourId'
          ..fields['name'] = name.trim()
          ..fields['category'] = category.wireValue;
    if (category == InternalDocumentCategory.voucher && activityId != null)
      request.fields['activityId'] = '$activityId';
    if (token != null) request.headers['Authorization'] = token;
    // The server independently identifies and validates the file contents.
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes,
        filename: file.fileName,
        contentType: http.MediaType.parse(file.contentType),
      ),
    );
    final response = await _http.send(request);
    final item = InternalTourDocument.fromJson(
      jsonDecode(await response.stream.bytesToString()) as Map<String, dynamic>,
    );
    if (item.tourId != tourId)
      throw const FormatException('Documento ajeno a la gira solicitada.');
    _internalDocuments[item.id] = item;
    notifyListeners();
    return item;
  }

  @override
  Future<InternalDocumentDownload> downloadInternalDocument({
    required int tourId,
    required String documentId,
  }) async {
    if (LabMode.fixturesForTests)
      throw StateError('Esta prueba requiere un provider explícito.');
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(documentId) || tourId <= 0)
      throw ArgumentError('Documento inválido.');
    if (_internalDocuments[documentId]?.tourId != tourId)
      await listInternalDocuments(tourId);
    final item = _internalDocuments[documentId];
    if (item == null || item.tourId != tourId)
      throw StateError('Documento no disponible para esta gira.');
    final token = await _loadToken();
    final response = await _http.send(
      http.Request(
        'GET',
        LabApi.uri('/app/services/internal-documents/$documentId', {
          'tourId': '$tourId',
        }),
      )..headers['Authorization'] = token ?? '',
    );
    if ((response.contentLength ?? 0) > internalDocumentMaxBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('Archivo demasiado grande.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > internalDocumentMaxBytes)
        throw const FormatException('Archivo demasiado grande.');
      bytes.add(chunk);
    }
    if (bytes.length != item.sizeBytes)
      throw const FormatException('El archivo está incompleto.');
    return InternalDocumentDownload(
      fileName: item.storedName,
      contentType: item.contentType,
      bytes: bytes.takeBytes(),
    );
  }

  /// Updates the existing record; never routes an edit through create-hito.
  Future<void> updateHito({
    required String idHito,
    required String idTour,
    required String title,
    required String description,
    required String closingNote,
    HitoLocationDraft? location,
  }) async {
    if (LabMode.fixturesForTests) {
      throw StateError('La edición en tests requiere un provider explícito.');
    }
    final hitoId = int.tryParse(idHito);
    final tourId = int.tryParse(idTour);
    if (hitoId == null || hitoId <= 0 || tourId == null || tourId <= 0) {
      throw ArgumentError('Identificador de hito o gira inválido.');
    }
    if (location != null &&
        (location.label.trim().isEmpty ||
            location.label.trim().runes.length > 255)) {
      throw ArgumentError('Nombre de ubicación inválido.');
    }
    final token = await _loadToken();
    final response = await _http.post(
      LabApi.uri('/app/services/update-hito'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
      body: jsonEncode({
        'idHito': hitoId,
        'idTour': tourId,
        'titulo': title.trim(),
        'descripcion': description.trim(),
        'notaCierre': closingNote.trim(),
        if (location != null) ...{
          'latitud': location.point.latitude.toString(),
          'longitud': location.point.longitude.toString(),
          'ubicacion': location.label.trim(),
        },
      }),
    );
    // The update contract deliberately returns no representation or new ID.
    if (response.statusCode != 204) {
      throw StateError('No se confirmó la actualización del hito.');
    }
    notifyListeners();
  }

  Future<void> deleteHito(String idHito, String idTour) async {
    if (LabMode.fixturesForTests) return _fixtures.deleteHito(idHito, idTour);
    final token = await _loadToken();
    await _http.post(
      LabApi.uri('/app/services/delete-hito', {
        'idHito': idHito,
        'idTour': idTour,
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    notifyListeners();
  }

  Future<DetailHitoList> getHitoComplete(String hito, String tourId) async {
    if (LabMode.fixturesForTests)
      return _fixtures.getHitoComplete(hito, tourId);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/get/detail/create-hito', {
      'idTour': tourId,
      'idHito': hito.toString(),
    });
    final resp = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      Map<String, dynamic> decodedResponse = json.decode(
        utf8.decode(resp.bodyBytes),
      );
      DetailHitoList login = new DetailHitoList.fromJson(decodedResponse);
      notifyListeners();
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourCode) async {
    if (LabMode.fixturesForTests) return _fixtures.getBinnacle(tourCode);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/get/create-hito', {'tourId': tourCode});
    final resp = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      final decorespoCreate = JsonFields.records(
        json.decode(utf8.decode(resp.bodyBytes)),
      );
      return decorespoCreate
          .map((job) => new ConsolidatedTourSalesDTO.fromJson(job))
          .toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<Document>> getDocument(String tourCode) async {
    if (LabMode.fixturesForTests) return _fixtures.getDocument(tourCode);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/document-records', {
      'tourId': tourCode,
    });
    final resp = await _http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      final decorespoCreate = JsonFields.records(
        json.decode(utf8.decode(resp.bodyBytes)),
      );
      return decorespoCreate.map((job) => new Document.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<PassengerList>> getListPassenger(String tourCode) async {
    if (LabMode.fixturesForTests) return _fixtures.getListPassenger(tourCode);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/passengers/list', {'tourId': tourCode});
    final resp = await _http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      final decorespoCreate = JsonFields.records(
        json.decode(utf8.decode(resp.bodyBytes)),
      );
      return decorespoCreate
          .map((job) => new PassengerList.fromJson(job))
          .toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> downloadDocument(
    String folderName,
    String fileName,
    String idTour,
    String folder,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.downloadDocument(folderName, fileName, idTour, folder);
    await requestStoragePermission();
    String? token = await _loadToken();
    final url = LabApi.uri('/app/services/download', {
      'folderName': folderName,
      'fileName': fileName,
      'idTour': idTour,
      'folder': folder,
    });
    final response = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (fileName == "Nomina alumnos") {
      fileName = "NominaAlumnos.pdf";
    } else if (fileName == "Programa gira") {
      fileName = "ProgramaGira.pdf";
    }
    if (response.statusCode != 200)
      throw Exception('No se pudo descargar el PDF: ${response.statusCode}');
    await LabMedia.exportPdf(response.bodyBytes, fileName);
  }

  Future<void> viewDocument(
    String folderName,
    String fileName,
    String idTour,
    BuildContext context,
    String folder,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.viewDocument(
        folderName,
        fileName,
        idTour,
        context,
        folder,
      );
    String? token = await _loadToken();
    try {
      final url = LabApi.uri('/app/services/view', {
        'folderName': folderName,
        'fileName': fileName,
        'idTour': idTour,
        'folder': folder,
      });
      final resp = await _http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? '',
        },
      );
      if (!context.mounted) return;
      if (resp.statusCode == 200) {
        final file = await LabMedia.storePdf(resp.bodyBytes, fileName);
        _showPdfDialog(file.path, context);
      } else {
        throw Exception('Error al obtener el documento: ${resp.statusCode}');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos abrir el documento. Vuelve a intentarlo.',
            ),
          ),
        );
      }
    }
  }

  void _showPdfDialog(
    String filePath,
    BuildContext context, {
    String? documentName,
    bool isMedicalRecord = false,
  }) {
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PDFViewer(
          filePath: filePath,
          documentName: documentName,
          isMedicalRecord: isMedicalRecord,
        ),
      ),
    );
  }

  Future<void> requestStoragePermission() async {
    // Native save-as dialogs and app documents need no broad storage permission.
  }

  Future<String> getDownloadDirectory() async =>
      (await LabMedia.documentDirectory()).path;

  Future<ResponseAttorney?> validateLoginUserFather(
    String rut,
    String password,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.validateLoginUserFather(rut, password);
    return ResponseAttorney.fromJson(
      await _loginLocal('attorney', rut, password),
    );
  }

  Future<ResponseAttorney?> validateLoginUserPassenger(
    String rut,
    String password,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.validateLoginUserPassenger(rut, password);
    return ResponseAttorney.fromJson(
      await _loginLocal('passenger', rut, password),
    );
  }

  Future<bool> validateMedicalRecord(String rut) async {
    if (LabMode.fixturesForTests) return _fixtures.validateMedicalRecord(rut);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/validate/medical-records', {
      'user': rut,
    });
    final resp = await _http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.body.toLowerCase() == 'true') {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> createMedicalRecord(
    RequestPassengerMedical medicalRecord,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.createMedicalRecord(medicalRecord);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/medical-records');
    final resp = await _http.post(
      url,
      body: jsonEncode(medicalRecord.toJson()),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<PassengersMedicalRecordDTO> getMedicalRecord(
    String idTour,
    String idPassenger,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.getMedicalRecord(idTour, idPassenger);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/get/medical-records', {
      'tourId': idTour,
      'idPassenger': idPassenger,
    });
    final resp = await _http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(
        utf8.decode(resp.bodyBytes),
      );
      PassengersMedicalRecordDTO login =
          new PassengersMedicalRecordDTO.fromJson(decorespoCreate);
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<ProgramViewDto> getviewProgram(String idTour) async {
    if (LabMode.fixturesForTests) return _fixtures.getviewProgram(idTour);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/get/program-view', {'tourId': idTour});
    final resp = await _http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(
        utf8.decode(resp.bodyBytes),
      );
      ProgramViewDto login = new ProgramViewDto.fromJson(decorespoCreate);
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> downloadDocumentMedicalRecord(
    String idTour,
    String idPassenger,
    String identificacion,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.downloadDocumentMedicalRecord(
        idTour,
        idPassenger,
        identificacion,
      );
    await requestStoragePermission();
    String? token = await _loadToken();
    final url = LabApi.uri('/app/services/get/pdf/view/medical-records', {
      'tourId': idTour,
      'idPassenger': idPassenger,
      'identificacion': identificacion,
    });
    final response = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (response.statusCode != 200)
      throw Exception('No se pudo descargar el PDF: ${response.statusCode}');
    final fileName = MedicalPdfName.fromContentDisposition(
      response.headers['content-disposition'],
      identificacion,
    );
    await LabMedia.exportPdf(
      response.bodyBytes,
      fileName,
      dialogTitle: 'Guardar ficha médica',
    );
  }

  Future<void> shareDocumentMedicalRecord(
    String idTour,
    String idPassenger,
    String identificacion,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.shareDocumentMedicalRecord(
        idTour,
        idPassenger,
        identificacion,
      );
    await requestStoragePermission();
    String? token = await _loadToken();
    final url = LabApi.uri('/app/services/get/pdf/view/medical-records', {
      'tourId': idTour,
      'idPassenger': idPassenger,
      'identificacion': identificacion,
    });
    final response = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (response.statusCode != 200)
      throw Exception('No se pudo descargar el PDF: ${response.statusCode}');
    final fileName = MedicalPdfName.fromContentDisposition(
      response.headers['content-disposition'],
      identificacion,
    );
    final file = await LabMedia.storePdf(response.bodyBytes, fileName);
    try {
      await LabMedia.sharePdf(file, name: fileName, text: 'Ficha médica');
    } finally {
      await LabMedia.removePreview(file.path);
    }
  }

  /// Read the existing medical PDF without routing to an editable record.
  /// The server authorizes the requested passenger/tour against the session.
  Future<Uint8List> getMedicalRecordPdf(
    String idTour,
    String idPassenger,
  ) async {
    if ((int.tryParse(idTour) ?? 0) <= 0 ||
        (int.tryParse(idPassenger) ?? 0) <= 0) {
      throw const FormatException('Falta la identidad de la ficha.');
    }
    final generation = LabSession.generation;
    final token = await _loadToken();
    if (generation != LabSession.generation) {
      throw StateError('La sesión cambió.');
    }
    final response = await _http.post(
      LabApi.uri('/app/services/get/pdf/medical-records', {
        'tourId': idTour,
        'idPassenger': idPassenger,
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (generation != LabSession.generation) {
      throw StateError('La sesión cambió.');
    }
    if (response.statusCode != 200) throw LabApiException(response.statusCode);
    LabMedia.validatePdf(response.bodyBytes);
    return response.bodyBytes;
  }

  Future<void> viewDocumentMedicalRecord(
    String idTour,
    String idPassenger,
    BuildContext context,
    String identificacion,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.viewDocumentMedicalRecord(
        idTour,
        idPassenger,
        context,
        identificacion,
      );
    String? token = await _loadToken();
    try {
      final url = LabApi.uri('/app/services/get/pdf/medical-records', {
        'tourId': idTour,
        'idPassenger': idPassenger,
      });
      final resp = await _http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? '',
        },
      );
      if (resp.statusCode == 200) {
        final fileName = MedicalPdfName.fromContentDisposition(
          resp.headers['content-disposition'],
          identificacion,
        );
        final file = await LabMedia.storePdf(resp.bodyBytes, fileName);
        _showPdfDialog(
          file.path,
          context,
          documentName: fileName,
          isMedicalRecord: true,
        );
      } else {
        throw Exception('Error al obtener el documento: ${resp.statusCode}');
      }
    } catch (e) {
      // Personal data and exception payloads are intentionally not logged.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al visualizar el documento: $e')),
      );
    }
  }

  Future<List<PositionMap>> positionMap(String tourCode) async {
    if (LabMode.fixturesForTests) return _fixtures.positionMap(tourCode);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/get/binnacle-map', {
      'tourId': tourCode,
    });
    final resp = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      final decorespoCreate = JsonFields.records(
        json.decode(utf8.decode(resp.bodyBytes)),
      );
      return decorespoCreate
          .map((job) => new PositionMap.fromJson(job))
          .toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> desactivateAccount(String rut) async {
    if (LabMode.fixturesForTests) return _fixtures.desactivateAccount(rut);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/desactivate/login', {'rut': rut});
    final resp = await _http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      notifyListeners();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> addHitoFotoPassenger(
    String hito,
    String tourId,
    XFile imageFiles,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.addHitoFotoPassenger(hito, tourId, imageFiles);
    final token = await _loadToken();
    final request =
        http.MultipartRequest(
            'POST',
            LabApi.uri('/app/services/add/fotos/passenger'),
          )
          ..fields['passengerId'] = hito
          ..fields['tourId'] = tourId;
    if (token != null) request.headers['Authorization'] = token;
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        await LabMedia.compressForUpload(imageFiles),
        filename: '${imageFiles.name.split('.').first}.jpg',
      ),
    );
    final response = await _http.send(request);
    await response.stream.drain<void>();
    notifyListeners();
  }

  Future<Responseimagepassenger> getPicturePassenger(
    String passenger,
    String tourId,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.getPicturePassenger(passenger, tourId);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/get/fotos/passenger', {
      'tourId': tourId,
      'passengerId': passenger.toString(),
    });
    final resp = await _http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      Map<String, dynamic> decodedResponse = json.decode(
        utf8.decode(resp.bodyBytes),
      );
      Responseimagepassenger login = new Responseimagepassenger.fromJson(
        decodedResponse,
      );
      notifyListeners();
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<PositionCoordinator>> uniqueID(String gps) async {
    if (LabMode.fixturesForTests) return _fixtures.uniqueID(gps);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/gps/data', {'idTour': gps.toString()});
    final resp = await _http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      final decoded = JsonFields.records(
        json.decode(utf8.decode(resp.bodyBytes)),
      );
      return decoded.map((item) => PositionCoordinator.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load GPS data');
    }
  }

  /// PG-036. Explicit family update with current revision and renewed consent.
  /// No automatic retry: a timeout or conflict must not overwrite a later edit.
  Future<PassengersMedicalRecordDTO> updateFamilyMedicalRecord(
    RequestPassengerMedical medical, {
    required String revision,
    required bool preserveLegacyMedications,
  }) async {
    final token = await _loadToken();
    final response = await _http.post(
      LabApi.uri('/app/services/medical-records/update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
      body: jsonEncode({
        ...medical.toJson(),
        'expectedRevision': revision,
        'aceptaAutorizacion': true,
        'versionAutorizacion': 'medical-emergency-v1',
        'conservarMedicamentosAnteriores': preserveLegacyMedications,
      }),
    );
    if (response.statusCode != 200)
      throw StateError('Medical record update failed');
    return PassengersMedicalRecordDTO.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<bool> sendMedicalDataEdit(RequestPassengerMedicalEdit medical) async {
    if (LabMode.fixturesForTests) return _fixtures.sendMedicalDataEdit(medical);
    String? token = await _loadToken();
    var url = LabApi.uri('/app/services/medical-records/edit');
    final resp = await _http.post(
      url,
      body: jsonEncode(medical.toJson()),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );
    if (resp.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> updateFcmToken(
    String passengerRut,
    String fcmToken,
    String deviceType,
  ) async {
    if (LabMode.fixturesForTests)
      return _fixtures.updateFcmToken(passengerRut, fcmToken, deviceType);
    final token = await _loadToken();
    final url = LabApi.uri('/app/services/notifications/update-fcm-token');
    final response = await _http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
      body: jsonEncode({
        'passengerRut': passengerRut,
        'fcmToken': fcmToken,
        'deviceType': deviceType,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'No se pudo registrar la solicitud local (${response.statusCode}).',
      );
    }
  }
}

/// Counts the exact multipart body, including its boundaries, without a second
/// client or bypassing LabApiClient's destination/session checks.
class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(
    super.method,
    super.url, {
    required this.onProgress,
  });
  final void Function(int sent, int total) onProgress;
  @override
  http.ByteStream finalize() {
    final total = contentLength;
    final stream = super.finalize();
    var sent = 0;
    onProgress(0, total);
    return http.ByteStream(
      stream.map((chunk) {
        sent += chunk.length;
        onProgress(sent, total);
        return chunk;
      }),
    );
  }
}

class CoordinatorReauthenticationException implements Exception {
  const CoordinatorReauthenticationException(this.message);
  final String message;
}
