import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';

Future<void> clearSession(SharedPreferences prefs) async {
  await prefs.remove('token');
  await prefs.remove('tokenExpiry');
  await prefs.remove('loginData');
  await prefs.remove('userRole');
  await prefs.setBool('isLoggedIn', false);
}

Future<String?> loadValidToken() async {
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('token');
  final String? tokenExpiryStr = prefs.getString('tokenExpiry');
  if (token == null || tokenExpiryStr == null) return null;
  try {
    final DateTime tokenExpiry = DateTime.parse(tokenExpiryStr);
    if (tokenExpiry.isBefore(DateTime.now())) {
      await prefs.remove('token');
      await prefs.remove('tokenExpiry');
      return null;
    }
    return token;
  } catch (_) {
    await prefs.remove('token');
    await prefs.remove('tokenExpiry');
    return null;
  }
}

Future<void> checkLoginStatus(BuildContext context, {bool replace = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String? token = await loadValidToken();
  if (!isLoggedIn || token == null) return;
  final String? loginJson = prefs.getString('loginData');
  if (loginJson == null) {
    await clearSession(prefs);
    return;
  }
  final String role = prefs.getString('userRole') ?? '';
  final dynamic loginMap = jsonDecode(loginJson);
  if (!context.mounted) return;
  try {
    Widget destination;
    if (role == 'coordinator') {
      destination = TravelCoordinatorDashboard(login: TourSales.fromJson(loginMap));
    } else if (role == 'passenger') {
      destination = TravelPassengerDashboard(login: ResponseAttorney.fromJson(loginMap));
    } else if (role == 'father') {
      destination = TravelFatherDashboard(login: ResponseAttorney.fromJson(loginMap));
    } else {
      await clearSession(prefs);
      return;
    }
    if (replace) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    }
  } catch (e) {
    debugPrint('SessionUtils: error deserializing loginData: $e');
    await clearSession(prefs);
  }
}
