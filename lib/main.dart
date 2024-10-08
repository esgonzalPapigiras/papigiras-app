import 'package:flutter/material.dart';
import 'package:papigiras_app/pages/index.dart';
import 'package:papigiras_app/pages/login.dart';
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
        }));
  }
}
