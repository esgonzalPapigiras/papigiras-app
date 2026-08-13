import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class CoordinatorProfileScreen extends StatefulWidget {
  const CoordinatorProfileScreen({super.key});

  @override
  State<CoordinatorProfileScreen> createState() => _CoordinatorProfileScreenState();
}

class _CoordinatorProfileScreenState extends State<CoordinatorProfileScreen> {
  final CoordinatorProviders _provider = CoordinatorProviders();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmationPasswordController = TextEditingController();
  late Future<CoordinatorProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _provider.getCoordinatorProfile();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmationPasswordController.dispose();
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
                    TextField(controller: _currentPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña actual')),
                    const SizedBox(height: 12),
                    TextField(controller: _newPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva contraseña')),
                    const SizedBox(height: 12),
                    TextField(controller: _confirmationPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Repetir nueva contraseña')),
                    if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red))],
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
                          final currentPassword = _currentPasswordController.text;
                          final newPassword = _newPasswordController.text;
                          final confirmationPassword = _confirmationPasswordController.text;
                          if (currentPassword.isEmpty) {
                            setDialogState(() {
                              error = 'Debes ingresar tu contraseña actual.';
                            });
                            return;
                          }
                          if (newPassword.length < 6) {
                            setDialogState(() {
                              error = 'La nueva contraseña debe tener al menos 6 caracteres.';
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
                            await _provider.changeCoordinatorPassword(currentPassword, newPassword);
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.pop(dialogContext);
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada.')));
                          } catch (exception) {
                            if (!dialogContext.mounted) {
                              return;
                            }
                            setDialogState(() {
                              saving = false;
                              error = exception.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
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
      appBar: AppBar(title: const Text('Mi perfil'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: FutureBuilder<CoordinatorProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(padding: const EdgeInsets.all(20), child: Text(snapshot.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No se pudo cargar el perfil.'));
          }
          final profile = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const CircleAvatar(radius: 55, backgroundImage: AssetImage('assets/profile.jpg')),
              const SizedBox(height: 16),
              Text('${profile.name} ${profile.lastname}'.trim(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _field(Icons.badge, 'RUT', profile.rut),
              _field(Icons.phone, 'Teléfono', profile.phone),
              _field(Icons.email, 'Correo', profile.email),
              _field(Icons.home, 'Residencia', profile.residence),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: _showPasswordDialog, icon: const Icon(Icons.lock), label: const Text('Cambiar contraseña')),
            ],
          );
        },
      ),  
    );
  }

  Widget _field(IconData icon, String label, String value) {
    return ListTile(leading: Icon(icon, color: Colors.teal), title: Text(label), subtitle: Text(value.isEmpty ? 'Sin información' : value));
  }
}
