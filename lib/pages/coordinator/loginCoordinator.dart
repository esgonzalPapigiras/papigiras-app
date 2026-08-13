import 'dart:convert';

import 'package:flutter/material.dart';
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
      _rutController.text = storedRut;
    }
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo-letras-papigiras.png', height: 60),
                  const SizedBox(height: 10),
                  Text(
                    'Bienvenido(a)',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    'Coordinador(a)',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _rutController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'RUT',
                      hintText: '12.345.678-9',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Ingresar',
                            style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
