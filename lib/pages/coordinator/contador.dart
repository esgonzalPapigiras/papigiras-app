import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/attorney/documentsfather.dart';
import 'package:papigiras_app/pages/coordinator/activities.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/loginCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CountDownCoordScreen extends StatefulWidget {
  @override
  _CountDownCoordScreenState createState() => _CountDownCoordScreenState();
  final TourSales login;
  CountDownCoordScreen({required this.login});
}

class _CountDownCoordScreenState extends State<CountDownCoordScreen> {
  List<PassengerList> pasajeros = [];
  List<Map<String, dynamic>> alumnos = []; // Inicializar aquí
  int totalPasajeros = 0;
  int alumnosVerificados = 0;
  final usuarioProvider = CoordinatorProviders();

  @override
  void initState() {
    super.initState();
    // Llama a fetchDocuments al iniciar el widget
    _fetchItineraries(widget.login.tourSalesId.toString());
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

  Future<void> _fetchItineraries(String tourCode) async {
    try {
      // Obtiene la lista de pasajeros
      pasajeros = await usuarioProvider.getListPassenger(tourCode);
      totalPasajeros = pasajeros.length;
      alumnosVerificados =
          pasajeros.where((passenger) => passenger.passengerverificate).length;

      // Mapea los pasajeros a la lista de alumnos
      alumnos = pasajeros.map((passenger) {
        return {
          "nombre": passenger.passengerName,
          "verificado": passenger.passengerverificate
        };
      }).toList();

      setState(() {}); // Actualiza el estado para reconstruir la interfaz
    } catch (error) {
      print("Error al cargar los itinerarios: $error");
    }
  }

  void _scanQRCode() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRViewExample(),
      ),
    );

    if (result != null) {
      setState(() {
        for (var alumno in alumnos) {
          if (!alumno["verificado"]) {
            alumno["verificado"] = true;
            alumnosVerificados++;
            break; // Salir del bucle después de verificar el primer alumno no verificado
          }
        }
      });
    }
  }

  void _resetCounter() {
    setState(() {
      alumnosVerificados = 0;
      for (var alumno in alumnos) {
        alumno["verificado"] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF3AC5C9),
      endDrawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildBackground(),
          Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: _buildContadorContent(),
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
            onTap: () {
              sendMessage(
                  phone: "+56932157564", message: "Hola! Necesito ayuda");
            },
          ),
          ListTile(
            leading: Icon(Icons.report_problem, color: Colors.teal),
            title: Text('Reportar un Problema'),
            onTap: () {
              sendMessage(
                  phone: "+56932157564", message: "Hola! Necesito ayuda");
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.teal),
            title: Text('Cerrar Sesión'),
            onTap: () {
              logoutUser(context);
            },
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
                widget.login.tourTripulationNameId,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              ),
              Text(widget.login.tourTripulationIdentificationId),
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
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.arrow_back,
                  color: Colors.white, size: 30), // Flecha blanca
              onPressed: () {
                // Navegar a otra ruta cuando la flecha es presionada
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TravelCoordinatorDashboard(
                          login:
                              widget.login)), // Reemplaza con la ruta deseada
                );
              },
            ),
          ),
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
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
    );
  }

  void logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false); // Borrar el estado de la sesión

    // Redirigir al login o realizar otra acción
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WelcomeScreen(),
      ),
    );
  }

  Widget _buildContadorContent() {
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
              'Contador Alumnos',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _scanQRCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: Text(
                "Lector QR",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: _resetCounter,
              child: Text("Reiniciar contador",
                  style: TextStyle(color: Colors.teal)),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$alumnosVerificados/$totalPasajeros",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: alumnos.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Switch(
                      value: alumnos[index]["verificado"],
                      onChanged: (value) {
                        setState(() {
                          if (!alumnos[index]["verificado"] && value) {
                            alumnosVerificados++;
                          } else if (alumnos[index]["verificado"] && !value) {
                            alumnosVerificados--;
                          }
                          alumnos[index]["verificado"] = value;
                        });
                      },
                      activeColor: Colors.green,
                    ),
                    title: Text(alumnos[index]["nombre"]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 35),
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
              buildBottomButton(
                  Icons.connect_without_contact_sharp,
                  'Actividades',
                  null,
                  ActivitiesCoordScreen(login: widget.login)),
              Transform.translate(
                offset:
                    Offset(0, -20), // Ajuste de posición para el botón central
                child: buildBottomButtonHito(Icons.add_circle, 'Hito', null,
                    HitoAddCoordScreen(login: widget.login)),
              ),
              buildBottomButton(Icons.person_add_alt_1, 'Contador', null,
                  CountDownCoordScreen(login: widget.login)),
            ],
          ),
          SizedBox(height: 10), // Espacio entre filas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildBottomButton(Icons.medical_information, 'Fichas Medicas',
                  null, MedicalCoordScreen(login: widget.login)),
              buildBottomButton(Icons.directions_bus, 'Bus & Tripulación', null,
                  BusCrewCoorScreen(login: widget.login)),
              buildBottomButton(Icons.folder_open, 'Mis Documentos', null,
                  DocumentCoordScreen(login: widget.login)),
              buildBottomButton(Icons.book, 'Bitácora del Viaje', null,
                  BitacoraCoordScreen(login: widget.login)),
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

class QRViewExample extends StatefulWidget {
  @override
  _QRViewExampleState createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      controller.pauseCamera(); // Detener la cámara después de escanear
      Navigator.of(context).pop(scanData.code); // Devuelve el código escaneado
    });
  }
}
