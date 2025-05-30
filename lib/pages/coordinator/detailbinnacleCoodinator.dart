import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';

class DetalleBitacoraCoordScreen extends StatefulWidget {
  @override
  _DetalleBitacoraCoordScreenState createState() =>
      _DetalleBitacoraCoordScreenState();
  final TourSales login;
  final String idHito;
  DetalleBitacoraCoordScreen({required this.idHito, required this.login});
}

class _DetalleBitacoraCoordScreenState
    extends State<DetalleBitacoraCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final usuarioProvider = new CoordinatorProviders();
  Future<DetailHitoList>? _hitoDetailFuture;

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
    // Borrar el estado de la sesión

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final locationService =
        Provider.of<LocationService>(context, listen: false);
    locationService.stopTracking();

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
    // Inicia la llamada al servicio para obtener los detalles del hito
    _hitoDetailFuture = usuarioProvider.getHitoComplete(
        widget.idHito.toString(), widget.login.tourSalesId.toString());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationService>().startTracking();
    });
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
                child: FutureBuilder<DetailHitoList>(
                  future: _hitoDetailFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      DetailHitoList hitoDetail = snapshot.data!;
                      return _buildBinnacleContent(hitoDetail);
                    } else {
                      return Center(child: Text('No data available'));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildBinnacleContent(DetailHitoList hitoDetail) {
    return Container(
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
          SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: _buildBinnacleEntries(hitoDetail),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBinnacleEntries(DetailHitoList hitoDetail) {
    List<Map<String, dynamic>> entries = [];
    String time = hitoDetail.hora ?? 'Sin hora';
    String activity = hitoDetail.titulo ?? 'Actividad no disponible';
    String description = hitoDetail.descripcion ?? 'Descripción no disponible';
    entries.add({
      'time': time,
      'activity': activity,
      'description': description,
      'images': hitoDetail.images, // Lista de imágenes
    });

    // Mapear las entradas a los widgets
    return entries.map((entry) {
      return Card(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.place, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    entry['time']!,
                    style: TextStyle(
                        color: Colors.teal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Text(
                    entry['activity']!,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                entry['description']!,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              SizedBox(height: 16),
              // Mostrar todas las imágenes dinámicamente dependiendo de la cantidad
              Column(
                children: [
                  // Aquí mapeamos las imágenes de la lista 'images' de la entrada
                  for (var imageBase64 in entry['images'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Center(
                        child: Image.memory(
                          base64Decode(imageBase64.split(',').last),
                          fit: BoxFit
                              .cover, // Ajusta la forma en que se escala la imagen
                          height: 200, // Altura específica de la imagen
                          width: 200, // Ancho específico de la imagen
                        ),
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
      );
    }).toList();
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
