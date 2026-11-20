import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../lab/api_http.dart';
import '../lab/mode.dart';
import '../lab/preferences.dart';
import '../lab/session.dart';
import '../notifications/attorney_push_registration.dart';
import '../notifications/push_notifications.dart';
import '../runtime/api_destination.dart';

class FcmUtils {
  static AttorneyPushRegistration? _registration;

  static Future<void> startForFather(String passengerRut) async {
    if (!AppEnvironment.connected || LabMode.fixturesForTests) return;
    final prefs = await SharedPreferences.getInstance();
    final generation = LabSession.generation;
    final authorization = prefs.getString('token');
    bool current() =>
        generation == LabSession.generation &&
        prefs.getBool('isLoggedIn') == true &&
        prefs.getString('userRole') == 'father' &&
        authorization != null &&
        authorization.isNotEmpty &&
        prefs.getString('token') == authorization;
    if (!current()) return;
    await PushNotifications.initialize();
    if (!current()) return;
    _registration ??= AttorneyPushRegistration(
      FirebasePushTokenSource(),
      onError: (error, stack) {
        // Do not include token, RUT, server response or notification contents.
        debugPrint(
          'No se pudo actualizar el registro de notificaciones (${error.runtimeType}).',
        );
      },
    );
    await _registration!.start(
      sessionIsCurrent: current,
      register: (token) async {
        if (!current()) return;
        final client = LabApiClient();
        try {
          await client.post(
            LabApi.uri('/app/services/notifications/update-fcm-token'),
            headers: {
              'authorization': authorization!,
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'passengerRut': passengerRut,
              'fcmToken': token,
              'deviceType': Platform.operatingSystem,
            }),
          );
        } finally {
          client.close();
        }
      },
    );
  }

  static Future<void> stop() async {
    await _registration?.stop();
  }
}
