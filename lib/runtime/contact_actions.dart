import 'package:url_launcher/url_launcher.dart' as native;

import '../lab/offline.dart' show labNotice;
import 'api_destination.dart';

// Existing agency contact from the official app (a20d994).
const agencyPhone = '+56932157564';

typedef ContactLauncher = Future<bool> Function(Uri uri);

/// Opens a prepared conversation only. The user sends the message in WhatsApp.
class WhatsAppContact {
  const WhatsAppContact({required this.connected, required this.launch});

  final bool connected;
  final ContactLauncher launch;

  Future<bool> open(String phone, String message) async {
    if (!connected) {
      labNotice(
        'LAB: contacto simulado. No se abrió ninguna aplicación externa.',
      );
      return true;
    }
    // Accept display punctuation, never arbitrary URLs or embedded parameters.
    final trimmed = phone.trim();
    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(trimmed)) return false;
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(digits)) return false;
    final query = 'phone=$digits&text=${Uri.encodeComponent(message)}';
    final urls = [
      Uri(scheme: 'whatsapp', host: 'send', query: query),
      Uri.https('wa.me', '/$digits', {'text': message}),
    ];
    for (final uri in urls) {
      try {
        if (await launch(uri)) return true;
      } catch (_) {
        // Unsupported scheme/platform: try the HTTPS conversation fallback.
      }
    }
    return false;
  }
}

Future<void> openWhatsAppContact({
  required String phone,
  required String message,
}) async {
  final opened = await WhatsAppContact(
    connected: AppEnvironment.connected,
    launch: (uri) =>
        native.launchUrl(uri, mode: native.LaunchMode.externalApplication),
  ).open(phone, message);
  if (!opened) {
    labNotice('No pudimos abrir el contacto. Inténtalo de nuevo.');
  }
}
