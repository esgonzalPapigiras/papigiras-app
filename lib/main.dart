import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:background_locator_2/background_locator.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase must be initialized here so it is ready when the Apoderado
  // login screen requests the FCM token. No token is fetched here — that
  // happens only after a successful Apoderado login.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await BackgroundLocator.initialize();
  Widget startScreen = await _determineStartScreen();
  runApp(
    ChangeNotifierProvider(
      create: (context) => LocationService(),
      child: MyApp(startScreen: startScreen),
    ),
  );
}

Future<Widget> _determineStartScreen() async {
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String? token = prefs.getString('token');
  final String? tokenExpiryStr = prefs.getString('tokenExpiry');
  if (!isLoggedIn || token == null || tokenExpiryStr == null) {
    return WelcomeScreen();
  }
  try {
    final tokenExpiry = DateTime.parse(tokenExpiryStr);
    if (tokenExpiry.isBefore(DateTime.now())) {
      await _clearPrefsSession(prefs);
      return WelcomeScreen();
    }
  } catch (e) {
    await _clearPrefsSession(prefs);
    return WelcomeScreen();
  }
  final String? loginJson = prefs.getString('loginData');
  final String role = prefs.getString('userRole') ?? '';
  if (loginJson == null) return WelcomeScreen();
  final loginMap = jsonDecode(loginJson);
  try {
    if (role == 'coordinator') {
      return TravelCoordinatorDashboard(login: TourSales.fromJson(loginMap));
    } else if (role == 'passenger') {
      return TravelPassengerDashboard(
          login: ResponseAttorney.fromJson(loginMap));
    } else if (role == 'father') {
      return TravelFatherDashboard(login: ResponseAttorney.fromJson(loginMap));
    } else {
      await _clearPrefsSession(prefs);
      return WelcomeScreen();
    }
  } catch (_) {
    await _clearPrefsSession(prefs);
    return WelcomeScreen();
  }
}

Future<void> _clearPrefsSession(SharedPreferences prefs) async {
  await prefs.remove('token');
  await prefs.remove('tokenExpiry');
  await prefs.remove('loginData');
  await prefs.remove('userRole');
  await prefs.setBool('isLoggedIn', false);
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  MyApp({required this.startScreen});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Papigiras',
      debugShowCheckedModeBanner: false,
      home: startScreen,
      routes: {
        'welcome': (BuildContext context) => WelcomeScreen(),
      },
    );
  }
}
