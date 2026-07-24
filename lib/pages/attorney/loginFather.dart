import 'dart:convert';
import 'package:flutter/material.dart';
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
    final login = await usuarioProvider.validateLoginUserFather(_userController.text, _passwordController.text);
    if (login != null && login.isActive == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', login.tokenKey!);
      await prefs.setString('tokenExpiry', DateTime.now().add(Duration(days: 3)).toIso8601String());
      await prefs.setString('userRole', 'father');
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('loginData', jsonEncode(login.toJson()));
      FcmUtils.saveTokenForFather(login.passengerIdentificacion.toString()).timeout(const Duration(seconds: 10)).catchError((e) {
        print("FCM token save failed: $e");
      });
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'Éxito',
        text: 'Bienvenido',
        confirmBtnText: 'Continuar',
        onConfirmBtnTap: () async {
          Navigator.of(context).pop();
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => WelcomeFatherScreen(login: login)), (route) => false);
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(image: DecorationImage(image: AssetImage('assets/background.png'), fit: BoxFit.cover)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10.0, offset: Offset(0, 5))],
                  ),
                  padding: EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Image.asset('assets/logo-letras-papigiras.png', height: 60.0),
                      SizedBox(height: 10.0),
                      Text('Bienvenido(s)', style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                      Text('Apoderado(s)', style: TextStyle(fontSize: 16.0, color: Colors.grey[600])),
                      SizedBox(height: 30.0),
                      TextField(
                        controller: _userController,
                        maxLength: 12,
                        decoration: InputDecoration(
                          labelText: 'Rut Alumno',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder:
                              OutlineInputBorder(borderSide: BorderSide(color: _showError ? Colors.red : Colors.grey), borderRadius: BorderRadius.circular(10.0)),
                          focusedBorder:
                              OutlineInputBorder(borderSide: BorderSide(color: _showError ? Colors.red : Colors.teal), borderRadius: BorderRadius.circular(10.0)),
                        ),
                        keyboardType: TextInputType.text,
                        onChanged: (value) {
                          setState(() {
                            _userController.text = _formatRut(value);
                            _userController.selection = TextSelection.fromPosition(TextPosition(offset: _userController.text.length));
                            _showError = false;
                          });
                        },
                      ),
                      if (_showError)
                        Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text('Debes ingresar un rut de alumno', style: TextStyle(color: Colors.red, fontSize: 12.0))),
                      SizedBox(height: 20.0),
                      TextField(
                        controller: _passwordController,
                        obscureText: _isPasswordHidden,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder:
                              OutlineInputBorder(borderSide: BorderSide(color: _showErrorTwo ? Colors.red : Colors.grey), borderRadius: BorderRadius.circular(10.0)),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _showErrorTwo ? Colors.red : Colors.teal),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordHidden ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _isPasswordHidden = !_isPasswordHidden;
                              });
                            },
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _showErrorTwo = false);
                        },
                      ),
                      SizedBox(height: 30.0),
                      ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 15.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                          backgroundColor: Colors.teal,
                        ),
                        child: Text('Ingresar', style: TextStyle(fontSize: 18.0, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
