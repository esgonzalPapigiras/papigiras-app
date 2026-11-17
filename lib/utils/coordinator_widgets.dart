import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorTourSelection.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorProfile.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/utils/LocationService.dart';

const Color kCoordinatorTeal = Color(0xFF3AC5C9);
const String kAgencyPhone = "+56932157564";

Future<void> sendWhatsAppMessage(
    {required String phone, required String message}) async {
  final whatsappUrl =
      Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
  if (await canLaunchUrl(whatsappUrl)) {
    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    return;
  }
  final whatsappDirect = Uri.parse(
      "whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}");
  if (await canLaunchUrl(whatsappDirect)) {
    await launchUrl(whatsappDirect, mode: LaunchMode.externalApplication);
  } else {
    throw 'WhatsApp no está instalado o no puede manejar la URL';
  }
}

Future<void> logoutCoordinator(BuildContext context) async {
  final locationService = Provider.of<LocationService>(context, listen: false);
  await locationService.stopTracking();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => WelcomeScreen()), (route) => false);
}

class CoordinatorTopBar extends StatelessWidget {
  final TourSales login;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool showBackButton;
  const CoordinatorTopBar(
      {Key? key,
      required this.login,
      required this.scaffoldKey,
      this.showBackButton = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          showBackButton
              ? _buildBackButton(context)
              : const SizedBox(width: 48),
          const Spacer(),
          Image.asset('assets/logo-letras-papigiras.png', height: 36),
          const Spacer(),
          _buildMenuButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return IconButton(
      tooltip: 'Volver',
      style: IconButton.styleFrom(
        backgroundColor: PapigirasColors.soft,
        minimumSize: const Size.square(48),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 24),
      onPressed: () {
        Navigator.of(context).maybePop();
      },
    );
  }

  Widget _buildMenuButton() {
    return IconButton(
      tooltip: 'Abrir menú',
      style: IconButton.styleFrom(
        backgroundColor: PapigirasColors.soft,
        minimumSize: const Size.square(48),
      ),
      icon: const Icon(Icons.menu_rounded, size: 24),
      onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
    );
  }
}

class CoordinatorEndDrawer extends StatelessWidget {
  final TourSales login;
  const CoordinatorEndDrawer({Key? key, required this.login}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final locationService = Provider.of<LocationService>(context);
    return Drawer(
      width: math.min(360.0, MediaQuery.sizeOf(context).width - 28),
      backgroundColor: PapigirasColors.canvas,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(36)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: PapigirasColors.soft,
                  backgroundImage: AssetImage('assets/profile.jpg'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Cerrar menú',
                  style: IconButton.styleFrom(
                    backgroundColor: PapigirasColors.soft,
                  ),
                  onPressed: () => Scaffold.of(context).closeEndDrawer(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              login.tourTripulationNameId,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              login.tourTripulationIdentificationId,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _buildProfileTile(context),
            const SizedBox(height: 8),
            _buildChangeTourTile(context),
            const SizedBox(height: 8),
            _buildReportProblemTile(context),
            const SizedBox(height: 8),
            _buildLocationToggleTile(context, locationService),
            const SizedBox(height: 14),
            _buildLogoutTile(context, locationService),
          ],
        ),
      ),
    );
  }

  RoundedRectangleBorder get _tileShape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(26));

  Widget _buildProfileTile(BuildContext context) {
    return ListTile(
      tileColor: PapigirasColors.soft,
      shape: _tileShape,
      leading: const Icon(Icons.person_outline_rounded),
      title: const Text(
        'Mi perfil',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.arrow_forward_rounded, size: 20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CoordinatorProfileScreen()),
      ),
    );
  }

  Widget _buildChangeTourTile(BuildContext context) {
    return ListTile(
      tileColor: PapigirasColors.soft,
      shape: _tileShape,
      leading: const Icon(Icons.swap_horiz_rounded),
      title: const Text(
        'Cambiar gira',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(login.tourCode),
      trailing: const Icon(Icons.arrow_forward_rounded, size: 20),
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        final coordinatorJson = prefs.getString('coordinatorData');
        if (coordinatorJson == null || !context.mounted) return;
        final coordinator =
            CoordinatorLogin.fromJson(jsonDecode(coordinatorJson));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => CoordinatorTourSelectionScreen(
              coordinator: coordinator,
            ),
          ),
          (route) => false,
        );
      },
    );
  }

  Widget _buildReportProblemTile(BuildContext context) {
    return ListTile(
      tileColor: PapigirasColors.soft,
      shape: _tileShape,
      leading: const Icon(Icons.help_outline_rounded),
      title: const Text(
        'Reportar un problema',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const FaIcon(
        FontAwesomeIcons.whatsapp,
        color: PapigirasColors.teal,
        size: 20,
      ),
      onTap: () => sendWhatsAppMessage(
          phone: kAgencyPhone, message: "Hola! Necesito ayuda"),
    );
  }

  Widget _buildLocationToggleTile(
      BuildContext context, LocationService locationService) {
    return SwitchListTile(
      tileColor: PapigirasColors.soft,
      shape: _tileShape,
      secondary: const Icon(Icons.location_on_outlined),
      title: const Text(
        'Ubicación en segundo plano',
        style: TextStyle(fontWeight: FontWeight.w600),
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
                      onPressed: locationService.openRequiredLocationSettings,
                    ),
                  ),
                );
              }
            },
    );
  }

  Widget _buildLogoutTile(
      BuildContext context, LocationService locationService) {
    return ListTile(
      shape: _tileShape,
      leading: const Icon(Icons.logout_rounded),
      title: const Text('Cerrar sesión'),
      iconColor: Theme.of(context).colorScheme.error,
      textColor: Theme.of(context).colorScheme.error,
      onTap: locationService.isChangingMode
          ? null
          : () => logoutCoordinator(context),
    );
  }
}

class CoordinatorBottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? destination;
  const CoordinatorBottomButton(
      {Key? key,
      required this.icon,
      required this.label,
      required this.destination})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (destination != null) {
          Navigator.of(context).push(buildCoordinatorRoute(destination!));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Colors.teal),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.teal, fontSize: 8))
        ],
      ),
    );
  }
}

class CoordinatorBottomButtonHito extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? destination;
  const CoordinatorBottomButtonHito(
      {Key? key,
      required this.icon,
      required this.label,
      required this.destination})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (destination != null) {
          Navigator.of(context).push(buildCoordinatorRoute(destination!));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 70, color: Colors.teal),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.teal, fontSize: 8))
        ],
      ),
    );
  }
}

Route buildCoordinatorRoute(Widget destination) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 1000),
    pageBuilder: (context, animation, secondaryAnimation) => destination,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.ease;
      final tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
