import 'dart:io';
import 'package:flutter/material.dart';

/// Guard applied before runApp. All Dart HttpClient traffic fails closed.
/// Only the dedicated allow-listed public tile and localhost LAB API adapters have network capabilities.
/// LAB has no native network, push, GPS or URL-launcher plugins.
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

enum LaunchMode { externalApplication, platformDefault }
Future<bool> canLaunchUrl(Uri uri) async => true;
Future<bool> launchUrl(Uri uri, {LaunchMode? mode}) async {
  labNotice('LAB: contacto simulado. No se abrió ninguna aplicación externa.');
  return true;
}
