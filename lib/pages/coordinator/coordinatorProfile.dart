import 'package:flutter/material.dart';
import 'package:papigiras_app/auth/saved_credentials.dart';
import 'package:papigiras_app/design/pilo_change_password_sheet.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class CoordinatorProfileScreen extends StatefulWidget {
  const CoordinatorProfileScreen({super.key});

  @override
  State<CoordinatorProfileScreen> createState() =>
      _CoordinatorProfileScreenState();
}

class _CoordinatorProfileScreenState extends State<CoordinatorProfileScreen> {
  final CoordinatorProviders _provider = CoordinatorProviders();
  late Future<CoordinatorProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _provider.getCoordinatorProfile();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _showPasswordDialog(BuildContext context, String rut) async {
    final result = await showPiloChangePasswordSheet(
      context,
      onChangePassword: _provider.changeCoordinatorPassword,
      onUpdateRememberedPassword: (password) =>
          SavedCredentials.updatePasswordForIdentity(
            roles: const ['coordinator'],
            rut: rut,
            password: password,
          ),
    );
    if (context.mounted) showPiloPasswordChangeFeedback(context, result);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      body: Builder(
        builder: (context) => SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: FutureBuilder<CoordinatorProfile>(
                future: _profileFuture,
                builder: (context, snapshot) => ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    PiloSectionBar(
                      title: 'Mi perfil',
                      onBack: Navigator.of(context).canPop()
                          ? () => Navigator.of(context).maybePop()
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: _profileContent(context, snapshot),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _profileContent(
    BuildContext context,
    AsyncSnapshot<CoordinatorProfile> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!snapshot.hasData) {
      final message = snapshot.hasError
          ? snapshot.error.toString().replaceFirst('Exception: ', '')
          : 'No se pudo cargar el perfil.';
      return Center(child: Text(message, textAlign: TextAlign.center));
    }

    final profile = snapshot.data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: const ProfilePhotoAvatar(radius: 48),
        ),
        const SizedBox(height: 16),
        Text(
          formatStudentName(profile.name, profile.lastname),
          style: PiloFamilyTheme.display(34),
        ),
        const SizedBox(height: 20),
        DecoratedBox(
          decoration: BoxDecoration(
            color: PiloFamilyTheme.soft,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _field(context, Icons.badge_outlined, 'RUT', profile.rut),
                const Divider(height: 24, color: PiloFamilyTheme.hairline),
                _field(
                  context,
                  Icons.phone_outlined,
                  'Teléfono',
                  profile.phone,
                ),
                const Divider(height: 24, color: PiloFamilyTheme.hairline),
                _field(context, Icons.email_outlined, 'Correo', profile.email),
                const Divider(height: 24, color: PiloFamilyTheme.hairline),
                _field(
                  context,
                  Icons.home_outlined,
                  'Residencia',
                  profile.residence,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => _showPasswordDialog(context, profile.rut),
          icon: const Icon(Icons.lock_outline_rounded),
          label: const Text('Cambiar contraseña', textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 20,
            foregroundColor: PiloFamilyTheme.ink,
            backgroundColor: PiloFamilyTheme.paper,
            child: Icon(icon, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.bodySmall),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? 'Sin información' : value,
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
