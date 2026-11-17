import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_login_layout.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPassenger extends StatefulWidget {
  @override
  _LoginPassengerState createState() => _LoginPassengerState();
}

class _LoginPassengerState extends State<LoginPassenger> {
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
      setState(() {
        _showError = false;
      });
    });
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkLoginStatus();
    });
  }

  void _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedRut = prefs.getString('userRut');
    String? storedPassword = prefs.getString('userPassword');
    setState(() {
      if (storedRut != null) {
        _userController.text = storedRut;
      }
      if (storedPassword != null) {
        _passwordController.text = storedPassword;
      }
    });
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? token = await _loadToken();
    if (isLoggedIn && token != null) {
      String? loginJson = prefs.getString('loginData');
      if (loginJson != null) {
        String role = prefs.getString('userRole') ?? '';
        var loginMap = jsonDecode(loginJson);
        if (!mounted) return;
        try {
          if (role == 'coordinator') {
            TourSales login = TourSales.fromJson(loginMap);
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        TravelCoordinatorDashboard(login: login)));
          } else if (role == 'passenger') {
            ResponseAttorney login = ResponseAttorney.fromJson(loginMap);
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        TravelPassengerDashboard(login: login)));
          } else if (role == 'father') {
            ResponseAttorney login = ResponseAttorney.fromJson(loginMap);
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => TravelFatherDashboard(login: login)));
          } else {
            await _clearSession(prefs);
          }
        } catch (e) {
          print("Error deserializando loginData: $e");
          await _clearSession(prefs);
        }
      } else {
        await _clearSession(prefs);
      }
    }
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove('token');
    await prefs.remove('tokenExpiry');
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('loginData');
    await prefs.remove('userRole');
  }

  Future<String?> _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? tokenExpiryStr = prefs.getString('tokenExpiry');
    if (token != null && tokenExpiryStr != null) {
      DateTime tokenExpiry = DateTime.parse(tokenExpiryStr);
      final now = DateTime.now();
      if (tokenExpiry.isBefore(now)) {
        await prefs.remove('token');
        await prefs.remove('tokenExpiry');
        return null;
      } else {
        return token;
      }
    } else {
      return null;
    }
  }

  @override
  void dispose() {
    _userController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return PapigirasLoginLayout(
      role: PapigirasLoginRole.passenger,
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
            onPressed: () async {
              if (_userController.text.isNotEmpty &&
                  _passwordController.text.isNotEmpty) {
                setState(() {
                  _showError = false;
                  _showErrorTwo = false;
                });
                final login = await usuarioProvider.validateLoginUserPassenger(
                    _userController.text, _passwordController.text);
                if (login != null && login.isActive!) {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.setString('token', login.tokenKey!);
                  final now = DateTime.now();
                  final expiryDate = now.add(Duration(days: 3));
                  await prefs.setString(
                      'tokenExpiry', expiryDate.toIso8601String());
                  await prefs.setString('userRole', 'passenger');
                  await prefs.setBool('isLoggedIn', true);
                  String loginJson = jsonEncode(login.toJson());
                  await prefs.setString('loginData', loginJson);
                  QuickAlert.show(
                    context: context,
                    type: QuickAlertType.success,
                    title: 'Éxito',
                    text: 'Bienvenido',
                    confirmBtnText: 'Continuar',
                    onConfirmBtnTap: () async {
                      Navigator.of(context).pop();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  TravelPassengerDashboard(login: login)));
                    },
                  );
                } else {
                  QuickAlert.show(
                    context: context,
                    type: QuickAlertType.error,
                    title: 'Error',
                    text: 'Usuario no encontrado o desactivado',
                    confirmBtnText: 'Aceptar',
                    onConfirmBtnTap: () {
                      Navigator.of(context).pop();
                    },
                  );
                }
              } else {
                QuickAlert.show(
                  context: context,
                  type: QuickAlertType.error,
                  title: 'Error',
                  text: 'Ingresar usuario y contraseña',
                  confirmBtnText: 'Aceptar',
                  onConfirmBtnTap: () {
                    Navigator.of(context).pop();
                  },
                );
              }
            },
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
