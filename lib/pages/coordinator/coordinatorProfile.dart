import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmationPasswordController =
      TextEditingController();
  late Future<CoordinatorProfile> _profileFuture;
  Uint8List? _profileImage;
  bool _uploadingPicture = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<CoordinatorProfile> _loadProfile() async {
    final profile = await _provider.getCoordinatorProfile();
    if (profile.hasPicture) {
      try {
        _profileImage = await _provider.getCoordinatorProfilePicture();
      } catch (_) {
        _profileImage = null;
      }
    }
    return profile;
  }

  Future<void> _changeProfilePicture() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;

    setState(() => _uploadingPicture = true);
    try {
      await _provider.uploadCoordinatorProfilePicture(image);
      final bytes = await _provider.getCoordinatorProfilePicture();
      if (!mounted) return;
      setState(() {
        _profileImage = bytes;
        _uploadingPicture = false;
        _profileFuture = _provider.getCoordinatorProfile();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploadingPicture = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmationPasswordController.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _showPasswordDialog() async {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmationPasswordController.clear();
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cambiar contraseña'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: _currentPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Contraseña actual')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Nueva contraseña')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _confirmationPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Repetir nueva contraseña')),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.red))
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final currentPassword =
                              _currentPasswordController.text;
                          final newPassword = _newPasswordController.text;
                          final confirmationPassword =
                              _confirmationPasswordController.text;
                          if (currentPassword.isEmpty) {
                            setDialogState(() {
                              error = 'Debes ingresar tu contraseña actual.';
                            });
                            return;
                          }
                          if (newPassword.length < 6) {
                            setDialogState(() {
                              error =
                                  'La nueva contraseña debe tener al menos 6 caracteres.';
                            });
                            return;
                          }
                          if (newPassword != confirmationPassword) {
                            setDialogState(() {
                              error = 'Las contraseñas nuevas no coinciden.';
                            });
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await _provider.changeCoordinatorPassword(
                                currentPassword, newPassword);
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.pop(dialogContext);
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Contraseña actualizada.')));
                          } catch (exception) {
                            if (!dialogContext.mounted) {
                              return;
                            }
                            setDialogState(() {
                              saving = false;
                              error = exception
                                  .toString()
                                  .replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FutureBuilder<CoordinatorProfile>(
              future: _profileFuture,
              builder: (context, snapshot) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _header(context),
                  const SizedBox(height: 24),
                  _profileContent(context, snapshot),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: 'Volver',
            style: IconButton.styleFrom(
              backgroundColor: PapigirasColors.soft,
              minimumSize: const Size.square(48),
            ),
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(
              'Mi perfil',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
        ],
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundImage: _profileImage != null
                    ? MemoryImage(_profileImage!)
                    : const AssetImage('assets/profile.jpg') as ImageProvider,
              ),
              Positioned(
                right: -5,
                bottom: -5,
                child: IconButton.filled(
                  tooltip: 'Cambiar foto de perfil',
                  style: IconButton.styleFrom(
                    backgroundColor: PapigirasColors.mint,
                    foregroundColor: PapigirasColors.ink,
                  ),
                  onPressed: _uploadingPicture ? null : _changeProfilePicture,
                  icon: _uploadingPicture
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '${profile.name} ${profile.lastname}'.trim(),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        DecoratedBox(
          decoration: BoxDecoration(
            color: PapigirasColors.soft,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _field(context, Icons.badge_outlined, 'RUT', profile.rut),
                const Divider(height: 24),
                _field(
                  context,
                  Icons.phone_outlined,
                  'Teléfono',
                  profile.phone,
                ),
                const Divider(height: 24),
                _field(
                  context,
                  Icons.email_outlined,
                  'Correo',
                  profile.email,
                ),
                const Divider(height: 24),
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
          onPressed: _showPasswordDialog,
          icon: const Icon(Icons.lock_outline_rounded),
          label: const Text('Cambiar contraseña'),
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
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          foregroundColor: PapigirasColors.ink,
          backgroundColor: PapigirasColors.surface,
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? 'Sin información' : value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
