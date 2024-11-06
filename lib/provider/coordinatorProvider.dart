import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:papigiras_app/dto/TourSales.dart';
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
}
