import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/pages/binnacle.dart';
import 'package:papigiras_app/pages/coordinator/activities.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/pages/tripulationbus.dart';

class TravelCoordinatorDashboard extends StatefulWidget {
  @override
  _TravelCoordinatorDashboardState createState() =>
      _TravelCoordinatorDashboardState();
}

class _TravelCoordinatorDashboardState
    extends State<TravelCoordinatorDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
                // Acción para contactar agencia
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
                // Acción para reportar un problema
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.teal),
              title: Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.grey[800]),
              ),
              onTap: () {
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
            // Logo y encabezado
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
              child: Row(
                children: [
                  Spacer(),
                  Image.asset(
                    'assets/logo-letras-papigiras.png',
                    height: 50,
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.menu, color: Colors.white, size: 30),
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ],
              ),
            ),
            // Tarjeta con información del viaje
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 20),
                          // Foto de perfil
                          Container(
                            padding: EdgeInsets.all(4), // Ancho del borde
                            decoration: BoxDecoration(
                              color: Colors.teal, // Color del borde
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 50, // Tamaño de la imagen
                              backgroundImage: AssetImage('assets/profile.jpg'),
                            ),
                          ),
                          SizedBox(
                              width:
                                  30), // Espaciado entre la imagen y el texto
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alberto Roldán',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(
                                    height: 5), // Espacio entre nombre y texto
                                Text(
                                  'En Gira con:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'LASTARRIAS 3° C 2020',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold, // Negrita
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  // Centrar horizontalmente
                                  children: [
                                    Icon(
                                      Icons.visibility, // Icono de ojo
                                      color: Colors.teal, // Color del icono
                                      size: 24, // Tamaño del icono
                                    ),
                                    SizedBox(
                                        width:
                                            8), // Espacio entre el icono y el texto
                                    GestureDetector(
                                      onTap: () {
                                        // Lógica para navegar o ejecutar una acción
                                      },
                                      child: Text(
                                        'Ver Programa',
                                        style: TextStyle(
                                          fontSize: 16, // Tamaño del texto
                                          color: Colors.teal, // Color del texto
                                          fontWeight:
                                              FontWeight.bold, // Negrita
                                          decoration: TextDecoration
                                              .underline, // Subrayar el texto
                                        ),
                                      ),
                                    ),
                                  ],
                                ), // Espacio entre el texto y el botón
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            // Usar Expanded para evitar desbordamiento
                            child: Column(
                              children: [
                                Text(
                                  'Alumnos a bordo',
                                  style: TextStyle(fontSize: 12),
                                ),
                                SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .center, // Centrar horizontalmente
                                  crossAxisAlignment: CrossAxisAlignment
                                      .center, // Centrar verticalmente
                                  children: [
                                    Icon(
                                      Icons.man_2,
                                      color: Colors.teal,
                                      size: 30,
                                    ),
                                    // Espacio antes del icono
                                    Icon(
                                      Icons.male,
                                      color: Colors.teal,
                                      size: 30,
                                    ),
                                    SizedBox(
                                        width:
                                            10), // Espacio entre el icono y el texto
                                    Text(
                                      '18',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .center, // Centrar horizontalmente
                                  crossAxisAlignment: CrossAxisAlignment
                                      .center, // Centrar verticalmente
                                  children: [
                                    Icon(
                                      Icons.woman_2_sharp,
                                      color: Colors.teal,
                                      size: 30,
                                    ),
                                    // Espacio antes del icono
                                    Icon(
                                      Icons.female,
                                      color: Colors.teal,
                                      size: 30,
                                    ),
                                    SizedBox(
                                        width:
                                            10), // Espacio entre el icono y el texto
                                    Text(
                                      '18',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ],
                                ),
                                // Número debajo del Row
                              ],
                            ),
                          ),
                          // Barra de separación roja
                          Container(
                            width: 2, // Ancho de la barra
                            height:
                                120, // Altura de la barra, ajusta según sea necesario
                            color: Colors.teal, // Color de la barra
                          ),
                          Expanded(
                            // Usar Expanded para evitar desbordamiento
                            child: Column(
                              children: [
                                Text(
                                  'Acompañantes',
                                  style: TextStyle(fontSize: 12),
                                ),
                                SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .center, // Centrar horizontalmente
                                  crossAxisAlignment: CrossAxisAlignment
                                      .center, // Centrar verticalmente
                                  children: [
                                    Icon(
                                      Icons.man_2,
                                      color: Colors.teal,
                                      size: 30,
                                    ),
                                    // Espacio antes del icono
                                    Icon(
                                      Icons.male,
                                      color: Colors.teal,
                                      size: 30,
                                    ),
                                    SizedBox(
                                        width:
                                            10), // Espacio entre el icono y el texto
                                    Text(
                                      '18',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .center, // Centrar horizontalmente
                                  crossAxisAlignment: CrossAxisAlignment
                                      .center, // Centrar verticalmente
                                  children: [
                                    Icon(
                                      Icons.woman_2_sharp,
                                      color: Colors.teal,
                                      size: 30,
                                    ), // Espacio antes del icono
                                    Icon(
                                      Icons.female,
                                      color: Colors.teal,
                                      size: 30,
                                    ),
                                    SizedBox(
                                        width:
                                            10), // Espacio entre el icono y el texto
                                    Text(
                                      '18',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ],
                                ),
                                // Número debajo del Row
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Centrar horizontalmente
                        children: [
                          Icon(
                            Icons.visibility, // Icono de ojo
                            color: Colors.teal, // Color del icono
                            size: 24, // Tamaño del icono
                          ),
                          SizedBox(
                              width: 8), // Espacio entre el icono y el texto
                          GestureDetector(
                            onTap: () {
                              // Lógica para navegar o ejecutar una acción
                            },
                            child: Text(
                              'Ver Nómina Pasajeros',
                              style: TextStyle(
                                fontSize: 16, // Tamaño del texto
                                color: Colors.teal, // Color del texto
                                fontWeight: FontWeight.bold, // Negrita
                                decoration: TextDecoration
                                    .underline, // Subrayar el texto
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 2,
                        width: 320, // Altura de la barra
                        color: Colors.teal, // Color de la barra
                        margin: EdgeInsets.symmetric(
                            vertical:
                                8), // Espaciado vertical alrededor de la barra
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Centrar horizontalmente
                        children: [
                          Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today, // Icono de calendario
                                    color: Colors.teal,
                                    size: 20, // Tamaño del icono
                                  ),
                                  SizedBox(
                                      width:
                                          4), // Espacio entre el icono y el texto
                                  Text(
                                    'Fecha Salida',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              SizedBox(
                                  height:
                                      4), // Espacio entre el texto y la fecha
                              Text(
                                '2/12/20',
                                style:
                                    TextStyle(color: Colors.teal, fontSize: 16),
                              ),
                            ],
                          ),
                          SizedBox(
                              width:
                                  16), // Espacio entre la columna de salida y la flecha
                          Icon(
                            Icons.arrow_forward, // Icono de flecha
                            color: Colors.teal, // Color de la flecha
                            size: 24, // Tamaño de la flecha
                          ),
                          SizedBox(
                              width:
                                  16), // Espacio entre la flecha y la columna de regreso
                          Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today, // Icono de calendario
                                    color: Colors.teal,
                                    size: 20, // Tamaño del icono
                                  ),
                                  SizedBox(
                                      width:
                                          4), // Espacio entre el icono y el texto
                                  Text(
                                    'Fecha Regreso',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              SizedBox(
                                  height:
                                      4), // Espacio entre el texto y la fecha
                              Text(
                                '8/12/20',
                                style:
                                    TextStyle(color: Colors.teal, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Centrar horizontalmente
                        children: [
                          Column(
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                      width:
                                          4), // Espacio entre el icono y el texto

                                  buildInfoSection('Observaciones'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Botones de la parte inferior

            buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget buildInfoSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 5),
        Center(
          // Asegúrate de envolver el Container en un Center para centrarlo
          child: Container(
            width: 320, // Establece un ancho fijo
            constraints: BoxConstraints(
              maxHeight: 80,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.all(10),
            child: TextField(
              maxLines: 3, // Limita el número de líneas
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "",
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildBottomBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildBottomButton(Icons.connect_without_contact_sharp,
                  'Actividades', null, ActivitiesCoordScreen()),
              Transform.translate(
                  offset: Offset(0, -30),
                  child: buildBottomButtonHito(
                      Icons.add_circle, 'Hito', null, HitoAddCoordScreen())),
              buildBottomButton(Icons.person_add_alt_1, 'Contador', null,
                  CountDownCoordScreen()),
            ],
          ),
          SizedBox(height: 5), // Espacio entre las filas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildBottomButton(Icons.medical_information, 'Fichas Medicas',
                  null, MedicalCoordScreen()),
              buildBottomButton(Icons.directions_bus, 'Bus & Tripulación', null,
                  BusCrewCoorScreen()),
              buildBottomButton(Icons.folder_open, 'Mis Documentos', null,
                  DocumentCoordScreen()),
              buildBottomButton(Icons.book, 'Bitácora del Viaje', null,
                  BitacoraCoordScreen()),
            ],
          ),
        ],
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
          Icon(
            icon,
            size: 40,
            color: Colors.teal,
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.teal,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomButtonHito(
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
          Icon(
            icon,
            size: 70,
            color: Colors.teal,
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.teal,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

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
