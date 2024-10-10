import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/pages/index.dart';
import 'package:papigiras_app/pages/tripulationbus.dart';

class MedicalRecordScreen extends StatefulWidget {
  @override
  _MedicalRecordScreenState createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends State<MedicalRecordScreen> {
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
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Ficha Médica',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(width: 10),
                            TextButton.icon(
                              onPressed: () {
                                // Acción para editar
                              },
                              icon: Icon(Icons.edit, color: Colors.teal),
                              label: Text(
                                'Editar',
                                style: TextStyle(color: Colors.teal),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(4), // Ancho del borde
                              decoration: BoxDecoration(
                                color: Colors.teal, // Color del borde
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundImage:
                                    AssetImage('assets/profile.jpg'),
                              ),
                            ),
                            SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Arancibia Carlos',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  '20.457.748-k',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '16 años / Tipo de Sangre O+',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Divider(),
                        SizedBox(height: 10),
                        buildInfoSection('Alergias'),
                        SizedBox(height: 10),
                        buildInfoSection('Enfermedades'),
                        SizedBox(height: 10),
                        buildInfoSection('Medicamentos'),
                        SizedBox(height: 20),
                        // Botón Guardar Ficha Médica
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => TravelDashboard()),
                              );
                            },
                            child: Text('Guardar Ficha Médica'),
                            style: ElevatedButton.styleFrom(
                              primary: Colors.teal,
                              onPrimary: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 15,
                              ),
                              textStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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
              // Barra de navegación inferior con sombreado
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
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          buildBottomButton(
                              Icons.book, 'Bitácora del Viaje', '1'),
                          buildBottomButton(
                              Icons.directions_bus, 'Bus & Tripulación', null),
                          buildBottomButton(
                              Icons.folder_open, 'Mis Documentos', null),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
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
        Container(
          constraints: BoxConstraints(
            maxHeight: 80,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.all(10),
          child: TextField(
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Escribe aquí...',
              hintStyle: TextStyle(color: Colors.grey[600]),
            ),
            style: TextStyle(color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  Widget buildBottomButton(IconData icon, String label, String? badge) {
    return GestureDetector(
      onTap: () {
        print('$label presionado');
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
}
