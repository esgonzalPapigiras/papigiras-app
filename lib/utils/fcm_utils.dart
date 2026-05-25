import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

/// Handles all FCM token logic for the Apoderado role.
/// Usage after a successful father login:
///   await FcmUtils.saveTokenForFather(apoderadoId);
/// Usage in fatherWelcome initState:
///   _refreshSubscription = FcmUtils.listenForTokenRefresh(apoderadoId);
/// Cancel the subscription in dispose:
///   _refreshSubscription?.cancel();
class FcmUtils {
  /// Gets the current FCM token and sends it to the backend,
  /// associated with [apoderadoId].
  /// Should be called once right after a successful Apoderado login.
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
      // Never crash the login flow because of FCM
      debugPrint('FcmUtils: error saving token: $e');
    }
  }

  /// Subscribes to Firebase token-refresh events.
  /// Whenever Firebase issues a new token (e.g. after app reinstall or
  /// iOS token rotation), the new token is automatically sent to the backend.
  ///
  /// Returns the [StreamSubscription] — call cancel() on it in dispose().
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

  /// Sends [token] to the Spring Boot backend for the given [apoderadoId].
  static Future<void> _sendTokenToBackend(
      String apoderadoId, String token) async {
    final provider = CoordinatorProviders();
    await provider.updateFcmToken(apoderadoId, token);
  }
}
