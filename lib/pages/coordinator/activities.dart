import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/pages/tripulationbus.dart';

class ActivitiesCoordScreen extends StatefulWidget {
  @override
  _ActivitiesCoordScreenState createState() => _ActivitiesCoordScreenState();
}

class _ActivitiesCoordScreenState extends State<ActivitiesCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? selectedActivity;
  final TextEditingController participantsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFF3AC5C9), // Fondo turquesa
      endDrawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildBackground(),
          Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: _buildActivityContent(),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          ListTile(
            leading: Icon(Icons.phone, color: Colors.teal),
            title: Text('Contactar Agencia'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone, color: Colors.teal),
                SizedBox(width: 10),
                Icon(FontAwesomeIcons.whatsapp, color: Colors.teal),
              ],
            ),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.report_problem, color: Colors.teal),
            title: Text('Reportar un Problema'),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.teal),
            title: Text('Cerrar Sesión'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundImage: AssetImage('assets/profile.jpg'),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arancibia Carlos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text('20.457.748-K'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
      child: Row(
        children: [
          Spacer(),
          Image.asset(
            'assets/logo-letras-papigiras.png',
            height: 50,
          ),
          Spacer(),
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: Colors.white, size: 30),
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Actividades',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedActivity,
              items: ['Rafting', 'Bowling Bariloche', 'Cabalgata Osorno']
                  .map((activity) => DropdownMenuItem(
                        value: activity,
                        child: Text(activity),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedActivity = value),
              decoration: InputDecoration(
                labelText: 'Selecciona Actividad',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: participantsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Participantes',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    // Agregar lógica para agregar actividad
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    backgroundColor: Colors.teal,
                  ),
                  child: Text(
                    'Agregar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),
            Expanded(
              child: ListView(
                children: _buildActivityList(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Exportar .XLS', style: TextStyle(color: Colors.teal)),
                Icon(Icons.file_download, color: Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActivityList() {
    List<Map<String, String>> activities = [
      {'name': 'Bowling Bariloche', 'participants': '32'},
      {'name': 'Cabalgata Osorno', 'participants': '28'},
      {'name': 'Rafting Bariloche', 'participants': '32'},
    ];

    return activities.map((entry) {
      return Card(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Más ancho
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ListTile(
            title: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Centra el contenido del Row
              children: [
                Text(
                  entry['name']!,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Container(
                  margin: EdgeInsets.symmetric(
                      horizontal: 8), // Espaciado a los lados
                  height: 20, // Altura de la línea
                  width: 2, // Ancho de la línea
                  color: Colors.teal, // Color de la línea
                ),
                Text(
                  entry['participants']!,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      padding:
          EdgeInsets.symmetric(vertical: 10), // Ajuste del espacio vertical
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildBottomButton(Icons.connect_without_contact_sharp,
                  'Actividades', null, ActivitiesCoordScreen()),
              Transform.translate(
                offset:
                    Offset(0, -20), // Ajuste de posición para el botón central
                child: buildBottomButtonHito(
                    Icons.add_circle, 'Hito', null, HitoAddCoordScreen()),
              ),
              buildBottomButton(Icons.person_add_alt_1, 'Contador', null,
                  CountDownCoordScreen()),
            ],
          ),
          SizedBox(height: 10), // Espacio entre filas
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
