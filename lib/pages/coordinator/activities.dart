import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/dto/Itinerary.dart';
import 'package:papigiras_app/dto/RequestActivities.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacleaddlist.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/loginCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ActivitiesCoordScreen extends StatefulWidget {
  @override
  _ActivitiesCoordScreenState createState() => _ActivitiesCoordScreenState();
  final TourSales login;
  ActivitiesCoordScreen({required this.login});
}

class _ActivitiesCoordScreenState extends State<ActivitiesCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Itinerary? selectedActivity;
  List<Itinerary> itineraries = [];
  List<ActivitiesList> activitiesList = [];
  final TextEditingController participantsController = TextEditingController();
  final usuarioProvider = new CoordinatorProviders();

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

  void logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borrar el estado de la sesión

    // Redirigir al login o realizar otra acción
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => WelcomeScreen()),
      (route) =>
          false, // Esto elimina todas las rutas anteriores de la pila de navegación
    );
  }

  @override
  void initState() {
    super.initState();
    // Llama a fetchDocuments al iniciar el widget
    _fetchItineraries(widget.login.tourSalesId.toString());
  }

  Future<void> _fetchItineraries(String tourCode) async {
    try {
      itineraries = await usuarioProvider
          .getItineray(widget.login.tourSalesId.toString());
      // Eliminar duplicados basados en itineraryId
      itineraries = itineraries.toSet().toList();

      if (itineraries.isNotEmpty) {
        selectedActivity =
            itineraries[0]; // Esto asegura que selectedActivity no esté null
      }

      activitiesList = await usuarioProvider
          .getItinerayGuardados(widget.login.tourSalesId.toString());

      setState(() {});
    } catch (error) {
      print("Error al cargar los itinerarios: $error");
    }
  }

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
                  child: FutureBuilder<Widget>(
                future: _buildActivityContent(),
                builder:
                    (BuildContext context, AsyncSnapshot<Widget> snapshot) {
                  // Check the connection state of the future
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // While the future is still loading, show a loading indicator
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    // If there was an error, display an error message
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else {
                    // Once the future is resolved, return the widget from the future
                    return snapshot.data ??
                        SizedBox.shrink(); // Return the resolved widget
                  }
                },
              )),
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
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<Widget> _buildActivityContent() async {
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
            DropdownButtonFormField<Itinerary>(
              value: selectedActivity,
              items: itineraries.map((activity) {
                return DropdownMenuItem<Itinerary>(
                  value: activity,
                  child: Text(
                      activity.itinerary), // Muestra el nombre de la actividad
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedActivity = value;
                });
              },
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
                  onPressed: () async {
                    RequestActivities maintainerList = RequestActivities(
                        activityId: selectedActivity!.itineraryId,
                        quantityPassenger:
                            int.parse(participantsController.text),
                        tourSalesId: widget.login.tourSalesId);
                    await usuarioProvider.activitiesCreate(maintainerList);

                    await _fetchItineraries(
                        widget.login.tourSalesId.toString());

                    setState(() {});

                    QuickAlert.show(
                      context: context,
                      type: QuickAlertType.success,
                      title: 'Éxito',
                      text: 'Agregado con exito',
                      confirmBtnText: 'Continuar',
                      onConfirmBtnTap: () {
                        Navigator.of(context).pop(); // Cierra el QuickAlert
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TravelCoordinatorDashboard(login: widget.login),
                          ),
                        );
                      },
                    );
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
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActivityList() {
    return activitiesList.map((entry) {
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
                  entry.activitiesName,
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
                  entry.quantityPassengerCheck.toString(),
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
          EdgeInsets.symmetric(vertical: 35), // Ajuste del espacio vertical
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
