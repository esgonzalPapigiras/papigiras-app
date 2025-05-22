import 'package:flutter/material.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';
import 'package:papigiras_app/pages/attorney/fatherWelcome.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Provider(
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Material App',
            home: WelcomeScreen(), // Usa `home` en lugar de `initialRoute`
            routes: {
          // Aquí defines las rutas adicionales
          'welcome': (BuildContext context) => WelcomeScreen(),
        }));
  }
}
