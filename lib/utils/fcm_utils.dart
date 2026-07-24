import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class FcmUtils {
  static Future<void> saveTokenForFather(String apoderadoId) async {
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('FcmUtils: FCM token was null, skipping save.');
        return;
      }
      debugPrint('FcmUtils: saving token for apoderado $apoderadoId');
      await _sendTokenToBackend(apoderadoId, token);
    } catch (e) {
      debugPrint('FcmUtils: error saving token: $e');
    }
  }

  static StreamSubscription<String> listenForTokenRefresh(String apoderadoId) {
    return FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        debugPrint('FcmUtils: token refreshed for apoderado $apoderadoId');
        await _sendTokenToBackend(apoderadoId, newToken);
      },
      onError: (e) {
        debugPrint('FcmUtils: token refresh stream error: $e');
      },
    );
  }

  static Future<void> _sendTokenToBackend(String apoderadoId, String token) async {
    final provider = CoordinatorProviders();
    await provider.updateFcmToken(apoderadoId, token);
  }
}