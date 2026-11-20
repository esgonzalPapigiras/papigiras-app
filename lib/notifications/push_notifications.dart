import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import '../lab/preferences.dart';
import 'attorney_push_registration.dart';

@pragma('vm:entry-point')
Future<void> papigirasBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Firebase/APNs displays background messages. Do not duplicate them or log
  // potentially personal notification contents.
}

abstract final class PushNotifications {
  static final _local = FlutterLocalNotificationsPlugin();
  static Future<void>? _initializing;
  static StreamSubscription<RemoteMessage>? _foreground;

  static Future<void> initialize() => _initializing ??= _initialize()
      .catchError((Object error, StackTrace stack) {
        _initializing = null;
        Error.throwWithStackTrace(error, stack);
      });

  static Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    FirebaseMessaging.onBackgroundMessage(papigirasBackgroundMessage);
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'hito_channel',
            'Hitos',
            description: 'Notificaciones de nuevos hitos',
            importance: Importance.high,
          ),
        );
    // One foreground presentation path prevents duplicate alerts on iOS.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
    await _foreground?.cancel();
    _foreground = FirebaseMessaging.onMessage.listen((message) async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('isLoggedIn') != true ||
          prefs.getString('userRole') != 'father')
        return;
      final notification = message.notification;
      if (notification == null) return;
      await _local.show(
        (message.messageId ?? message.sentTime?.toIso8601String() ?? '')
                .hashCode &
            0x7fffffff,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hito_channel',
            'Hitos',
            icon: '@mipmap/launcher_icon',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    });
  }
}

class FirebasePushTokenSource implements PushTokenSource {
  @override
  Stream<String> get refreshedTokens =>
      FirebaseMessaging.instance.onTokenRefresh;
  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();
  @override
  Future<void> deleteToken() => FirebaseMessaging.instance.deleteToken();

  @override
  Future<void> prepare() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw StateError(
        'Las notificaciones no están autorizadas en este dispositivo.',
      );
    }
    if (!Platform.isIOS) return;
    // Preserve the official APNs-before-FCM ordering on physical iPhones.
    for (var attempt = 0; attempt < 20; attempt++) {
      final token = await FirebaseMessaging.instance.getAPNSToken();
      if (token != null && token.isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException(
      'APNs no entregó un token.',
      const Duration(seconds: 10),
    );
  }
}
