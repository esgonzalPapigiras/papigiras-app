import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';
import 'package:papigiras_app/pages/coordinator/activities.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/loginCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class BusCrewCoorScreen extends StatefulWidget {
  final TourSales login;

  BusCrewCoorScreen({required this.login});

  @override
  _BusCrewCoorScreenState createState() => _BusCrewCoorScreenState();
}

class _BusCrewCoorScreenState extends State<BusCrewCoorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<TourTripulation> _tripulations = [];
  final usuarioProvider = CoordinatorProviders();
  bool _isLoading = true;

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

  Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryDateString = prefs.getString('expiryDate');
    if (expiryDateString == null) return false;

    final expiryDate = DateTime.parse(expiryDateString);
    return DateTime.now().isBefore(expiryDate);
  }

  void logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borrar el estado de la sesión

    // Redirigir al login o realizar otra acción
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginCoordinator()),
      (route) =>
          false, // Esto elimina todas las rutas anteriores de la pila de navegación
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTripulations(widget.login.tourSalesId.toString()); // Usar tourSalesId
  }

  Future<void> _loadTripulations(String tourCode) async {
    try {
      _tripulations = await usuarioProvider.getTripulation(tourCode);
    } catch (e) {
      print('Error al cargar la tripulación: $e');
    } finally {
      setState(() {
        _isLoading = false; // Cambia el estado de carga
      });
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
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: AssetImage('assets/profile.jpg'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.login.tourTripulationNameId,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                      Text(widget.login.tourTripulationIdentificationId),
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
                logoutUser(context);
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
            padding:
                const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
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
                                login: widget
                                    .login)), // Reemplaza con la ruta deseada
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
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
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
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Image.asset(
                                      'assets/bus.jpg',
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
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                TextSpan(
                                                  text: _tripulations[0]
                                                      .tourTripulationBusPatent,
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
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                TextSpan(
                                                  text: _tripulations[0]
                                                      .tourTripulationBusBrand,
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
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                TextSpan(
                                                  text: _tripulations[0]
                                                      .tourTripulationBusModel,
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
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                TextSpan(
                                                  text: _tripulations[0]
                                                      .tourTripulationBusYear,
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
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                TextSpan(
                                                  text: _tripulations[0]
                                                      .tourTripulationBusEnterprise,
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
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _tripulations.length,
                            itemBuilder: (context, index) {
                              final tripulation = _tripulations[index];
                              String role =
                                  tripulation.tourTripulationTypeId == 32
                                      ? 'Coordinador'
                                      : 'Conductor';
                              String imagePath =
                                  tripulation.tourTripulationTypeId == 32
                                      ? 'assets/conductor_one.jpg'
                                      : 'assets/conductor_two.jpg';
                              return _buildCrewMember(
                                role: role,
                                name: tripulation.tourTripulationNameId,
                                position: 'Licencia Clase A',
                                id: tripulation.tourTripulationIdentificationId,
                                imagePath: imagePath,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Container(
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
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildBottomButton(
                      Icons.connect_without_contact_sharp,
                      'Actividades',
                      null,
                      ActivitiesCoordScreen(login: widget.login),
                    ),
                    Transform.translate(
                      offset: Offset(0, -30),
                      child: buildBottomButtonHito(
                        Icons.add_circle,
                        'Hito',
                        null,
                        HitoAddCoordScreen(login: widget.login),
                      ),
                    ),
                    buildBottomButton(
                      Icons.person_add_alt_1,
                      'Contador',
                      null,
                      CountDownCoordScreen(login: widget.login),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildBottomButton(
                      Icons.medical_information,
                      'Fichas Medicas',
                      null,
                      MedicalCoordScreen(login: widget.login),
                    ),
                    buildBottomButton(
                      Icons.directions_bus,
                      'Bus & Tripulación',
                      null,
                      BusCrewCoorScreen(login: widget.login),
                    ),
                    buildBottomButton(
                      Icons.folder_open,
                      'Mis Documentos',
                      null,
                      DocumentCoordScreen(login: widget.login),
                    ),
                    buildBottomButton(
                      Icons.book,
                      'Bitácora del Viaje',
                      null,
                      BitacoraCoordScreen(login: widget.login),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ),
    );
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
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.teal,
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: AssetImage(imagePath),
              fit: BoxFit.fitHeight,
              alignment: Alignment.center,
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

  Route _createRoute(Widget destination) {
    return PageRouteBuilder(
      transitionDuration: Duration(milliseconds: 1000),
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
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
