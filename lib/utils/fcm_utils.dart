import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class FcmUtils {
  static StreamSubscription<String>? _tokenSubscription;

  static Future<void> startForFather(String passengerRut) async {
    await _tokenSubscription?.cancel();

    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        try {
          await _sendTokenToBackend(passengerRut, token);
        } catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              context: ErrorDescription('uploading refreshed FCM token'),
            ),
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            context: ErrorDescription('listening for FCM token refresh'),
          ),
        );
      },
    );

    await saveTokenForFather(passengerRut);
  }

  static Future<void> saveTokenForFather(String passengerRut) async {
    if (Platform.isIOS) {
      await _waitForApnsToken();
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Firebase did not return an FCM token');
    }

    await _sendTokenToBackend(passengerRut, token);
  }

  static Future<void> stop() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }

  static Future<void> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();

      if (apnsToken != null && apnsToken.isNotEmpty) {
        return;
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );
    }

    throw TimeoutException(
      'APNs token was not available',
      const Duration(seconds: 10),
    );
  }

  static Future<void> _sendTokenToBackend(
    String passengerRut,
    String token,
  ) async {
    await CoordinatorProviders().updateFcmToken(
      passengerRut,
      token,
      Platform.operatingSystem,
    );
  }
}
