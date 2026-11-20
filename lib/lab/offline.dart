import 'dart:io';
import 'package:flutter/material.dart';

/// Guard applied before runApp. All Dart HttpClient traffic fails closed.
/// Only dedicated API/tile adapters use Dart networking. Connected builds also
/// have explicit native push, GPS, media and user-initiated contact adapters.
class LabOfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw const SocketException('Papigiras LAB: conexiones de red deshabilitadas');
  }
}

final labMessengerKey = GlobalKey<ScaffoldMessengerState>();
void labNotice(String text) {
  labMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
}
