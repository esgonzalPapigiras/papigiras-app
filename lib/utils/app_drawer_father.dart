import 'package:papigiras_app/lab/session.dart';
import '../navigation/family_navigation.dart';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/design/apple_design_trial.dart';
import 'package:papigiras_app/auth/saved_credentials.dart';
import 'package:papigiras_app/design/pilo_change_password_sheet.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/runtime/contact_actions.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';

class AppDrawerFather extends StatelessWidget {
  final ResponseAttorney login;
  final bool allowPasswordChange;
  final XFile? imageFile;
  final String? imageUrl;
  @visibleForTesting
  final CoordinatorProviders? photoProvider;
  @visibleForTesting
  final CoordinatorProviders? passwordProvider;
  @visibleForTesting
  final Future<XFile?> Function()? pickImage;

  const AppDrawerFather({
    super.key,
    required this.login,
    this.allowPasswordChange = true,
    this.imageFile,
    this.imageUrl,
    this.photoProvider,
    this.passwordProvider,
    this.pickImage,
  });

  /// The Pilo home menu uses a modal sheet. Resolve the destination after the
  /// menu closes so switching family sections never leaves an old popup open.
  static Future<void> showPiloSheet(
    BuildContext context, {
    required ResponseAttorney login,
    required VoidCallback onTripDetails,
    required VoidCallback onMedical,
    required VoidCallback onDocuments,
    required VoidCallback onCrew,
    CoordinatorProviders? photoProvider,
    CoordinatorProviders? passwordProvider,
    Future<XFile?> Function()? pickImage,
  }) async {
    final menu = AppDrawerFather(
      login: login,
      photoProvider: photoProvider,
      passwordProvider: passwordProvider,
      pickImage: pickImage,
    );
    final action = await showModalBottomSheet<_PiloFamilyMenuAction>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: PiloFamilyTheme.paper,
      barrierColor: PiloFamilyTheme.ink.withValues(alpha: .34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => _PiloMenuSheet(
        title: 'Tu gira',
        sheetKey: const ValueKey('pilo-family-menu-sheet'),
        children: [
          for (final item in const [
            (
              _PiloFamilyMenuAction.trip,
              'Datos gira',
              Icons.work_outline_rounded,
            ),
            (
              _PiloFamilyMenuAction.medical,
              'Ficha médica',
              Icons.medical_information_outlined,
            ),
            (
              _PiloFamilyMenuAction.documents,
              'Documentos',
              Icons.description_outlined,
            ),
            (
              _PiloFamilyMenuAction.crew,
              'Tripulación',
              Icons.people_outline_rounded,
            ),
            (
              _PiloFamilyMenuAction.profile,
              'Perfil del estudiante',
              Icons.person_outline_rounded,
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PiloMenuRow(
                key: ValueKey('pilo-family-menu-${item.$1.name}'),
                label: item.$2,
                icon: item.$3,
                onTap: () => Navigator.of(sheetContext).pop(item.$1),
              ),
            ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case _PiloFamilyMenuAction.trip:
        onTripDetails();
      case _PiloFamilyMenuAction.medical:
        onMedical();
      case _PiloFamilyMenuAction.documents:
        onDocuments();
      case _PiloFamilyMenuAction.crew:
        onCrew();
      case _PiloFamilyMenuAction.profile:
        await menu._showPiloProfileSheet(context);
      case null:
        break;
    }
  }

  /// Student identity/actions share the Pilo profile sheet without exposing
  /// guardian destinations or guardian password changes.
  static Future<void> showPiloStudentProfileSheet(
    BuildContext context, {
    required ResponseAttorney login,
    CoordinatorProviders? photoProvider,
  }) => AppDrawerFather(
    login: login,
    allowPasswordChange: false,
    photoProvider: photoProvider,
  )._showPiloProfileSheet(context);

  Future<void> _showPiloProfileSheet(BuildContext origin) =>
      showModalBottomSheet<void>(
        context: origin,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: PiloFamilyTheme.paper,
        barrierColor: PiloFamilyTheme.ink.withValues(alpha: .34),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        clipBehavior: Clip.antiAlias,
        builder: (context) => _PiloMenuSheet(
          title: 'Perfil del estudiante',
          sheetKey: const ValueKey('pilo-family-profile-sheet'),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _profile(context),
            ),
            if (allowPasswordChange) ...[
              _PiloMenuRow(
                key: const ValueKey('family-menu-password'),
                label: 'Cambiar contraseña',
                icon: Icons.lock_outline_rounded,
                onTap: () => _changePassword(context),
              ),
              const SizedBox(height: 8),
            ],
            _PiloMenuRow(
              key: const ValueKey('family-menu-contact'),
              label: 'Contactar agencia',
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => _sendMessage(agencyPhone, 'Hola! Necesito ayuda'),
            ),
            const SizedBox(height: 8),
            _PiloMenuRow(
              key: const ValueKey('family-menu-report'),
              label: 'Reportar un problema',
              icon: Icons.help_outline_rounded,
              onTap: () => _sendMessage(agencyPhone, 'Hola! Necesito ayuda'),
            ),
            const SizedBox(height: 16),
            _PiloMenuRow(
              key: const ValueKey('family-menu-logout'),
              label: 'Cerrar sesión',
              icon: Icons.logout_rounded,
              foreground: const Color(0xFFB42318),
              onTap: () => _logout(origin),
            ),
          ],
        ),
      );

  // Preserve the existing contact operation. Isolated reference builds block external
  // apps; the former telephone icons were decorative, not a separate call.
  Future<void> _sendMessage(String phone, String message) =>
      openWhatsAppContact(phone: phone, message: message);
  Future<void> _changePassword(BuildContext context) async {
    if (!allowPasswordChange) return;
    final provider = passwordProvider ?? CoordinatorProviders();
    try {
      final result = await showPiloChangePasswordSheet(
        context,
        attorneyPassword: true,
        onChangePassword: provider.changeAttorneyPassword,
        onUpdateRememberedPassword: (password) =>
            SavedCredentials.updatePasswordForIdentity(
              roles: const ['attorney'],
              rut: login.passengerIdentificacion ?? '',
              password: password,
            ),
      );
      if (context.mounted) showPiloPasswordChangeFeedback(context, result);
    } finally {
      if (passwordProvider == null) provider.dispose();
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await LabSession.clear(prefs);
    if (!context.mounted) return;
    final navigator =
        FamilyNavigationScope.maybeOf(context)?.sessionNavigator ??
        Navigator.of(context);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) => AppleDesignTrialScope(
    child: Builder(
      builder: (context) => Drawer(
        width: math.min(360, MediaQuery.sizeOf(context).width - 28),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Cerrar menú',
                            onPressed: () =>
                                Scaffold.of(context).closeEndDrawer(),
                            color: AppleTrialColors.secondary,
                            icon: const Icon(CupertinoIcons.xmark, size: 21),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _profile(context),
                        const SizedBox(height: 20),
                        if (allowPasswordChange) ...[
                          _MenuAction(
                            key: const ValueKey('family-menu-password'),
                            label: 'Cambiar contraseña',
                            icon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 24,
                            ),
                            onTap: () => _changePassword(context),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Material(
                          color: AppleTrialColors.background,
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              _MenuAction(
                                key: const ValueKey('family-menu-contact'),
                                label: 'Contactar agencia',
                                semanticLabel: 'Contactar agencia por WhatsApp',
                                icon: const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  size: 24,
                                ),
                                onTap: () => _sendMessage(
                                  agencyPhone,
                                  'Hola! Necesito ayuda',
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(left: 56),
                                child: Divider(height: 1, thickness: 1),
                              ),
                              _MenuAction(
                                key: const ValueKey('family-menu-report'),
                                label: 'Reportar un problema',
                                icon: const Icon(
                                  CupertinoIcons.exclamationmark_bubble,
                                  size: 24,
                                ),
                                onTap: () => _sendMessage(
                                  agencyPhone,
                                  'Hola! Necesito ayuda',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Spacer(),
                        _MenuAction(
                          key: const ValueKey('family-menu-logout'),
                          label: 'Cerrar sesión',
                          color: const Color(0xFFB42318),
                          icon: const Icon(
                            CupertinoIcons.square_arrow_right,
                            size: 24,
                          ),
                          onTap: () => _logout(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _profile(BuildContext context) {
    final name = formatStudentName(
      login.passengerName,
      login.passengerApellidos,
    );
    final rut = login.passengerIdentificacion?.trim() ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfilePhotoAvatar(
          radius: 34,
          passenger: login,
          provider: photoProvider,
          pickImage: pickImage,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                if (rut.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      rut,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _PiloFamilyMenuAction { trip, medical, documents, crew, profile }

class _PiloMenuSheet extends StatelessWidget {
  const _PiloMenuSheet({
    required this.title,
    required this.sheetKey,
    required this.children,
  });
  final String title;
  final Key sheetKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: ConstrainedBox(
      key: sheetKey,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .90,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PiloFamilyTheme.connectorLine,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: PiloFamilyTheme.display(32)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Cerrar menú',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: PiloFamilyTheme.soft,
                      minimumSize: const Size.square(44),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 25),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class _PiloMenuRow extends StatelessWidget {
  const _PiloMenuRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.foreground = PiloFamilyTheme.ink,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Material(
    color: PiloFamilyTheme.soft,
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: foreground == PiloFamilyTheme.ink
                  ? PiloFamilyTheme.accentText
                  : foreground,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: foreground == PiloFamilyTheme.ink
                  ? PiloFamilyTheme.accentText
                  : foreground,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.color = AppleTrialColors.ink,
  });
  final String label;
  final String? semanticLabel;
  final Widget icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel ?? label,
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  IconTheme(
                    data: IconThemeData(
                      color: color == AppleTrialColors.ink
                          ? AppleTrialColors.accent
                          : color,
                    ),
                    child: SizedBox(width: 28, child: Center(child: icon)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
