import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDrawerCoordinator extends StatelessWidget {
  final TourSales login;
  const AppDrawerCoordinator({
    Key? key,
    required this.login,
  }) : super(key: key);

  Future<void> _sendMessage(String phone, String message) async {
    final whatsappUrl =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      return;
    }
    final direct = Uri.parse(
        'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(direct)) {
      await launchUrl(direct, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('codigoGira');
    await prefs.remove('userPassword');
    await prefs.clear();
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
                  child: const CircleAvatar(
                    radius: 35,
                    backgroundImage: AssetImage('assets/profile.jpg'),
                  ),
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
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
                Icon(FontAwesomeIcons.whatsapp, color: Colors.teal),
              ],
            ),
            onTap: () => _sendMessage('+56932157564', 'Hola! Necesito ayuda'),
          ),
          ListTile(
            leading: const Icon(Icons.report_problem, color: Colors.teal),
            title: Text(
              'Reportar un Problema',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onTap: () => _sendMessage('+56932157564', 'Hola! Necesito ayuda'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.location_on, color: Colors.teal),
            title: Text(
              'Ubicación en segundo plano',
              style: TextStyle(color: Colors.grey[800]),
            ),
            subtitle: const Text(
              'Permite compartir tu ubicación aunque la app esté minimizada',
              style: TextStyle(fontSize: 12),
            ),
            value: locationService.isTracking,
            onChanged: (value) async {
              if (value) {
                await locationService.startTracking();
              } else {
                await locationService.stopTracking();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.teal),
            title: Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
