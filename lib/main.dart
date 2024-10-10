import 'package:flutter/material.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';
import 'package:papigiras_app/pages/attorney/fatherWelcome.dart';
import 'package:papigiras_app/pages/binnacle.dart';
import 'package:papigiras_app/pages/index.dart';
import 'package:papigiras_app/pages/login.dart';
import 'package:papigiras_app/pages/tripulationbus.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Provider(
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Material App',
            initialRoute: 'welcome',
            routes: {
          'welcome': (BuildContext context) => WelcomeScreen(),
          'login': (BuildContext context) => LoginScreen(),
          'dashboardTour': (BuildContext context) => TravelDashboard(),
          'welcomeFather': (BuildContext context) => WelcomeFatherScreen(),
          'medicalRecords': (BuildContext context) => MedicalRecordScreen(),
          'busCrewScreen': (BuildContext context) => BusCrewScreen(),
          'bitacoraScreen': (BuildContext context) => BitacoraScreen()
        }));
  }
}
