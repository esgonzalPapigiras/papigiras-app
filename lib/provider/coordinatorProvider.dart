import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:papigiras_app/dto/Itinerary.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'dart:convert';

import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';

class CoordinatorProviders with ChangeNotifier {
  Future<TourSales?> validateLoginUser(String tourCode) async {
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/coordinator', {'tourCode': tourCode});
    final resp = await http.post(url, headers: {
      'Content-Type':
          'application/json' // Agregar el token en la cabecera de la solicitud
    });

    LinkedHashMap<String, dynamic> decorespoCreate = json.decode(resp.body);
    TourSales login = new TourSales.fromJson(decorespoCreate);
    if (resp.statusCode == 200) {
      return login;
    } else {
      return null;
    }
  }

  Future<TourSales?> validateLoginUserFather(
      String rut, String password) async {
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/coordinator', {'rut': rut, 'password': password});
    final resp = await http.post(url, headers: {
      'Content-Type':
          'application/json' // Agregar el token en la cabecera de la solicitud
    });

    LinkedHashMap<String, dynamic> decorespoCreate = json.decode(resp.body);
    TourSales login = new TourSales.fromJson(decorespoCreate);
    if (resp.statusCode == 200) {
      return login;
    } else {
      return null;
    }
  }

  Future<TourSales?> validateLoginUserPassenger(
      String rut, String password) async {
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/coordinator', {'rut': rut, 'password': password});
    final resp = await http.post(url, headers: {
      'Content-Type':
          'application/json' // Agregar el token en la cabecera de la solicitud
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
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/tripulations', {'tourId': tourCode});
    final resp = await http.post(url, headers: {
      'Content-Type':
          'application/json' // Agregar el token en la cabecera de la solicitud
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
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/binnacle', {'tourId': tourCode});
    final resp = await http.post(url, headers: {
      'Content-Type':
          'application/json' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(resp.body);
      return decorespoCreate.map((job) => new Itinerary.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<Document>> getDocument(String tourCode) async {
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/document-records', {'tourId': tourCode});
    final resp = await http.post(url, headers: {
      'Content-Type':
          'application/json' // Agregar el token en la cabecera de la solicitud
    });
    if (resp.statusCode == 200) {
      List decorespoCreate = json.decode(resp.body);
      return decorespoCreate.map((job) => new Document.fromJson(job)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  Future<List<PassengerList>> getListPassenger(String tourCode) async {
    var url = Uri.https('ms-papigiras-app-ezkbu.ondigitalocean.app',
        '/app/services/passengers/list', {'tourId': tourCode});
    final resp = await http.post(url, headers: {
      'Content-Type':
          'application/json' // Agregar el token en la cabecera de la solicitud
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
}
