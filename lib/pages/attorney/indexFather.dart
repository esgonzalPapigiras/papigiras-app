import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/attorney/documentsfather.dart';
import 'package:papigiras_app/pages/attorney/loginFather.dart';
import 'package:papigiras_app/pages/attorney/map.dart';
import 'package:papigiras_app/pages/attorney/tripulationbusfather.dart';
import 'package:papigiras_app/pages/attorney/viewProgram.dart';
import 'package:papigiras_app/pages/attorney/viewmedicalRecord.dart';
import 'package:url_launcher/url_launcher.dart';

class TravelFatherDashboard extends StatefulWidget {
  final ResponseAttorney login;
  TravelFatherDashboard({required this.login});
  @override
  _TravelFatherDashboardState createState() => _TravelFatherDashboardState();
}

class _TravelFatherDashboardState extends State<TravelFatherDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String formatDate(String date) {
    // Parsear la fecha en el formato original (yyyy-MM-dd)
    DateTime parsedDate = DateTime.parse(date);

    // Formatear la fecha en el formato deseado (dd-MM-yyyy)
    String formattedDate = DateFormat('dd-MM-yyyy').format(parsedDate);

    return formattedDate;
  }

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
                      radius: 35, // Tamaño de la imagen
                      backgroundImage: AssetImage('assets/profile.jpg'),
                    ),
                  ),
                  SizedBox(width: 16), // Espacio entre la imagen y el texto
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arancibia Carlos',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '20.457.748-k',
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
              leading: Icon(Icons.logout, color: Colors.teal),
              title: Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.grey[800]),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginFather(),
                  ),
                );
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
                        radius: 40,
                        backgroundImage:
                            AssetImage('assets/profile.jpg'), // Foto del perfil
                      ),
                      SizedBox(height: 10),
                      Center(
                        child: Text(
                          widget.login.passengerName! +
                              " " +
                              widget.login.passengerApellidos!,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Text(
                        widget.login.passengerIdentificacion!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ViewMedicalRecordScreen(login: widget.login),
                            ),
                          );
                        },
                        icon: Icon(Icons.remove_red_eye, color: Colors.teal),
                        label: Text(
                          'Ficha médica',
                          style: TextStyle(
                            color: Colors.teal,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Divider(),
                      Text(
                        widget.login.tourName! +
                            " " +
                            widget.login.tourCourse! +
                            " " +
                            widget.login.tourYear.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'En Gira',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ViewProgramScreen(login: widget.login),
                            ),
                          );
                        },
                        icon: Icon(Icons.remove_red_eye, color: Colors.teal),
                        label: Text(
                          'Ver Programa',
                          style: TextStyle(
                            color: Colors.teal,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Fecha Salida',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  formatDate(
                                      widget.login.tourSalesdateInitial!),
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Fecha Regreso',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  formatDate(widget.login.tourSalesdateFinal!),
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MapScreen(
                                login: widget.login,
                                locations: [],
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: EdgeInsets.symmetric(
                            horizontal: 30.0,
                            vertical: 15.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        child: Text(
                          'Ver Ubicación en tiempo Real',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 10,
                    offset: Offset(0, -3), // Sombra hacia arriba
                  ),
                ],
              ),
              child: Column(
                children: [
                  Divider(height: 1, color: Colors.grey[300]),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 35),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildBottomButton(
                            Icons.book,
                            'Bitácora del Viaje',
                            null,
                            BitacoraFatherScreen(
                              login: widget.login,
                            )),
                        buildBottomButton(
                            Icons.directions_bus,
                            'Bus & Tripulación',
                            null,
                            BusCrewFatherScreen(
                              login: widget.login,
                            )),
                        buildBottomButton(Icons.folder_open, 'Mis Documentos',
                            null, DocumentFatherScreen(login: widget.login)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
