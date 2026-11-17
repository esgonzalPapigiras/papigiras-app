import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_login_layout.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorTourSelection.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginCoordinator extends StatefulWidget {
  const LoginCoordinator({super.key});

  @override
  State<LoginCoordinator> createState() => _LoginCoordinatorState();
}

class _LoginCoordinatorState extends State<LoginCoordinator> {
  final CoordinatorProviders _provider = CoordinatorProviders();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedRut();
  }

  Future<void> _loadRememberedRut() async {
    final prefs = await SharedPreferences.getInstance();
    final storedRut = prefs.getString('coordinatorRut');
    if (storedRut != null && mounted) {
      _setRutText(storedRut);
    }
  }

  String _formatRut(String text) {
    final unformatted = text.replaceAll(RegExp(r'[^0-9kK]'), '');
    if (unformatted.isEmpty) return '';

    final buffer = StringBuffer();
    for (var index = 0; index < unformatted.length; index++) {
      if (index == unformatted.length - 1) {
        buffer.write('-');
      } else if ((unformatted.length - index - 1) % 3 == 0 &&
          index != unformatted.length - 2) {
        buffer.write('.');
      }
      buffer.write(unformatted[index]);
    }
    return buffer.toString().toUpperCase();
  }

  void _setRutText(String value) {
    final formattedRut = _formatRut(value);
    _rutController.value = TextEditingValue(
      text: formattedRut,
      selection: TextSelection.collapsed(offset: formattedRut.length),
    );
  }

  Future<void> _login() async {
    final rut = _rutController.text.trim();
    final password = _passwordController.text;
    if (rut.isEmpty || password.isEmpty) {
      _showMessage('Ingresa tu RUT y contraseña.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final coordinator = await _provider.loginCoordinator(rut, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', coordinator.token);
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().add(const Duration(days: 10)).toIso8601String(),
      );
      await prefs.setString('userRole', 'coordinator');
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('coordinatorRut', coordinator.rut);
      await prefs.setString(
        'coordinatorData',
        jsonEncode(coordinator.toJson()),
      );
      await prefs.remove('loginData');
      await prefs.remove('selectedTourId');

      final tours = await _provider.getCoordinatorTours();
      if (!mounted) return;

      if (coordinator.mustChangePassword) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cambio de contraseña pendiente'),
            content: const Text(
              'Tu cuenta utiliza una contraseña temporal. Podrás cambiarla desde tu perfil.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => CoordinatorTourSelectionScreen(
            coordinator: coordinator,
            initialTours: tours,
          ),
        ),
        (route) => false,
      );
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _rutController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PapigirasLoginLayout(
      role: PapigirasLoginRole.coordinator,
      children: [
        TextField(
          controller: _rutController,
          maxLength: 12,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          onChanged: _setRutText,
          decoration: papigirasLoginField(
            label: 'Tu RUT',
            hint: '12.345.678-9',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: _hidePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          decoration: papigirasLoginField(
            label: 'Contraseña',
            suffixIcon: IconButton(
              tooltip:
                  _hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () {
                setState(() => _hidePassword = !_hidePassword);
              },
              icon: Icon(
                _hidePassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLoading ? null : _login,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ingresar'),
            ),
          ),
        ),
      ],
    );
  }
}
