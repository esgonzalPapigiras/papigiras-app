import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/alumns/loginpassenger.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/attorney/documentsfather.dart';
import 'package:papigiras_app/pages/attorney/loginFather.dart';
import 'package:papigiras_app/pages/attorney/map.dart';
import 'package:papigiras_app/pages/attorney/tripulationbusfather.dart';
import 'package:papigiras_app/pages/attorney/viewProgram.dart';
import 'package:papigiras_app/pages/attorney/viewmedicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/loginCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:qr/qr.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
// Importa el paquete

class TravelPassengerDashboard extends StatefulWidget {
  final ResponseAttorney login;
  TravelPassengerDashboard({required this.login});
  @override
  _TravelPassengerDashboardState createState() =>
      _TravelPassengerDashboardState();
}

class _TravelPassengerDashboardState extends State<TravelPassengerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final usuarioProvider = new CoordinatorProviders();
  String baseUrl =
      "https://ms-papigiras-app-ezkbu.ondigitalocean.app/app/services/get/information/passenger?tourPassenger=";

  String formatDate(String date) {
    // Parsear la fecha en el formato original (yyyy-MM-dd)
    DateTime parsedDate = DateTime.parse(date);

    // Formatear la fecha en el formato deseado (dd-MM-yyyy)
    String formattedDate = DateFormat('dd-MM-yyyy').format(parsedDate);

    return formattedDate;
  }

  XFile? _image;
  String? _imageUrl;

  void sendMessage({required String phone, required String message}) async {
    final whatsappUrl =
        Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      print('No se puede abrir WhatsApp');
      // Intenta con el esquema directo
      final whatsappDirect = Uri.parse(
          "whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(whatsappDirect)) {
        await launchUrl(
          whatsappDirect,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'WhatsApp no está instalado o no puede manejar la URL';
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = image;
      });
      // Luego de seleccionar la imagen, se sube al servidor
      await usuarioProvider.addHitoFotoPassenger(
          widget.login.passengerId.toString(),
          widget.login.tourId.toString(),
          image); // 1 es un ejemplo de hitoId
      _loadImage(); // Recargamos la imagen después de la subida
    }
  }

  Future<void> _loadImage() async {
    try {
      Responseimagepassenger imageUrl =
          await usuarioProvider.getPicturePassenger(
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
      );

      if (imageUrl.image.isNotEmpty) {
        setState(() {
          _imageUrl = imageUrl.image; // Si la imagen existe, la cargamos
        });
      } else {
        setState(() {
          _imageUrl = null; // Si no hay imagen, usar la predeterminada
        });
      }
    } catch (e) {
      setState(() {
        _imageUrl = null; // Si ocurre un error, usar la predeterminada
      });
    }
  }

  bool _isBase64(String data) {
    try {
      base64Decode(data
          .split(',')
          .last); // Intenta decodificar eliminando un posible prefijo
      return true;
    } catch (e) {
      return false; // Si falla, no es Base64
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage(); // Cargar la imagen al inicio
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFF3AC5C9),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            // Encabezado personalizado
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(4), // Ancho del borde
                    decoration: BoxDecoration(
                      color: Colors.teal, // Color del borde
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: _image != null
                          ? FileImage(File(_image!.path)) as ImageProvider<
                              Object> // Imagen seleccionada desde el dispositivo
                          : (_imageUrl != null && _imageUrl!.isNotEmpty)
                              ? (_isBase64(
                                      _imageUrl!) // Verifica si la URL es una imagen en Base64
                                  ? MemoryImage(base64Decode(
                                      _imageUrl!
                                          .split(',')
                                          .last)) as ImageProvider<
                                      Object> // Decodifica y muestra imagen Base64
                                  : NetworkImage(_imageUrl!) as ImageProvider<
                                      Object>) // Carga imagen desde el servidor
                              : AssetImage('assets/profile.jpg')
                                  as ImageProvider<
                                      Object>, // Imagen predeterminada
                    ),
                  ),
                  SizedBox(width: 16), // Espacio entre la imagen y el texto
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.login.passengerName!}\n${widget.login.passengerApellidos!}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.login.passengerIdentificacion!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.phone, color: Colors.teal),
              title: Text(
                'Contactar Agencia',
                style: TextStyle(color: Colors.grey[800]),
              ),
              onTap: () {
                sendMessage(
                    phone: "+56944087015", message: "Hola! Necesito ayuda");
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone, color: Colors.teal),
                  SizedBox(width: 10),
                  Icon(FontAwesomeIcons.whatsapp, color: Colors.teal),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.report_problem, color: Colors.teal),
              title: Text(
                'Reportar un Problema',
                style: TextStyle(color: Colors.grey[800]),
              ),
              onTap: () {
                sendMessage(
                    phone: "+56944087015", message: "Hola! Necesito ayuda");
              },
            ),
            ListTile(
              leading: Icon(Icons.desktop_access_disabled_outlined,
                  color: Colors.teal),
              title: Text(
                'Desactivar Cuenta',
                style: TextStyle(color: Colors.grey[800]),
              ),
              onTap: () {
                QuickAlert.show(
                  context: context,
                  type: QuickAlertType
                      .error, // Cambiar a 'error' para la cruz roja
                  title: 'Eliminar Cuenta',
                  text: 'Desactivar tu cuenta no te permitirá ingresar más',
                  confirmBtnText: 'Continuar',
                  onConfirmBtnTap: () {
                    usuarioProvider.desactivateAccount(
                        widget.login.passengerIdentificacion.toString());

                    logoutUser(context); //Cierra el QuickAlert
                  },
                );
                // Acción para cerrar sesión
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.teal),
              title: Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.grey[800]),
              ),
              onTap: () {
                logoutUser(context);
                // Acción para cerrar sesión
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            // Sección del encabezado
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
              child: Row(
                children: [
                  Spacer(),
                  Image.asset(
                    'assets/logo-letras-papigiras.png', // Logo de la app
                    height: 50,
                  ),
                  Spacer(),
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu, color: Colors.white, size: 30),
                      onPressed: () {
                        _scaffoldKey.currentState
                            ?.openEndDrawer(); // Abre el Drawer desde la derecha
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Sección de la tarjeta principal
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40.0),
                    topRight: Radius.circular(40.0),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 20),
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _image != null
                            ? FileImage(File(_image!.path)) as ImageProvider<
                                Object> // Imagen seleccionada desde el dispositivo
                            : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                ? (_isBase64(
                                        _imageUrl!) // Verifica si la URL es una imagen en Base64
                                    ? MemoryImage(base64Decode(
                                        _imageUrl!
                                            .split(',')
                                            .last)) as ImageProvider<
                                        Object> // Decodifica y muestra imagen Base64
                                    : NetworkImage(_imageUrl!) as ImageProvider<
                                        Object>) // Carga imagen desde el servidor
                                : AssetImage('assets/profile.jpg')
                                    as ImageProvider<
                                        Object>, // Imagen predeterminada
                      ),
                      SizedBox(height: 10),
                      Text(
                        '${widget.login.passengerName!}\n${widget.login.passengerApellidos!}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.login.passengerIdentificacion!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Divider(),
                      SizedBox(height: 100),
                      Center(
                        child: QrImageView(
                          data: jsonEncode({
                            "id": 20,
                            "url": baseUrl + widget.login.passengerId.toString()
                          }),
                          size: 200,
                          // You can include embeddedImageStyle Property if you
                          //wanna embed an image from your Asset folder
                          embeddedImageStyle: QrEmbeddedImageStyle(
                            size: const Size(
                              100,
                              100,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            // Sección inferior de botones
          ],
        ),
      ),
    );
  }

  void logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borrar el estado de la sesión

    // Redirigir al login o realizar otra acción
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPassenger()),
      (route) =>
          false, // Esto elimina todas las rutas anteriores de la pila de navegación
    );
  }

  Widget buildBottomButton(
      IconData icon, String label, String? badge, Widget? destination) {
    return GestureDetector(
      onTap: () {
        if (destination != null) {
          Navigator.of(context).push(_createRoute(destination));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Icon(
                icon,
                size: 40,
                color: Colors.teal,
              ),
              if (badge != null)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.teal,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Método para crear la ruta personalizada de transición desde abajo hacia arriba
  Route _createRoute(Widget destination) {
    return PageRouteBuilder(
      transitionDuration: Duration(milliseconds: 1000),
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0); // Desde abajo
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
}
