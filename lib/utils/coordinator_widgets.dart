import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/runtime/contact_actions.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/navigation/family_navigation.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorProfile.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorTourSelection.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/ranking/coordinator_ranking_screen.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/location_callback.dart';
import 'package:papigiras_app/utils/page_navigation.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';
import 'package:provider/provider.dart';

const Color kCoordinatorTeal = Color(0xFF3AC5C9);
const String kAgencyPhone = agencyPhone;

Future<void> sendWhatsAppMessage({
  required String phone,
  required String message,
}) => openWhatsAppContact(phone: phone, message: message);
Future<void> logoutCoordinator(BuildContext context) async {
  await context.read<LocationService>().stopTracking();
  final prefs = await SharedPreferences.getInstance();
  await LabSession.clear(prefs);
  await clearPreferencesPreservingLocationStops(prefs);
  if (!context.mounted) return;
  _sessionNavigator(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => WelcomeScreen()),
    (route) => false,
  );
}

NavigatorState _sessionNavigator(BuildContext context) =>
    FamilyNavigationScope.maybeOf(context)?.sessionNavigator ??
    Navigator.of(context);

void backCoordinatorPage(BuildContext context) {
  final navigation = FamilyNavigationScope.maybeOf(context);
  if (navigation != null) {
    navigation.back();
  } else {
    Navigator.of(context).maybePop();
  }
}

class CoordinatorTopBar extends StatelessWidget {
  const CoordinatorTopBar({
    super.key,
    required this.login,
    required this.scaffoldKey,
    this.showBackButton = true,
    this.title,
    this.subtitle,
  });

  final TourSales login;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool showBackButton;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final back = showBackButton ? () => backCoordinatorPage(context) : null;
    final menu = IconButton(
      tooltip: 'Abrir menú',
      onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
      icon: const Icon(Icons.menu_rounded, size: 24),
    );
    if (title case final sectionTitle?) {
      return ColoredBox(
        color: PiloFamilyTheme.paper,
        child: PiloSectionBar(
          title: sectionTitle,
          subtitle: subtitle,
          onBack: back,
          actions: [menu],
        ),
      );
    }
    return ColoredBox(
      color: PiloFamilyTheme.paper,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              if (back != null)
                IconButton(
                  tooltip: 'Volver',
                  style: IconButton.styleFrom(
                    backgroundColor: PiloFamilyTheme.soft,
                    minimumSize: const Size.square(48),
                  ),
                  onPressed: back,
                  icon: const Icon(Icons.arrow_back_rounded, size: 24),
                ),
              const Spacer(),
              menu,
            ],
          ),
        ),
      ),
    );
  }
}

class CoordinatorEndDrawer extends StatelessWidget {
  const CoordinatorEndDrawer({super.key, required this.login});

  final TourSales login;

  @override
  Widget build(BuildContext context) {
    final locationService = context.watch<LocationService>();
    final text = Theme.of(context).textTheme;
    return Drawer(
      width: math.min(360.0, MediaQuery.sizeOf(context).width - 28),
      backgroundColor: PiloFamilyTheme.paper,
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
                ProfilePhotoAvatar(
                  radius: 36,
                  onOpenProfile: () => _openProfile(context),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Cerrar menú',
                  style: IconButton.styleFrom(
                    backgroundColor: PiloFamilyTheme.soft,
                  ),
                  onPressed: () => Scaffold.of(context).closeEndDrawer(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _openProfile(context),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatStudentName(login.tourTripulationNameId, null),
                      style: PiloFamilyTheme.display(30),
                    ),
                    Text(
                      login.tourTripulationIdentificationId,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _item(
              'Mi perfil',
              Icons.person_outline_rounded,
              () => _openProfile(context),
            ),
            const SizedBox(height: 8),
            _item(
              'Ranking de temporada',
              Icons.emoji_events_outlined,
              () => _openRanking(context),
            ),
            const SizedBox(height: 8),
            _item(
              'Cambiar gira',
              Icons.swap_horiz_rounded,
              () => _changeTour(context),
              subtitle: login.tourCode,
            ),
            const SizedBox(height: 8),
            _item(
              'Reportar un problema',
              Icons.help_outline_rounded,
              () => sendWhatsAppMessage(
                phone: kAgencyPhone,
                message: 'Hola! Necesito ayuda',
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Cerrar sesión'),
              iconColor: Theme.of(context).colorScheme.error,
              textColor: Theme.of(context).colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              onTap: locationService.isChangingMode
                  ? null
                  : () => logoutCoordinator(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    String label,
    IconData icon,
    VoidCallback onTap, {
    String? subtitle,
  }) {
    return Material(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: PiloFamilyTheme.ink),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null || subtitle.isEmpty ? null : Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_rounded,
          size: 20,
          color: PiloFamilyTheme.ink,
        ),
        onTap: onTap,
      ),
    );
  }

  void _openProfile(BuildContext context) {
    final navigator = _sessionNavigator(context);
    final profile = InheritedTheme.captureAll(
      context,
      const CoordinatorProfileScreen(),
    );
    Scaffold.of(context).closeEndDrawer();
    navigator.push(buildPapiRoute(profile));
  }

  void _openRanking(BuildContext context) {
    final navigator = _sessionNavigator(context);
    final ranking = InheritedTheme.captureAll(
      context,
      CoordinatorRankingScreen(
        initialSeason: login.seasonClient > 0 ? login.seasonClient : null,
        currentCoordinatorId: login.coordinatorId,
      ),
    );
    Scaffold.of(context).closeEndDrawer();
    navigator.push(buildPapiRoute(ranking));
  }

  Future<void> _changeTour(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final coordinatorJson = prefs.getString('coordinatorData');
    if (coordinatorJson == null || !context.mounted) return;
    final coordinator = CoordinatorLogin.fromJson(jsonDecode(coordinatorJson));
    final navigator = _sessionNavigator(context);
    Scaffold.of(context).closeEndDrawer();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            CoordinatorTourSelectionScreen(coordinator: coordinator),
      ),
      (route) => false,
    );
  }
}

class CoordinatorBottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? destination;
  const CoordinatorBottomButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.destination,
  }) : super(key: key);

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
          Text(label, style: const TextStyle(color: Colors.teal, fontSize: 8)),
        ],
      ),
    );
  }
}

class CoordinatorBottomButtonHito extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? destination;
  const CoordinatorBottomButtonHito({
    Key? key,
    required this.icon,
    required this.label,
    required this.destination,
  }) : super(key: key);

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
          Text(label, style: const TextStyle(color: Colors.teal, fontSize: 8)),
        ],
      ),
    );
  }
}

Route buildCoordinatorRoute(Widget destination) => buildPapiRoute(destination);
