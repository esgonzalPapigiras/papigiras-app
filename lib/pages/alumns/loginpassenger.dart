import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/pages/attorney/fatherWelcome.dart';
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
        _showError = false; // Resetea el error cuando cambia el texto
      });
    });
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkLoginStatus();
    });
  }

  void _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Recupera los datos guardados del usuario
    String? storedRut = prefs.getString('userRut');
    String? storedPassword = prefs.getString('userPassword');

    // Si los datos existen, colócalos en los controladores de los campos
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
    String? token = await _loadToken(); // _loadToken ya maneja la expiración

    if (isLoggedIn && token != null) {
      String? loginJson = prefs.getString('loginData');
      if (loginJson != null) {
        String role = prefs.getString('userRole') ??
            ''; // Usar un valor por defecto o manejar error si es nulo
        var loginMap = jsonDecode(loginJson);

        if (!mounted)
          return; // Comprobar si el widget sigue montado antes de navegar

        try {
          // Envolver en try-catch por si el JSON no coincide con los DTOs
          if (role == 'coordinator') {
            TourSales login = TourSales.fromJson(loginMap);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      TravelCoordinatorDashboard(login: login)),
            );
          } else if (role == 'passenger') {
            ResponseAttorney login = ResponseAttorney.fromJson(loginMap);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => TravelPassengerDashboard(login: login)),
            );
          } else if (role == 'father') {
            ResponseAttorney login = ResponseAttorney.fromJson(loginMap);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => TravelFatherDashboard(login: login)),
            );
          } else {
            // Rol desconocido o inválido, limpiar sesión para re-login
            await _clearSession(prefs);
          }
        } catch (e) {
          // Error al deserializar, limpiar sesión
          print("Error deserializando loginData: $e");
          await _clearSession(prefs);
        }
      } else {
        // Estado inconsistente: isLoggedIn es true pero no hay loginData. Limpiar sesión.
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

      // Si el token ha expirado, eliminarlo y devolver null
      if (tokenExpiry.isBefore(now)) {
        await prefs.remove('token');
        await prefs.remove('tokenExpiry');
        return null; // El token ha expirado
      } else {
        return token; // El token es válido
      }
    } else {
      return null; // No hay token guardado
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
        buffer.write('-'); // Añade el guion antes del dígito verificador.
      } else if ((text.length - i - 1) % 3 == 0 && i != text.length - 2) {
        buffer.write('.'); // Añade puntos cada tres dígitos.
      }
      buffer.write(text[i]);
    }
    return buffer.toString().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10.0,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  padding:
                      EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Imagen de "Papigiras"
                      Image.asset(
                        'assets/logo-letras-papigiras.png', // Asegúrate de que la imagen esté en la carpeta correcta
                        height: 60.0,
                      ),
                      SizedBox(height: 10.0),
                      Text(
                        'Bienvenido(s)',
                        style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'Alumno(s)',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 30.0),
                      TextField(
                        controller: _userController,
                        maxLength:
                            12, // Longitud máxima para RUT con puntos y guion
                        decoration: InputDecoration(
                          labelText: 'Rut Alumno',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _showError ? Colors.red : Colors.grey,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _showError ? Colors.red : Colors.teal,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        keyboardType: TextInputType.text,
                        onChanged: (value) {
                          setState(() {
                            _userController.text = _formatRut(value);
                            _userController.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: _userController.text.length),
                            );
                            _showError = false; // Oculta el error al escribir
                          });
                        },
                      ),
                      if (_showError)
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            'Debes ingresar un rut de alumno',
                            style: TextStyle(color: Colors.red, fontSize: 12.0),
                          ),
                        ),
                      SizedBox(height: 20.0),
                      TextField(
                        controller: _passwordController,
                        obscureText:
                            _isPasswordHidden, // Oculta el texto si es true
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color:
                                    _showErrorTwo ? Colors.red : Colors.grey),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color:
                                    _showErrorTwo ? Colors.red : Colors.teal),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordHidden
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordHidden =
                                    !_isPasswordHidden; // Alterna visibilidad
                              });
                            },
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _showErrorTwo =
                                false; // Oculta el error al escribir
                          });
                        },
                      ),
                      SizedBox(height: 30.0),
                      ElevatedButton(
                        onPressed: () async {
                          if (_userController.text.isNotEmpty &&
                              _passwordController.text.isNotEmpty) {
                            setState(() {
                              _showError = false;
                              _showErrorTwo = false;
                            });

                            // Realizar la solicitud de login
                            final login = await usuarioProvider
                                .validateLoginUserPassenger(
                                    _userController.text,
                                    _passwordController.text);

                            if (login != null && login.isActive!) {
                              // Si el login es exitoso, guardar el token, la fecha de expiración y el rol
                              SharedPreferences prefs =
                                  await SharedPreferences.getInstance();

                              // Guardar el token
                              await prefs.setString('token', login.tokenKey!);

                              // Establecer la fecha de expiración a 3 días a partir de ahora
                              final now = DateTime.now();
                              final expiryDate = now.add(Duration(
                                  days: 3)); // Fecha de expiración: 3 días
                              await prefs.setString(
                                  'tokenExpiry', expiryDate.toIso8601String());

                              // Guardar el rol del usuario
                              await prefs.setString('userRole',
                                  'passenger'); // Guardamos el rol como 'passenger'

                              // Marcar como logueado
                              await prefs.setBool('isLoggedIn', true);

                              // Serializar el objeto login y guardarlo como una cadena JSON
                              String loginJson = jsonEncode(login.toJson());
                              await prefs.setString('loginData', loginJson);

                              // Mostrar QuickAlert de éxito y navegar a la siguiente pantalla
                              QuickAlert.show(
                                context: context,
                                type: QuickAlertType.success,
                                title: 'Éxito',
                                text: 'Bienvenido',
                                confirmBtnText: 'Continuar',
                                onConfirmBtnTap: () async {
                                  Navigator.of(context)
                                      .pop(); // Cierra el QuickAlert
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TravelPassengerDashboard(
                                              login: login),
                                    ),
                                  );
                                },
                              );
                            } else {
                              // Si el login es null o inactivo, mostrar QuickAlert de error
                              QuickAlert.show(
                                context: context,
                                type: QuickAlertType.error,
                                title: 'Error',
                                text: 'Usuario no encontrado o desactivado',
                                confirmBtnText: 'Aceptar',
                                onConfirmBtnTap: () {
                                  Navigator.of(context)
                                      .pop(); // Cierra el QuickAlert
                                },
                              );
                            }
                          } else {
                            // Si los campos están vacíos, mostrar QuickAlert de error
                            QuickAlert.show(
                              context: context,
                              type: QuickAlertType.error,
                              title: 'Error',
                              text: 'Ingresar usuario y contraseña',
                              confirmBtnText: 'Aceptar',
                              onConfirmBtnTap: () {
                                Navigator.of(context)
                                    .pop(); // Cierra el QuickAlert
                              },
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 50.0, vertical: 15.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          backgroundColor: Colors.teal, // Color del botón
                        ),
                        child: Text(
                          'Ingresar',
                          style: TextStyle(fontSize: 18.0, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Enlace de recuperación de contraseña fuera del container
              /*TextButton(
                onPressed: () {
                  // Acción para recuperar la contraseña
                  print("Recuperar contraseña presionado");
                },
                child: Text(
                  '¿Has olvidado tu contraseña? Recupérala aquí',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),*/
            ],
          ),
        ),
      ),
    );
  }
}
