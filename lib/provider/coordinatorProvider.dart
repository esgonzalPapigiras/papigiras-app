import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/Itinerary.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ProgramViewDto.dart';
import 'package:papigiras_app/dto/RequestActivities.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/binnacleaddlist.dart';
import 'package:papigiras_app/dto/positionMap.dart';
import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/dto/requestMedicalRecord.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/utils/PDFViewer.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;

import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoordinatorProviders with ChangeNotifier {
  String? _token;

  String? get token => _token;

  CoordinatorProviders() {
    _loadToken();
  }

  // Cargar token desde SharedPreferences
  Future<String?> _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '';
    notifyListeners();
    return _token;
  }

  Future<TourSales?> validateLoginUser(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/coordinator', {'tourCode': tourCode});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });

    LinkedHashMap<String, dynamic> decorespoCreate = json.decode(resp.body);
    TourSales login = new TourSales.fromJson(decorespoCreate);
    if (resp.statusCode == 200) {
      return login;
    } else {
      return null;
    }
  }

  Future<List<TourTripulation>> getTripulation(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/tripulations', {'tourId': tourCode});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(resp.body);
      return decorespoCreate
          .map((job) => new TourTripulation.fromJson(job))
          .toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<Itinerary>> getItineray(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/binnacle', {'tourId': tourCode});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(resp.body);
      return decorespoCreate.map((job) => new Itinerary.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<ActivitiesList>> getItinerayGuardados(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/get/create-activities', {'tourId': tourCode});
    final resp = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(resp.body);
      return decorespoCreate
          .map((job) => new ActivitiesList.fromJson(job))
          .toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> activitiesCreate(RequestActivities tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/create-activities');
    final resp =
        await http.post(url, body: jsonEncode(tourCode.toJson()), headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      notifyListeners();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<ConsolidatedTourSalesDTO> addHito(RequestHito tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/create-hito');
    final resp =
        await http.post(url, body: jsonEncode(tourCode.toJson()), headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(resp.body);
      ConsolidatedTourSalesDTO login =
          new ConsolidatedTourSalesDTO.fromJson(decorespoCreate);
      notifyListeners();
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> addHitoFoto(
      int hito, String tourId, List<XFile> imageFiles) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/create-hito/fotos');

    // Crea un objeto MultipartRequest para enviar datos multipart
    var request = http.MultipartRequest('POST', url);

    // Añadir parámetros adicionales
    request.fields['hitoId'] =
        hito.toString(); // El hitoId debe ser parte del objeto hito
    request.fields['tourId'] = tourId.toString();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = token;
    } // El tourId debe ser parte del objeto hito

    // Añadir las imágenes
    for (int i = 0; i < imageFiles.length; i++) {
      var file = await http.MultipartFile.fromPath(
        'images', // Este es el nombre del campo en tu API
        imageFiles[i].path,
        filename: imageFiles[i].name,
      );
      request.files.add(file);
    }

    // Realiza la solicitud
    try {
      var response = await request.send();

      if (response.statusCode == 200) {
        print('Hito fotos agregadas con éxito');
        // Aquí puedes manejar la respuesta si es necesario
      } else {
        print('Error al enviar las fotos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al enviar la solicitud: $e');
    }
  }

  Future<DetailHitoList> getHitoComplete(String hito, String tourId) async {
    String? token = await _loadToken();
    var url = Uri.https(
        'ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/get/detail/create-hito',
        {'idTour': tourId, 'idHito': hito.toString()});
    final resp = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      Map<String, dynamic> decodedResponse =
          json.decode(utf8.decode(resp.bodyBytes));

      DetailHitoList login = new DetailHitoList.fromJson(decodedResponse);
      notifyListeners();
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/get/create-hito', {'tourId': tourCode});
    final resp = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate
          .map((job) => new ConsolidatedTourSalesDTO.fromJson(job))
          .toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<Document>> getDocument(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/document-records', {'tourId': tourCode});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate.map((job) => new Document.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<PassengerList>> getListPassenger(String tourCode) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/passengers/list', {'tourId': tourCode});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate
          .map((job) => new PassengerList.fromJson(job))
          .toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> downloadDocument(
      String folderName, String fileName, String idTour, String folder) async {
    // Solicitar permisos de almacenamiento
    await requestStoragePermission();
    String? token = await _loadToken();
    final url = Uri.https(
        'ms-papigiras-app-ezkbu.ondigitalocean.app', '/app/services/download', {
      'folderName': folderName,
      'fileName': fileName,
      'idTour': idTour,
      'folder': folder
    });

    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': token ?? ''
      // Si es necesario, puedes agregar aquí el token
      // 'Authorization': 'Bearer your_token_here',
    });

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

  Future<void> viewDocument(String folderName, String fileName, String idTour,
      BuildContext context, String folder) async {
    String? token = await _loadToken();
    try {
      final url = Uri.https(
          'ms-papigiras-app-ezkbu.ondigitalocean.app', '/app/services/view', {
        'folderName': folderName,
        'fileName': fileName,
        'idTour': idTour,
        'folder': folder
      });

      final resp = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization':
            token ?? '' // Agregar el token en la cabecera de la solicitud
      });

      if (resp.statusCode == 200) {
        final Uint8List documentBytes = resp.bodyBytes;

        // Guardar el documento temporalmente en el dispositivo
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String filePath = '${appDocDir.path}/$fileName';

        // Escribir el archivo en el dispositivo
        final File file = File(filePath);
        await file.writeAsBytes(documentBytes);

        // Mostrar el PDF en un diálogo
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
            height: 400, // Ajusta la altura según sea necesario
            child: PDFView(
              filePath: filePath,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: false,
              pageFling: false,
              onPageChanged: (page, total) {
                print('Page $page of $total');
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              child: Text('Cerrar'),
            ),
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
        // Intentar obtener el directorio de descargas predeterminado en Android
        Directory? downloadsDirectory =
            Directory('/storage/emulated/0/Download');
        if (await downloadsDirectory.exists()) {
          return downloadsDirectory.path;
        } else {
          // Usar el almacenamiento externo de la aplicación como fallback
          Directory? appDocDir = await getExternalStorageDirectory();
          return appDocDir?.path ?? '';
        }
      } else if (Platform.isIOS) {
        // Obtener el directorio de documentos en iOS
        Directory appSupportDir = await getApplicationDocumentsDirectory();

        // Crear una subcarpeta de descargas
        String sharedPath = '${appSupportDir.path}/Downloads';

        // Validar o crear el directorio
        await _ensureDirectoryExists(sharedPath);

        return sharedPath;
      }
    } catch (e) {
      // Registrar el error y retornar un directorio seguro
      print('Error al obtener el directorio de descargas: $e');
      return '';
    }
    return '';
  }

  /// Método auxiliar para asegurar que un directorio exista
  Future<void> _ensureDirectoryExists(String path) async {
    Directory dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('Directorio creado en $path');
    } else {
      print('Directorio ya existe en $path');
    }
  }

  Future<ResponseAttorney?> validateLoginUserFather(
      String rut, String password) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/attorney/login', {'user': rut, 'password': password});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });

    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(resp.body);
      ResponseAttorney login = new ResponseAttorney.fromJson(decorespoCreate);
      return login;
    } else {
      return null;
    }
  }

  Future<ResponseAttorney?> validateLoginUserPassenger(
      String rut, String password) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/passenger/login', {'user': rut, 'password': password});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });

    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(resp.body);
      ResponseAttorney login = new ResponseAttorney.fromJson(decorespoCreate);
      return login;
    } else {
      return null;
    }
  }

  Future<bool> validateMedicalRecord(String rut) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/validate/medical-records', {'user': rut});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.body.toLowerCase() == 'true') {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> createMedicalRecord(
      RequestPassengerMedical medicalRecord) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/medical-records');
    print(medicalRecord.toJson());
    final resp = await http
        .post(url, body: jsonEncode(medicalRecord.toJson()), headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });

    if (resp.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<PassengersMedicalRecordDTO> getMedicalRecord(
      String idTour, String idPassenger) async {
    String? token = await _loadToken();
    var url = Uri.https(
        'ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/get/medical-records',
        {'tourId': idTour, 'idPassenger': idPassenger});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });

    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(resp.body);
      PassengersMedicalRecordDTO login =
          new PassengersMedicalRecordDTO.fromJson(decorespoCreate);
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<ProgramViewDto> getviewProgram(String idTour) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/get/program-view', {'tourId': idTour});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });

    if (resp.statusCode == 200) {
      LinkedHashMap<String, dynamic> decorespoCreate = json.decode(resp.body);
      ProgramViewDto login = new ProgramViewDto.fromJson(decorespoCreate);
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> downloadDocumentMedicalRecord(
      String idTour, String idPassenger, String identificacion) async {
    // Solicitar permisos de almacenamiento
    await requestStoragePermission();
    String? token = await _loadToken();
    String fileName = "fichamedica" + "-" + identificacion + ".pdf";

    final url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/get/pdf/view/medical-records', {
      'idTour': idTour,
      'folder': idPassenger,
      'identificacion': identificacion
    });

    final response = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': token ?? ''
      // Si es necesario, puedes agregar aquí el token
      // 'Authorization': 'Bearer your_token_here',
    });

    print('Content-Type: ${response.headers['content-type']}');

    String downloadPath = await getDownloadDirectory();
    final filePath = path.join(downloadPath, fileName);
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    print('Archivo descargado en: $filePath');
  }

  Future<void> viewDocumentMedicalRecord(String idTour, String idPassenger,
      BuildContext context, String identificacion) async {
    String? token = await _loadToken();
    try {
      final url = Uri.https(
          'ms-papigiras-app-ezkbu.ondigitalocean.app',
          '/app/services/get/pdf/medical-records',
          {'tourId': idTour, 'idPassenger': idPassenger});

      String fileName = "fichamedica" + "-" + identificacion;

      final resp = await http.post(url, headers: {
        'Content-Type': 'application/json',
        'Authorization':
            token ?? '' // Agregar el token en la cabecera de la solicitud
      });

      if (resp.statusCode == 200) {
        final Uint8List documentBytes = resp.bodyBytes;

        // Guardar el documento temporalmente en el dispositivo
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String filePath = '${appDocDir.path}/$fileName';

        // Escribir el archivo en el dispositivo
        final File file = File(filePath);
        await file.writeAsBytes(documentBytes);

        // Mostrar el PDF en un diálogo
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
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/get/binnacle-map', {'tourId': tourCode});
    final resp = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(utf8.decode(resp.bodyBytes));
      return decorespoCreate
          .map((job) => new PositionMap.fromJson(job))
          .toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> desactivateAccount(String rut) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/desactivate/login', {'rut': rut});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      notifyListeners();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<void> addHitoFotoPassenger(
      String hito, String tourId, XFile imageFiles) async {
    String? token = await _loadToken();
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/add/fotos/passenger');

    // Crea un objeto MultipartRequest para enviar datos multipart
    var request = http.MultipartRequest('POST', url);

    // Añadir parámetros adicionales
    request.fields['passengerId'] =
        hito.toString(); // El hitoId debe ser parte del objeto hito
    request.fields['tourId'] = tourId.toString();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = token;
    } // El tourId debe ser parte del objeto hito

    var file = await http.MultipartFile.fromPath(
      'image', // Este es el nombre del campo en tu API
      imageFiles.path,
      filename: imageFiles.name,
    );
    request.files.add(file);

    // Realiza la solicitud
    try {
      var response = await request.send();

      if (response.statusCode == 200) {
        print('Hito fotos agregadas con éxito');
        // Aquí puedes manejar la respuesta si es necesario
      } else {
        print('Error al enviar las fotos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al enviar la solicitud: $e');
    }
  }

  Future<Responseimagepassenger> getPicturePassenger(
      String passenger, String tourId) async {
    String? token = await _loadToken();
    var url = Uri.https(
        'ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/get/fotos/passenger',
        {'tourId': tourId, 'passengerId': passenger.toString()});
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization':
          token ?? '' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      Map<String, dynamic> decodedResponse =
          json.decode(utf8.decode(resp.bodyBytes));

      Responseimagepassenger login =
          new Responseimagepassenger.fromJson(decodedResponse);

      notifyListeners();
      return login;
    } else {
      throw Exception('Failed to load services');
    }
  }
}
