// Explicit, in-memory visual QA. Never reads or replaces the saved real session.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = LabOfflineHttpOverrides();
  SharedPreferences.setMockInitialValues({});
  LabMode.useFixturesForTests(true);
  LabFixtures.reset();
  const coordinator = CoordinatorLogin(
    coordinatorId: 910001,
    rut: 'LAB-C910001',
    name: 'Valentina',
    lastname: 'Ejemplo LAB',
    mustChangePassword: false,
    token: LabFixtures.token,
  );
  final today = DateTime.now();
  final tour = TourSales.fromJson({
    ...TourSales.fromCoordinatorTour(
      coordinator: coordinator,
      tour: LabFixtures.tour,
    ).toJson(),
    'tourSalesId': 910001,
    'tourCode': 'BRC26910001A',
    'tourSalesInit': DateFormat(
      'yyyy-MM-dd',
    ).format(today.subtract(const Duration(days: 2))),
    'tourSalesFinal': DateFormat(
      'yyyy-MM-dd',
    ).format(today.add(const Duration(days: 4))),
    'nameClient': 'Colegio Horizonte LAB',
    'courseClient': '3° Medio B',
  });
  await LabSession.saveCoordinator(coordinator);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('selectedTourId', 910001);
  await prefs.setString('loginData', jsonEncode(tour.toJson()));
  await prefs.setBool('coordinatorLocationSharingEnabled', false);
  runApp(
    ChangeNotifierProvider(
      create: (_) => LocationService(),
      child: MaterialApp(
        title: 'Papigiras Pilo · Vista de prueba',
        theme: papiTheme(),
        locale: papiLocale,
        supportedLocales: papiSupportedLocales,
        localizationsDelegates: papiLocalizationsDelegates,
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: labMessengerKey,
        home: TravelCoordinatorDashboard(login: tour),
        builder: (_, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: child!,
        ),
      ),
    ),
  );
}
