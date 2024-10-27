import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/pages/binnacle.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';

class BusCrewCoorScreen extends StatefulWidget {
  @override
  _BusCrewCoorScreenState createState() => _BusCrewCoorScreenState();
}

class _BusCrewCoorScreenState extends State<BusCrewCoorScreen> {
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
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 30.0, horizontal: 16.0),
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
              Expanded(
                  child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título de sección
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment
                              .center, // Centra el contenido horizontalmente
                          children: [
                            Text(
                              'Bus & Tripulación',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment
                                  .center, // Centra la imagen y el texto
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.asset(
                                  'assets/bus.jpg', // Imagen del bus
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Patente: ',
                                              style: TextStyle(
                                                  color: Colors.teal,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(
                                              text: 'WT1167-Y',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Marca: ',
                                              style: TextStyle(
                                                  color: Colors.teal,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(
                                              text: 'Mercedes Benz',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Modelo: ',
                                              style: TextStyle(
                                                  color: Colors.teal,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(
                                              text: 'Kin-long',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Año: ',
                                              style: TextStyle(
                                                  color: Colors.teal,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(
                                              text: '2016',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Empresa: ',
                                              style: TextStyle(
                                                  color: Colors.teal,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(
                                              text: 'Landeros',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                      Divider(height: 40, thickness: 1),
                      // Lista de Tripulación
                      _buildCrewMember(
                        role: 'Coordinador',
                        name: 'Alberto Roldán J.',
                        position: 'Profesor Ed. Física',
                        id: '14.776.259-9',
                        imagePath: 'assets/conductor_one.jpg',
                      ),
                      _buildCrewMember(
                        role: 'Chofer 1',
                        name: 'Luis Uribe M.',
                        position: 'Licencia Tipo B',
                        id: '13.676.279-k',
                        imagePath: 'assets/conductor_two.jpg',
                      ),
                      _buildCrewMember(
                        role: 'Chofer 2',
                        name: 'Carlos Soto G.',
                        position: 'Licencia Tipo B',
                        id: '12.987.775-8',
                        imagePath: 'assets/conductor_three.png',
                      ),
                    ],
                  ),
                ),
              )),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildBottomButton(Icons.connect_without_contact_sharp,
                            'Actividades', null, BitacoraScreen()),
                        Transform.translate(
                            offset: Offset(0, -30),
                            child: buildBottomButtonHito(Icons.add_circle,
                                'Hito', null, BusCrewCoorScreen())),
                        buildBottomButton(
                            Icons.person_add_alt_1, 'Contador', null, null),
                      ],
                    ),
                    SizedBox(height: 5), // Espacio entre las filas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildBottomButton(Icons.medical_information,
                            'Fichas Medicas', null, MedicalCoordScreen()),
                        buildBottomButton(Icons.directions_bus,
                            'Bus & Tripulación', null, BusCrewCoorScreen()),
                        buildBottomButton(Icons.folder_open, 'Mis Documentos',
                            null, DocumentCoordScreen()),
                        buildBottomButton(Icons.book, 'Bitácora del Viaje',
                            null, BitacoraScreen()),
                      ],
                    ),
                  ],
                ),
              ),
            ])));
  }

  Widget _buildCrewMember({
    required String role,
    required String name,
    required String position,
    required String id,
    required String imagePath,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 20.0),
      leading: Container(
        padding: EdgeInsets.all(2), // Ancho del borde
        decoration: BoxDecoration(
          color: Colors.teal, // Color del borde
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 120, // Ancho del contenedor para la imagen
          height: 120, // Alto del contenedor para la imagen
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: AssetImage(imagePath),
              fit: BoxFit
                  .fitHeight, // Ajusta la imagen para que ocupe todo el círculo
              alignment: Alignment.center, // Centra la imagen
            ),
          ),
        ),
      ),
      title: Text(
        role,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: TextStyle(
                  color: Colors.grey[800], fontWeight: FontWeight.bold)),
          Text(position, style: TextStyle(color: Colors.grey[600])),
          Text(id, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FontAwesomeIcons.whatsapp, color: Colors.teal, size: 24),
          SizedBox(width: 10), // Espacio entre los íconos
          Icon(FontAwesomeIcons.phone, color: Colors.teal, size: 24),
        ],
      ),
      onTap: () {
        // Acción para contactar por WhatsApp
      },
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
                        fontSize: 8,
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
              fontSize: 8,
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
