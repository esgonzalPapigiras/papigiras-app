import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
import 'package:path/path.dart' as path;
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class CoordinatorProviders with ChangeNotifier {
  String? _token;
  String? get token => _token;
  var urlDynamic = 'stingray-app-9tqd9-djh6d.ondigitalocean.app';
  //var urlDynamic = '192.168.1.6:8084';
  CoordinatorProviders() {
    _loadToken();
  }

  Future<String?> _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? tokenExpiryStr = prefs.getString('tokenExpiry');
    if (token != null && tokenExpiryStr != null) {
      DateTime tokenExpiry = DateTime.parse(tokenExpiryStr);
      final now = DateTime.now();
      if (tokenExpiry.isBefore(now)) {
        await prefs.remove('token');
        await prefs.remove('tokenExpiry');
        return null;
      } else {
        return token;
      }
    } else {
      return null;
    }
  }

  Future<void> checkLoginStatus(BuildContext context) async {
    String? token = await _loadToken();
    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<CoordinatorLogin> loginCoordinator(String rut, String password) async {
    final url = Uri.https(urlDynamic, '/app/services/coordinator/login');
    final response = await http.post(
      url,
      body: jsonEncode({'rut': rut, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception(_readError(response, 'No se pudo iniciar sesión'));
    }
    return CoordinatorLogin.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<Map<String, int>> getPassengerCountsBySex({
    required String tourCode,
    required int tourId,
  }) async {
    final summaryUrl = Uri.https(
      urlDynamic,
      '/app/services/coordinator',
      {'tourCode': tourCode},
    );
    final summaryResponse = await http.post(
      summaryUrl,
      headers: {'Content-Type': 'application/json'},
    );
    if (summaryResponse.statusCode != 200) {
      throw Exception('No se pudieron cargar los contadores de pasajeros');
    }

    final summary = jsonDecode(utf8.decode(summaryResponse.bodyBytes)) as Map<String, dynamic>;
    final rawCounts = (summary['passengerCountsBySex'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final tripulations = await getTripulation(tourId.toString());

    final coordinatorCount = tripulations
        .where((item) => item.tourTripulationTypeId == 32)
        .map((item) => item.tourTripulationIdentificationId.trim())
        .where((rut) => rut.isNotEmpty)
        .toSet()
        .length;

    final duplicationFactor = coordinatorCount > 0 ? coordinatorCount : 1;

    return rawCounts.map(
      (key, value) => MapEntry(
        key,
        ((value as num).toInt() / duplicationFactor).round(),
      ),
    );
  }

  Future<List<CoordinatorTour>> getCoordinatorTours() async {
    final token = await _loadToken();
    final url = Uri.https(urlDynamic, '/app/services/coordinator/me/tours');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''},
    );
    if (response.statusCode != 200) {
      throw Exception(_readError(response, 'No se pudieron cargar las giras'));
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((item) => CoordinatorTour.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<CoordinatorTourDetail> getCoordinatorTourDetail(int tourId) async {
    final token = await _loadToken();
    final url = Uri.https(urlDynamic, '/app/services/coordinator/tours/$tourId');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''},
    );
    if (response.statusCode != 200) {
      throw Exception(_readError(response, 'No se pudo cargar la gira'));
    }
    return CoordinatorTourDetail.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<CoordinatorProfile> getCoordinatorProfile() async {
    final token = await _loadToken();
    final url = Uri.https(urlDynamic, '/app/services/coordinator/me');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''},
    );
    if (response.statusCode != 200) {
      throw Exception(_readError(response, 'No se pudo cargar el perfil'));
    }
    return CoordinatorProfile.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> changeCoordinatorPassword(
    String currentPassword,
    String newPassword,
  ) async {
    final token = await _loadToken();
    final url = Uri.https(urlDynamic, '/app/services/coordinator/me/password');
    final response = await http.post(
      url,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
      headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''},
    );
    if (response.statusCode != 200) {
      throw Exception(_readError(response, 'No se pudo cambiar la contraseña'));
    }
  }

  String _readError(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ?? decoded['error']?.toString() ?? fallback;
      }
    } catch (_) {}
    return fallback;
  }

  Future<List<TourTripulation>> getTripulation(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/tripulations', {'tourId': tourCode});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate.map((job) => new TourTripulation.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<Itinerary>> getItineray(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/binnacle', {'tourId': tourCode});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate.map((job) => new Itinerary.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<ActivitiesList>> getItinerayGuardados(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/get/create-activities', {'tourId': tourCode});
    final resp = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate.map((job) => new ActivitiesList.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> activitiesCreate(RequestActivities tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/create-activities');
    final resp = await http.post(url, body: jsonEncode(tourCode.toJson()), headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      notifyListeners();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<ConsolidatedTourSalesDTO> addHito(RequestHito tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/create-hito');
    final resp = await http.post(url, body: jsonEncode(tourCode.toJson()), headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      ConsolidatedTourSalesDTO login = new ConsolidatedTourSalesDTO.fromJson(decorespoCreate);
      notifyListeners();
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> addHitoFoto(int hito, String tourId, List<XFile> imageFiles) async {
    final token = await _loadToken();
    final uri = Uri.https(urlDynamic, '/app/services/create-hito/fotos');
    final request = http.MultipartRequest('POST', uri)
      ..fields['hitoId'] = hito.toString()
      ..fields['tourId'] = tourId;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = token;
    }
    final tmpDir = await getTemporaryDirectory();
    for (final image in imageFiles) {
      final compressedPath = '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final result = await FlutterImageCompress.compressAndGetFile(image.path, compressedPath, quality: 50, minWidth: 500, minHeight: 500, format: CompressFormat.jpeg);
      if (result == null) {
        print('No se pudo comprimir ${image.path}, enviando original');
        request.files.add(await http.MultipartFile.fromPath('images', image.path, filename: image.name));
      } else {
        request.files.add(await http.MultipartFile.fromPath('images', result.path, filename: image.name));
      }
    }
    try {
      final streamedResp = await request.send();
      final status = streamedResp.statusCode;
      final body = await streamedResp.stream.bytesToString();
      if (status == 200) {
        print('Hito fotos agregadas con éxito');
      } else {
        print('Error $status: $body');
      }
    } catch (e) {
      print('Error al enviar las fotos: $e');
    }
  }

  Future<void> deleteHito(String idHito, String idTour) async {
    final token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/delete-hito', {'idHito': idHito, 'idTour': idTour});
    try {
      final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
      if (resp.statusCode == 200) {
        print('Hito eliminado correctamente (ID: $idHito)');
      } else if (resp.statusCode == 403) {
        print('Error 403: no autorizado. Verifica el token o permisos.');
      } else {
        print('Error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      print('Error al eliminar la foto: $e');
    }
  }

  Future<DetailHitoList> getHitoComplete(String hito, String tourId) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/get/detail/create-hito', {'idTour': tourId, 'idHito': hito.toString()});
    final resp = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      Map<String, dynamic> decodedResponse = json.decode(utf8.decode(resp.bodyBytes));
      DetailHitoList login = new DetailHitoList.fromJson(decodedResponse);
      notifyListeners();
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/get/create-hito', {'tourId': tourCode});
    final resp = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate.map((job) => new ConsolidatedTourSalesDTO.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<Document>> getDocument(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/document-records', {'tourId': tourCode});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate.map((job) => new Document.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<PassengerList>> getListPassenger(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/passengers/list', {'tourId': tourCode});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate.map((job) => new PassengerList.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> downloadDocument(String folderName, String fileName, String idTour, String folder) async {
    await requestStoragePermission();
    String? token = await _loadToken();
    final url = Uri.https(urlDynamic, '/app/services/download', {'folderName': folderName, 'fileName': fileName, 'idTour': idTour, 'folder': folder});
    final response = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (fileName == "Nomina alumnos") {
      fileName = "NominaAlumnos.pdf";
    } else if (fileName == "Programa gira") {
      fileName = "ProgramaGira.pdf";
    }
    String downloadPath = await getDownloadDirectory();
    final filePath = path.join(downloadPath, fileName);
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    print('Archivo descargado en: $filePath');
  }

  Future<void> viewDocument(String folderName, String fileName, String idTour, BuildContext context, String folder) async {
    String? token = await _loadToken();
    try {
      final url = Uri.https(urlDynamic, '/app/services/view', {'folderName': folderName, 'fileName': fileName, 'idTour': idTour, 'folder': folder});
      final resp = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
      if (resp.statusCode == 200) {
        final Uint8List documentBytes = resp.bodyBytes;
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String filePath = '${appDocDir.path}/$fileName';
        final File file = File(filePath);
        await file.writeAsBytes(documentBytes);
        _showPdfDialog(filePath, context);
      } else {
        throw Exception('Error al obtener el documento: ${resp.statusCode}');
      }
    } catch (e) {
      print('Error al visualizar el documento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al visualizar el documento: $e')),
      );
    }
  }

  void _showPdfDialog(String filePath, BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Visualizador PDF'),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: PDFView(
                filePath: filePath,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: false,
                pageFling: false,
                onPageChanged: (page, total) {
                  print('Page $page of $total');
                }),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Cerrar')),
          ],
        );
      },
    );
  }

  Future<void> requestStoragePermission() async {
    PermissionStatus status = await Permission.storage.request();
    if (status.isGranted) {
      print("Permiso de almacenamiento concedido");
    } else {
      print("Permiso de almacenamiento denegado");
    }
  }

  Future<String> getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        Directory? downloadsDirectory = Directory('/storage/emulated/0/Download');
        if (await downloadsDirectory.exists()) {
          return downloadsDirectory.path;
        } else {
          Directory? appDocDir = await getExternalStorageDirectory();
          return appDocDir?.path ?? '';
        }
      } else if (Platform.isIOS) {
        Directory appSupportDir = await getApplicationDocumentsDirectory();
        String sharedPath = '${appSupportDir.path}/Downloads';
        await _ensureDirectoryExists(sharedPath);
        return sharedPath;
      }
    } catch (e) {
      print('Error al obtener el directorio de descargas: $e');
      return '';
    }
    return '';
  }

  Future<void> _ensureDirectoryExists(String path) async {
    Directory dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('Directorio creado en $path');
    } else {
      print('Directorio ya existe en $path');
    }
  }

  Future<ResponseAttorney?> validateLoginUserFather(String rut, String password) async {
    var url = Uri.https(urlDynamic, '/app/services/attorney/login', {'user': rut, 'password': password});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json'});
    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      ResponseAttorney login = ResponseAttorney.fromJson(decorespoCreate);
      return login;
    } else {
      return null;
    }
  }

  Future<ResponseAttorney?> validateLoginUserPassenger(String rut, String password) async {
    var url = Uri.https(urlDynamic, '/app/services/passenger/login', {'user': rut, 'password': password});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json'});
    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      ResponseAttorney login = ResponseAttorney.fromJson(decorespoCreate);
      return login;
    } else {
      return null;
    }
  }

  Future<bool> validateMedicalRecord(String rut) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/validate/medical-records', {'user': rut});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.body.toLowerCase() == 'true') {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> createMedicalRecord(RequestPassengerMedical medicalRecord) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/medical-records');
    print(medicalRecord.toJson());
    final resp = await http.post(url, body: jsonEncode(medicalRecord.toJson()), headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<PassengersMedicalRecordDTO> getMedicalRecord(String idTour, String idPassenger) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/get/medical-records', {'tourId': idTour, 'idPassenger': idPassenger});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      PassengersMedicalRecordDTO login = new PassengersMedicalRecordDTO.fromJson(decorespoCreate);
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<ProgramViewDto> getviewProgram(String idTour) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/get/program-view', {'tourId': idTour});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      ProgramViewDto login = new ProgramViewDto.fromJson(decorespoCreate);
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> downloadDocumentMedicalRecord(String idTour, String idPassenger, String identificacion) async {
    await requestStoragePermission();
    String? token = await _loadToken();
    String fileName = "fichamedica" + "-" + identificacion + ".pdf";
    final url = Uri.https(urlDynamic, '/app/services/get/pdf/view/medical-records', {'tourId': idTour, 'idPassenger': idPassenger, 'identificacion': identificacion});
    final response = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    String downloadPath = await getDownloadDirectory();
    final filePath = path.join(downloadPath, fileName);
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
  }

  Future<void> shareDocumentMedicalRecord(String idTour, String idPassenger, String identificacion) async {
    await requestStoragePermission();
    String? token = await _loadToken();
    String fileName = "fichamedica" + "-" + identificacion + ".pdf";
    final url = Uri.https(urlDynamic, '/app/services/get/pdf/view/medical-records', {'tourId': idTour, 'idPassenger': idPassenger, 'identificacion': identificacion});
    final response = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    String downloadPath = await getDownloadDirectory();
    final filePath = path.join(downloadPath, fileName);
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    await Share.shareXFiles([XFile(filePath)], text: 'Ficha médica adjunta');
  }

  Future<void> viewDocumentMedicalRecord(String idTour, String idPassenger, BuildContext context, String identificacion) async {
    String? token = await _loadToken();
    try {
      final url = Uri.https(urlDynamic, '/app/services/get/pdf/medical-records', {'tourId': idTour, 'idPassenger': idPassenger});
      String fileName = "fichamedica" + "-" + identificacion;
      final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
      if (resp.statusCode == 200) {
        final Uint8List documentBytes = resp.bodyBytes;
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String filePath = '${appDocDir.path}/$fileName';
        final File file = File(filePath);
        await file.writeAsBytes(documentBytes);
        _showPdfDialog(filePath, context);
      } else {
        throw Exception('Error al obtener el documento: ${resp.statusCode}');
      }
    } catch (e) {
      print('Error al visualizar el documento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al visualizar el documento: $e')),
      );
    }
  }

  Future<List<PositionMap>> positionMap(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/get/binnacle-map', {'tourId': tourCode});
    final resp = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate.map((job) => new PositionMap.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> desactivateAccount(String rut) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/desactivate/login', {'rut': rut});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      notifyListeners();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> addHitoFotoPassenger(String hito, String tourId, XFile imageFiles) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/add/fotos/passenger');
    var request = http.MultipartRequest('POST', url);
    request.fields['passengerId'] = hito.toString();
    request.fields['tourId'] = tourId.toString();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = token;
    }
    var file = await http.MultipartFile.fromPath('image', imageFiles.path, filename: imageFiles.name);
    request.files.add(file);
    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        print('Hito fotos agregadas con éxito');
      } else {
        print('Error al enviar las fotos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al enviar la solicitud: $e');
    }
  }

  Future<Responseimagepassenger> getPicturePassenger(String passenger, String tourId) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/get/fotos/passenger', {'tourId': tourId, 'passengerId': passenger.toString()});
    final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      Map<String, dynamic> decodedResponse = json.decode(utf8.decode(resp.bodyBytes));
      Responseimagepassenger login = new Responseimagepassenger.fromJson(decodedResponse);
      notifyListeners();
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<PositionCoordinator>> uniqueID(String gps) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/gps/data', {'idTour': gps.toString()});
    final resp = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      final decoded = json.decode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
      return decoded.map((item) => PositionCoordinator.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load GPS data');
    }
  }

  Future<bool> sendMedicalDataEdit(RequestPassengerMedicalEdit medical) async {
    String? token = await _loadToken();
    var url = Uri.https(urlDynamic, '/app/services/medical-records/edit');
    print(token);
    final resp = await http.post(url, body: jsonEncode(medical.toJson()), headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
    if (resp.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> updateFcmToken(String apoderadoId, String fcmToken) async {
    try {
      String? token = await _loadToken();
      var url = Uri.https(urlDynamic, '/app/services/notifications/update-fcm-token');
      final resp = await http
          .post(url, body: jsonEncode({'passengerRut': apoderadoId, 'fcmToken': fcmToken}), headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''});
      if (resp.statusCode == 200) {
        return true;
      } else {
        debugPrint('updateFcmToken failed: ${resp.statusCode} ${resp.body}');
        return false;
      }
    } catch (e) {
      debugPrint('updateFcmToken exception: $e');
      return false;
    }
  }
}
