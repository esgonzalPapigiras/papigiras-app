import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:background_locator_2/background_locator.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorTourSelection.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/utils/fcm_utils.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('========== BACKGROUND FCM ==========');
  debugPrint('Message ID: ${message.messageId}');
  debugPrint('Data: ${message.data}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
  const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);
  const AndroidNotificationChannel channel = AndroidNotificationChannel('hito_channel', 'Hitos', description: 'Notificaciones de nuevos hitos', importance: Importance.high);
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
  debugPrint('FCM permission: ${settings.authorizationStatus}');
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('========== FOREGROUND FCM ==========');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');
    final notification = message.notification;
    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
          0,
          notification.title,
          notification.body,
          const NotificationDetails(
              android: AndroidNotificationDetails('hito_channel', 'Hitos', importance: Importance.max, priority: Priority.high),
              iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true)));
    }
  });
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('========== NOTIFICATION OPENED ==========');
    print(message.data);
  });
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
      final coordinator = CoordinatorLogin.fromJson(jsonDecode(coordinatorJson));
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
      return TravelPassengerDashboard(login: ResponseAttorney.fromJson(loginMap));
    } else if (role == 'father') {
      final loginJson = prefs.getString('loginData');
      if (loginJson == null) {
        return WelcomeScreen();
      }
      final login = ResponseAttorney.fromJson(jsonDecode(loginJson));
      final passengerRut = login.passengerIdentificacion;
      if (passengerRut != null && passengerRut.isNotEmpty) {
        try {
          await FcmUtils.startForFather(passengerRut).timeout(const Duration(seconds: 15));
        } catch (error) {
          debugPrint('FCM session synchronization failed: $error');
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

Future<void> _clearPrefsSession(SharedPreferences prefs) async {
  await prefs.remove('token');
  await prefs.remove('tokenExpiry');
  await prefs.remove('loginData');
  await prefs.remove('coordinatorData');
  await prefs.remove('selectedTourId');
  await prefs.remove('userRole');
  await prefs.setBool('isLoggedIn', false);
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp({super.key, required this.startScreen});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: startScreen, routes: {'welcome': (context) => WelcomeScreen()});
  }
}
