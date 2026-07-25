import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/utils/LocationService.dart';

const Color kCoordinatorTeal = Color(0xFF3AC5C9);
const String kAgencyPhone = "+56932157564";

Future<void> sendWhatsAppMessage({required String phone, required String message}) async {
  final whatsappUrl = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
  if (await canLaunchUrl(whatsappUrl)) {
    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    return;
  }
  final whatsappDirect = Uri.parse("whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}");
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
  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => WelcomeScreen()), (route) => false);
}

class CoordinatorTopBar extends StatelessWidget {
  final TourSales login;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool showBackButton;
  const CoordinatorTopBar({Key? key, required this.login, required this.scaffoldKey, this.showBackButton = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
      child: Row(
        children: [
          showBackButton ? _buildBackButton(context) : const SizedBox(width: 48),
          const Spacer(),
          Image.asset('assets/logo-letras-papigiras.png', height: 50),
          const Spacer(),
          _buildMenuButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
      onPressed: () {
        Navigator.of(context).maybePop();
      },
    );
  }

  Widget _buildMenuButton() {
    return IconButton(icon: const Icon(Icons.menu, color: Colors.white, size: 30), onPressed: () => scaffoldKey.currentState?.openEndDrawer());
  }
}

class CoordinatorEndDrawer extends StatelessWidget {
  final TourSales login;
  const CoordinatorEndDrawer({Key? key, required this.login}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final locationService = Provider.of<LocationService>(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [_buildHeader(), _buildReportProblemTile(context), _buildLocationToggleTile(locationService), _buildLogoutTile(context)],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
              child: const CircleAvatar(radius: 35, backgroundImage: AssetImage('assets/profile.jpg'))),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(login.tourTripulationNameId, style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold)),
              Text(login.tourTripulationIdentificationId, style: const TextStyle(fontSize: 14, color: Colors.black)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportProblemTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.report_problem, color: Colors.teal),
      title: Text('Reportar un Problema', style: TextStyle(color: Colors.grey[800])),
      trailing: const Icon(FontAwesomeIcons.whatsapp, color: Colors.teal),
      onTap: () => sendWhatsAppMessage(phone: kAgencyPhone, message: "Hola! Necesito ayuda"),
    );
  }

  Widget _buildLocationToggleTile(LocationService locationService) {
    return SwitchListTile(
      secondary: const Icon(Icons.location_on, color: Colors.teal),
      title: Text('Ubicación en segundo plano', style: TextStyle(color: Colors.grey[800])),
      subtitle: const Text('Permite compartir tu ubicación aunque la app esté minimizada', style: TextStyle(fontSize: 12)),
      value: locationService.backgroundTrackingEnabled,
      onChanged: (value) async {
        if (value) {
          await locationService.startTracking();
        } else {
          await locationService.enableForegroundOnlyTracking();
        }
      },
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return ListTile(
        leading: const Icon(Icons.logout, color: Colors.teal),
        title: Text('Cerrar Sesión', style: TextStyle(color: Colors.grey[800])),
        onTap: () => logoutCoordinator(context));
  }
}

class CoordinatorBottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? destination;
  const CoordinatorBottomButton({Key? key, required this.icon, required this.label, required this.destination}) : super(key: key);

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
        children: [Icon(icon, size: 40, color: Colors.teal), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.teal, fontSize: 8))],
      ),
    );
  }
}

class CoordinatorBottomButtonHito extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? destination;
  const CoordinatorBottomButtonHito({Key? key, required this.icon, required this.label, required this.destination}) : super(key: key);

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
        children: [Icon(icon, size: 70, color: Colors.teal), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.teal, fontSize: 8))],
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
      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
