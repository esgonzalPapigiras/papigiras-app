import 'package:flutter/material.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) =>
          LocationService(), // Proveedor del servicio de ubicación
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Material App',
      home: WelcomeScreen(), // Usa `home` en lugar de `initialRoute`
      routes: {
        'welcome': (BuildContext context) => WelcomeScreen(),
        // Define otras rutas aquí
      },
    );
  }
}
