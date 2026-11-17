import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_login_layout.dart';
import 'package:papigiras_app/pages/attorney/fatherWelcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/fcm_utils.dart';
import 'package:papigiras_app/utils/session_utils.dart';
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginFather extends StatefulWidget {
  @override
  _LoginFatherState createState() => _LoginFatherState();
}

class _LoginFatherState extends State<LoginFather> {
  final usuarioProvider = new CoordinatorProviders();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showError = false;
  bool _showErrorTwo = false;
  bool _isPasswordHidden = true;

  @override
  void initState() {
    super.initState();
    _userController.addListener(() {
      setState(() => _showError = false);
    });
    _loadSavedCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await checkLoginStatus(context, replace: true);
    });
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedRut = prefs.getString('userRut');
    final String? storedPassword = prefs.getString('userPassword');
    setState(() {
      if (storedRut != null) _userController.text = storedRut;
      if (storedPassword != null) _passwordController.text = storedPassword;
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatRut(String text) {
    text = text.replaceAll(RegExp(r'[^0-9kK]'), '');
    if (text.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == text.length - 1) {
        buffer.write('-');
      } else if ((text.length - i - 1) % 3 == 0 && i != text.length - 2) {
        buffer.write('.');
      }
      buffer.write(text[i]);
    }
    return buffer.toString().toUpperCase();
  }

  Future<void> _handleLogin() async {
    if (_userController.text.isEmpty || _passwordController.text.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Error',
        text: 'Ingresar usuario y contraseña',
        confirmBtnText: 'Aceptar',
        onConfirmBtnTap: () => Navigator.of(context).pop(),
      );
      return;
    }
    setState(() {
      _showError = false;
      _showErrorTwo = false;
    });
    final login = await usuarioProvider.validateLoginUserFather(
        _userController.text, _passwordController.text);
    if (login != null && login.isActive == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', login.tokenKey!);
      await prefs.setString('tokenExpiry',
          DateTime.now().add(Duration(days: 3)).toIso8601String());
      await prefs.setString('userRole', 'father');
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('loginData', jsonEncode(login.toJson()));
      Object? notificationError;
      try {
        await FcmUtils.startForFather(login.passengerIdentificacion.toString())
            .timeout(const Duration(seconds: 15));
      } catch (error) {
        notificationError = error;
        debugPrint('FCM registration failed: $error');
      }
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: notificationError == null
            ? QuickAlertType.success
            : QuickAlertType.warning,
        title: notificationError == null ? 'Éxito' : 'Sesión iniciada',
        text: notificationError == null
            ? 'Bienvenido'
            : 'La sesión se inició, pero no fue posible registrar '
                'las notificaciones. Verifica la conexión y vuelve '
                'a abrir la aplicación.',
        confirmBtnText: 'Continuar',
        onConfirmBtnTap: () async {
          Navigator.of(context).pop();
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (_) => WelcomeFatherScreen(login: login)),
              (route) => false);
        },
      );
    } else {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Error',
        text: 'Usuario no encontrado o desactivado',
        confirmBtnText: 'Aceptar',
        onConfirmBtnTap: () => Navigator.of(context).pop(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PapigirasLoginLayout(
      role: PapigirasLoginRole.attorney,
      footer: const PapigirasLoginHint(),
      children: [
        TextField(
          controller: _userController,
          maxLength: 12,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          decoration: papigirasLoginField(
            label: 'RUT del alumno',
            hint: '12.345.678-9',
            errorText: _showError ? 'Debes ingresar un RUT de alumno' : null,
          ),
          onChanged: (value) {
            setState(() {
              _userController.text = _formatRut(value);
              _userController.selection = TextSelection.fromPosition(
                TextPosition(offset: _userController.text.length),
              );
              _showError = false;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: _isPasswordHidden,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
          decoration: papigirasLoginField(
            label: 'Contraseña',
            errorText: _showErrorTwo ? 'Debes ingresar la contraseña' : null,
            suffixIcon: IconButton(
              tooltip: _isPasswordHidden
                  ? 'Mostrar contraseña'
                  : 'Ocultar contraseña',
              icon: Icon(
                _isPasswordHidden ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() => _isPasswordHidden = !_isPasswordHidden);
              },
            ),
          ),
          onChanged: (_) => setState(() => _showErrorTwo = false),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _handleLogin,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Ingresar'),
            ),
          ),
        ),
      ],
    );
  }
}
