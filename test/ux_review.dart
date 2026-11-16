// Explicit visual review harness. No credentials or real database are read.
// Run: flutter run --no-pub -t test/ux_review.dart -d <LAB simulator>
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorTourSelection.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'support/ux_demo_images.dart';

final uxReviewNavigator = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = LabOfflineHttpOverrides();
  SharedPreferences.setMockInitialValues({});
  LabMode.useFixturesForTests(true);
  LabFixtures.reset();
  LabFixtures.hitos = [
    _hito(
      101,
      'Encuentro en la plaza',
      'Nos reunimos para comenzar el recorrido por la ciudad.',
      'Plaza de Armas',
      '09:00',
      '-33.4372',
      '-70.6506',
    ),
    _hito(
      102,
      'Una pausa en el camino',
      'Compartimos una colación antes de continuar el paseo.',
      'Cerro Santa Lucía',
      '11:00',
      '-33.4403',
      '-70.6433',
    ),
    _hito(
      103,
      'Recorrido por el parque',
      'Una tarde para caminar junto a la laguna y conocer el entorno del parque.',
      'Parque Bicentenario',
      '15:00',
      '-33.3998',
      '-70.6021',
    ),
  ];
  LabFixtures.photos[101] = [uxCityPhoto];
  LabFixtures.photos[103] = [uxLagoonPhoto, uxParkPhoto];
  LabFixtures.medical[1] = LabFixtures.defaultMedical(1);
  runApp(const UxReviewApp());
}

ConsolidatedTourSalesDTO _hito(
  int id,
  String title,
  String description,
  String place,
  String time,
  String lat,
  String lon,
) => ConsolidatedTourSalesDTO(
  binnacleDetailId: id,
  binnacleTitulo: title,
  binnacleDescripcion: description,
  binnacleUbicacion: place,
  binnacleNotaCierre: '',
  binnacleLatitud: lat,
  binnacleLongitud: lon,
  binnacleHora: time,
  binnacleFecha: '2026-11-03',
  author: const HitoAuthor(
    coordinatorId: 1,
    name: 'Coordinador',
    lastname: 'Demo',
  ),
  canModify: true,
);

class UxReviewApp extends StatelessWidget {
  const UxReviewApp({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => LocationService(),
    child: MaterialApp(
      title: 'Papigiras LAB · Revisión UX',
      theme: papiTheme(),
      locale: papiLocale,
      supportedLocales: papiSupportedLocales,
      localizationsDelegates: papiLocalizationsDelegates,
      debugShowCheckedModeBanner: false,
      navigatorKey: uxReviewNavigator,
      scaffoldMessengerKey: labMessengerKey,
      home: const _ReviewRoles(),
      routes: {
        '/login': (_) => const _ReviewRoles(),
        'welcome': (_) => const _ReviewRoles(),
      },
      builder: (context, child) => ColoredBox(
        color: PapiColors.ink,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Material(
                color: PapiColors.ink,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.science_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'LAB · REVISIÓN UX · DATOS FICTICIOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.grid_view_rounded,
                          semanticLabel: 'Elegir rol de prueba',
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          await context.read<LocationService>().stopTracking();
                          await LabSession.clear(
                            await SharedPreferences.getInstance(),
                          );
                          uxReviewNavigator.currentState?.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const _ReviewRoles(),
                            ),
                            (_) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReviewRoles extends StatelessWidget {
  const _ReviewRoles();
  Future<void> _open(BuildContext context, String role) async {
    final Widget next;
    if (role == 'coordinator') {
      await LabSession.saveCoordinator(LabFixtures.coordinator);
      next = const CoordinatorTourSelectionScreen(
        coordinator: LabFixtures.coordinator,
      );
    } else {
      await LabSession.savePassenger(LabFixtures.passenger, role);
      next = role == 'attorney'
          ? TravelFatherDashboard(login: LabFixtures.passenger)
          : TravelPassengerDashboard(login: LabFixtures.passenger);
    }
    if (context.mounted)
      Navigator.push(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Image.asset(
            'assets/logo-letras-papigiras.png',
            height: 50,
            alignment: Alignment.centerLeft,
            semanticLabel: 'PapiGiras',
          ),
          const SizedBox(height: 40),
          Text(
            'El viaje,\nmás cerca.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Prueba el rediseño con perfiles y fotografías ficticios.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: PapiColors.muted),
          ),
          const SizedBox(height: 28),
          PapiActionRow(
            title: 'Apoderado',
            icon: Icons.favorite_border,
            onTap: () => _open(context, 'attorney'),
          ),
          const Divider(),
          PapiActionRow(
            title: 'Alumno',
            icon: Icons.backpack_outlined,
            onTap: () => _open(context, 'passenger'),
          ),
          const Divider(),
          PapiActionRow(
            title: 'Coordinador',
            icon: Icons.badge_outlined,
            onTap: () => _open(context, 'coordinator'),
          ),
        ],
      ),
    ),
  );
}
