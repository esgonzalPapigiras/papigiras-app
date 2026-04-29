import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

// Your app files (adjust paths if needed)
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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  print("===== PREFS DUMP IN MAIN=====");
  print("isLoggedIn: ${prefs.getBool('isLoggedIn')}");
  print("userRole: ${prefs.getString('userRole')}");
  print("token: ${prefs.getString('token')}");
  print("tokenExpiry: ${prefs.getString('tokenExpiry')}");
  print("loginData: ${prefs.getString('loginData')}");
  print("=======================");
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String? token = prefs.getString('token');
  final String? tokenExpiryStr = prefs.getString('tokenExpiry');
  // If no login flag or no token, go to Welcome
  if (!isLoggedIn || token == null || tokenExpiryStr == null) {
    return WelcomeScreen();
  }

  // Check expiry
  try {
    final tokenExpiry = DateTime.parse(tokenExpiryStr);
    if (tokenExpiry.isBefore(DateTime.now())) {
      // token expired -> clear minimal session and go to Welcome
      await prefs.remove('token');
      await prefs.remove('tokenExpiry');
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('loginData');
      await prefs.remove('userRole');
      return WelcomeScreen();
    }
  } catch (e) {
    // malformed date or something else -> fallback to Welcome
    await prefs.remove('token');
    await prefs.remove('tokenExpiry');
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('loginData');
    await prefs.remove('userRole');
    return WelcomeScreen();
  }

  final String? loginJson = prefs.getString('loginData');
  final String role = prefs.getString('userRole') ?? '';

  if (loginJson == null) return WelcomeScreen();

  final loginMap = jsonDecode(loginJson);

  if (role == 'coordinator') {
    final TourSales login = TourSales.fromJson(loginMap);
    return TravelCoordinatorDashboard(login: login);
  } else if (role == 'passenger') {
    final ResponseAttorney login = ResponseAttorney.fromJson(loginMap);
    return TravelPassengerDashboard(login: login);
  } else if (role == 'father') {
    final ResponseAttorney login = ResponseAttorney.fromJson(loginMap);
    return TravelFatherDashboard(login: login);
  } else {
    // unknown role -> clear and go to Welcome
    await prefs.remove('token');
    await prefs.remove('tokenExpiry');
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('loginData');
    await prefs.remove('userRole');
    return WelcomeScreen();
  }
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
        // add other named routes if you need them
      },
    );
  }
}
