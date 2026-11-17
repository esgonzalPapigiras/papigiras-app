import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
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
    final locationService =
        Provider.of<LocationService>(context, listen: false);
    await locationService.stopTracking();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('codigoGira');
    await prefs.remove('userPassword');
    await prefs.clear();
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
      backgroundColor: PapigirasColors.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PapigirasColors.soft,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: PapigirasColors.surface,
                  backgroundImage: AssetImage('assets/profile.jpg'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        login.tourTripulationNameId,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        login.tourTripulationIdentificationId,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.phone_outlined),
            title: Text(
              'Contactar Agencia',
              style: TextStyle(color: Colors.grey[800]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.phone, color: PapigirasColors.teal),
                SizedBox(width: 10),
                FaIcon(FontAwesomeIcons.whatsapp, color: PapigirasColors.teal),
              ],
            ),
            onTap: () => _sendMessage('+56932157564', 'Hola! Necesito ayuda'),
          ),
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.report_problem_outlined),
            title: Text(
              'Reportar un Problema',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onTap: () => _sendMessage('+56932157564', 'Hola! Necesito ayuda'),
          ),
          SwitchListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            secondary: const Icon(Icons.location_on_outlined),
            title: Text(
              'Ubicación en segundo plano',
              style: TextStyle(color: Colors.grey[800]),
            ),
            subtitle: Text(
              locationService.isChangingMode
                  ? 'Activando ubicación…'
                  : locationService.backgroundTrackingEnabled &&
                          locationService.backgroundServiceRunning
                      ? 'Activa: compartiendo el recorrido con los apoderados'
                      : locationService.backgroundTrackingEnabled
                          ? 'Verificando el servicio de ubicación…'
                          : 'Solo se comparte mientras la app está abierta',
              style: const TextStyle(fontSize: 12),
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
                        SnackBar(
                          content: Text(locationService.lastError!),
                          duration: const Duration(seconds: 8),
                          action: SnackBarAction(
                            label: 'CONFIGURACIÓN',
                            onPressed:
                                locationService.openRequiredLocationSettings,
                          ),
                        ),
                      );
                    }
                  },
          ),
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.logout_rounded),
            title: Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onTap:
                locationService.isChangingMode ? null : () => _logout(context),
          ),
        ],
      ),
    );
  }
}
