import 'package:papigiras_app/utils/profile_photo_avatar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/location_callback.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/runtime/contact_actions.dart';

class AppDrawerCoordinator extends StatelessWidget {
  final TourSales login;
  const AppDrawerCoordinator({Key? key, required this.login}) : super(key: key);

  Future<void> _sendMessage(String phone, String message) =>
      openWhatsAppContact(phone: phone, message: message);
  Future<void> _logout(BuildContext context) async {
    final locationService = Provider.of<LocationService>(
      context,
      listen: false,
    );
    await locationService.stopTracking();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('codigoGira');
    await prefs.remove('userPassword');
    await LabSession.clear(prefs);
    await clearPreferencesPreservingLocationStops(prefs);
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationService = Provider.of<LocationService>(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: const ProfilePhotoAvatar(radius: 35),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      login.tourTripulationNameId,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      login.tourTripulationIdentificationId,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone, color: Colors.teal),
            title: Text(
              'Contactar Agencia',
              style: TextStyle(color: Colors.grey[800]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.phone, color: Colors.teal),
                SizedBox(width: 10),
                FaIcon(FontAwesomeIcons.whatsapp, color: Colors.teal),
              ],
            ),
            onTap: () => _sendMessage(agencyPhone, 'Hola! Necesito ayuda'),
          ),
          ListTile(
            leading: const Icon(Icons.report_problem, color: Colors.teal),
            title: Text(
              'Reportar un Problema',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onTap: () => _sendMessage(agencyPhone, 'Hola! Necesito ayuda'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.location_on, color: Colors.teal),
            title: Text(
              'Simular ubicación en segundo plano',
              style: TextStyle(color: Colors.grey[800]),
            ),
            subtitle: const Text(
              'Permite compartir tu ubicación aunque la app esté minimizada',
              style: TextStyle(fontSize: 12),
            ),
            value: locationService.backgroundTrackingEnabled,
            onChanged: locationService.isChangingMode
                ? null
                : (value) async {
                    if (value) {
                      await locationService.startTracking();
                    } else {
                      await locationService.enableForegroundOnlyTracking();
                    }
                    if (context.mounted && locationService.lastError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(locationService.lastError!)),
                      );
                    }
                  },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.teal),
            title: Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onTap: locationService.isChangingMode
                ? null
                : () => _logout(context),
          ),
        ],
      ),
    );
  }
}
