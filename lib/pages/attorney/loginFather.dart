import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:papigiras_app/pages/attorney/fatherWelcome.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
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
      setState(() {
        _showError = false; // Resetea el error cuando cambia el texto
      });
    });
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
    return buffer.toString();
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
                        'Apoderado(s)',
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

                            if (_userController.text.isNotEmpty &&
                                _passwordController.text.isNotEmpty) {
                              final login =
                                  await usuarioProvider.validateLoginUserFather(
                                      _userController.text,
                                      _passwordController.text);
                              if (login != null && login.isActive!) {
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setString('token', login.tokenKey!);
                                final now = DateTime.now();
                                final expiryDate = now.add(Duration(
                                    days:
                                        3)); // Fecha de expiración: 3 días a partir de ahora
                                await prefs.setString('tokenExpiry',
                                    expiryDate.toIso8601String());
                                // Si login tiene datos, muestra QuickAlert de éxito y navega a la siguiente pantalla
                                QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.success,
                                  title: 'Éxito',
                                  text: 'Bienvenido',
                                  confirmBtnText: 'Continuar',
                                  onConfirmBtnTap: () async {
                                    SharedPreferences prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setBool('isLoggedIn', true);
                                    Navigator.of(context)
                                        .pop(); // Cierra el QuickAlert
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            WelcomeFatherScreen(login: login),
                                      ),
                                    );
                                  },
                                );
                              } else {
                                // Si login es null, muestra QuickAlert de error y no navega
                                QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.error,
                                  title: 'Error',
                                  text:
                                      'Usuario y Password Incorrectos,Favor reintentar',
                                  confirmBtnText: 'Aceptar',
                                  onConfirmBtnTap: () {
                                    Navigator.of(context)
                                        .pop(); // Cierra el QuickAlert
                                  },
                                );
                              }
                            } else {
                              QuickAlert.show(
                                context: context,
                                type: QuickAlertType.error,
                                title: 'Error',
                                text: 'Ingrese Password y rut Porfavor',
                                confirmBtnText: 'Aceptar',
                                onConfirmBtnTap: () {
                                  Navigator.of(context)
                                      .pop(); // Cierra el QuickAlert
                                },
                              );
                            }

                            // Maneja la respuesta del login si es necesario
                          } else {
                            setState(() {
                              _showError = true;
                              _showErrorTwo = true;
                            });
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
