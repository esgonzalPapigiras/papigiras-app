import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';

class LoginCoordinator extends StatefulWidget {
  @override
  _LoginCoordinatorState createState() => _LoginCoordinatorState();
}

class _LoginCoordinatorState extends State<LoginCoordinator> {
  final usuarioProvider = new CoordinatorProviders();
  final TextEditingController _codigoGiraController = TextEditingController();
  bool _showError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // Color de fondo
        body: Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                padding: EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Reemplazo de texto principal por imagen
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
                      'Coordinador(a)',
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 30.0),
                    TextField(
                      controller: _codigoGiraController,
                      decoration: InputDecoration(
                        labelText: 'Código Gira',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: _showError ? Colors.red : Colors.grey),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: _showError ? Colors.red : Colors.teal),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _showError = false; // Oculta el error al escribir
                        });
                      },
                    ),
                    if (_showError)
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Text(
                          'Debes ingresar un codigo de gira',
                          style: TextStyle(color: Colors.red, fontSize: 12.0),
                        ),
                      ),
                    SizedBox(height: 30.0),
                    ElevatedButton(
                      onPressed: () async {
                        if (_codigoGiraController.text.isNotEmpty) {
                          setState(() {
                            _showError = false;
                          });
                          final login = await usuarioProvider
                              .validateLoginUser(_codigoGiraController.text);
                          if (login != null) {
                            // Si login tiene datos, muestra QuickAlert de éxito y navega a la siguiente pantalla
                            QuickAlert.show(
                              context: context,
                              type: QuickAlertType.success,
                              title: 'Éxito',
                              text: 'Gira encontrada',
                              confirmBtnText: 'Continuar',
                              onConfirmBtnTap: () {
                                Navigator.of(context)
                                    .pop(); // Cierra el QuickAlert
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TravelCoordinatorDashboard(
                                            login: login),
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
                              text: 'Gira no encontrada',
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
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: 50.0, vertical: 15.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        primary: Colors.teal, // Color del botón
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
            // Enlace fuera del container
            TextButton(
              onPressed: () {
                // Acción para recuperar la contraseña
                print("Recuperar contraseña presionado");
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero, // Quitar el padding si es necesario
              ),
              child: Text(
                '¿Has olvidado tu contraseña? Recupérala aquí',
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
