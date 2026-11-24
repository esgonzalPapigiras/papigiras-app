import 'package:papigiras_app/utils/page_navigation.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'lab/session.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'lab/offline.dart';
import 'lab/preferences.dart';
import 'lab/location_controls.dart';
import 'lab/synthetic_location.dart';
import 'utils/fcm_utils.dart';
import 'utils/session_utils.dart';
import 'dto/TourSales.dart';
import 'dto/coordinator_session.dart';
import 'dto/responseAttorney.dart';
import 'pages/coordinator/indexCoordinator.dart';
import 'pages/coordinator/coordinatorTourSelection.dart';
import 'pages/alumns/indexpassenger.dart';
import 'pages/attorney/indexFather.dart';
import 'pages/welcome.dart';
import 'utils/LocationService.dart';
import 'runtime/api_destination.dart';
import 'notifications/push_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = LabOfflineHttpOverrides();
  if (AppEnvironment.connected) {
    // Validate the compiled destination before initializing external services.
    AppEnvironment.destination;
    try {
      await PushNotifications.initialize();
    } catch (_) {
      // Login retries registration and reports failure without blocking access.
      debugPrint(
        'No se pudieron inicializar las notificaciones. Se reintentará al iniciar sesión.',
      );
    }
  } else {
    await LabSyntheticLocation.instance.restore();
  }
  final startScreen = await determineLabStartScreen();
  runApp(PapigirasLab(startScreen: startScreen));
}

class PapigirasLab extends StatelessWidget {
  final Widget? startScreen;
  const PapigirasLab({super.key, this.startScreen});
  static final navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => LocationService(),
    child: _SessionBoundary(
      child: MaterialApp(
        title: AppEnvironment.connected ? 'PapiGiras' : 'Papigiras LAB',
        theme: ThemeData(pageTransitionsTheme: papiPageTransitions),
        locale: papiLocale,
        supportedLocales: papiSupportedLocales,
        localizationsDelegates: papiLocalizationsDelegates,
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: labMessengerKey,
        home: startScreen ?? WelcomeScreen(),
        routes: {
          'welcome': (_) => WelcomeScreen(),
          '/login': (_) => WelcomeScreen(),
        },
        builder:
            AppEnvironment.connected ||
                const bool.fromEnvironment(
                  'PILO_HIDE_LAB_BANNER',
                  defaultValue: true,
                )
            ? (_, child) => AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.dark,
                child: child ?? const SizedBox.shrink(),
              )
            : _buildLabBanner,
      ),
    ),
  );

  Widget _buildLabBanner(BuildContext context, Widget? child) => ColoredBox(
    color: const Color(0xff173f38),
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Material(
            color: const Color(0xff173f38),
            child: SizedBox(
              height: 38,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.science_outlined,
                    size: 17,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'LAB · COPIA RECUPERADA · 03/11/2026',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.route,
                      semanticLabel: 'Recorrido ficticio LAB',
                      size: 19,
                      color: Colors.white,
                    ),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const LabLocationControls(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.home_outlined,
                      semanticLabel: 'Volver al inicio LAB',
                      size: 19,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      await context.read<LocationService>().stopTracking();
                      await clearSession(await SharedPreferences.getInstance());
                      navigatorKey.currentState?.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => WelcomeScreen()),
                        (_) => false,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.restart_alt,
                      semanticLabel: 'Reiniciar sesión LAB',
                      size: 19,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      await context.read<LocationService>().stopTracking();
                      await clearSession(await SharedPreferences.getInstance());
                      navigatorKey.currentState?.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => WelcomeScreen()),
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
  );
}

class _SessionBoundary extends StatefulWidget {
  const _SessionBoundary({required this.child});
  final Widget child;
  @override
  State<_SessionBoundary> createState() => _SessionBoundaryState();
}

class _SessionBoundaryState extends State<_SessionBoundary>
    with WidgetsBindingObserver {
  Timer? _coordinatorCheck;
  int _watchRevision = 0;

  void _watchSession() async {
    final revision = ++_watchRevision;
    _coordinatorCheck?.cancel();
    final state = WidgetsBinding.instance.lifecycleState;
    if (!mounted ||
        !AppEnvironment.connected ||
        (state != null && state != AppLifecycleState.resumed))
      return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted ||
        revision != _watchRevision ||
        prefs.getString('userRole') != 'coordinator' ||
        prefs.getBool('isLoggedIn') != true)
      return;
    final service = context.read<LocationService>();
    unawaited(service.checkCoordinatorSession());
    _coordinatorCheck = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(service.checkCoordinatorSession()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _watchSession();

  @override
  void initState() {
    super.initState();
    LabSession.expired.addListener(_expired);
    if (AppEnvironment.connected) {
      WidgetsBinding.instance.addObserver(this);
      LabSession.changed.addListener(_watchSession);
      _watchSession();
    }
  }

  @override
  void dispose() {
    _coordinatorCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    LabSession.changed.removeListener(_watchSession);
    LabSession.expired.removeListener(_expired);
    super.dispose();
  }

  void _expired() {
    final generation = LabSession.generation;
    final message = LabSession.expiryMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != LabSession.generation) return;
      // Revocation has already cleared the local identity. A delayed native
      // stop must not leave private screens on display.
      unawaited(
        context.read<LocationService>().stopTracking().catchError(
          (Object _) {},
        ),
      );
      PapigirasLab.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => WelcomeScreen()),
        (_) => false,
      );
      if (message != null) {
        labMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<Widget> determineLabStartScreen() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('labSessionRevision') != LabSession.revision) {
    await LabSession.clear(prefs);
    return WelcomeScreen();
  }
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
  } catch (_) {
    await _clearPrefsSession(prefs);
    return WelcomeScreen();
  }
  final String role = prefs.getString('userRole') ?? '';
  try {
    if (role == 'coordinator') {
      final coordinatorJson = prefs.getString('coordinatorData');
      if (coordinatorJson == null) {
        await _clearPrefsSession(prefs);
        return WelcomeScreen();
      }
      final coordinator = CoordinatorLogin.fromJson(
        jsonDecode(coordinatorJson),
      );
      final loginJson = prefs.getString('loginData');
      if (loginJson == null) {
        return CoordinatorTourSelectionScreen(coordinator: coordinator);
      }
      return TravelCoordinatorDashboard(
        login: TourSales.fromJson(jsonDecode(loginJson)),
      );
    } else if (role == 'passenger') {
      final loginJson = prefs.getString('loginData');
      if (loginJson == null) return WelcomeScreen();
      final loginMap = jsonDecode(loginJson);
      return TravelPassengerDashboard(
        login: ResponseAttorney.fromJson(loginMap),
      );
    } else if (role == 'father') {
      final loginJson = prefs.getString('loginData');
      if (loginJson == null) {
        return WelcomeScreen();
      }
      final login = ResponseAttorney.fromJson(jsonDecode(loginJson));
      final passengerRut = login.passengerIdentificacion;
      if (passengerRut != null && passengerRut.isNotEmpty) {
        try {
          await FcmUtils.startForFather(
            passengerRut,
          ).timeout(const Duration(seconds: 15));
        } catch (error) {
          // Personal data and exception payloads are intentionally not logged.
        }
      }
      return TravelFatherDashboard(login: login);
    } else {
      await _clearPrefsSession(prefs);
      return WelcomeScreen();
    }
  } catch (_) {
    await _clearPrefsSession(prefs);
    return WelcomeScreen();
  }
}

Future<void> _clearPrefsSession(SharedPreferences prefs) =>
    LabSession.clear(prefs);
