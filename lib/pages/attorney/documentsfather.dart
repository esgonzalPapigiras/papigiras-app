import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/attorney/tripulationbusfather.dart';
import 'package:papigiras_app/pages/coordinator/activities.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'loginFather.dart';

class DocumentFatherScreen extends StatefulWidget {
  @override
  _DocumentFatherScreenState createState() => _DocumentFatherScreenState();
  final ResponseAttorney login;
  DocumentFatherScreen({required this.login});
}

class _DocumentFatherScreenState extends State<DocumentFatherScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<List<Document>> _documentsFuture;
  final usuarioProvider = new CoordinatorProviders();

  XFile? _image;
  String? _imageUrl;

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
    _loadImage();
    // Llama a fetchDocuments al iniciar el widget
    _documentsFuture = fetchDocuments(widget.login.tourId.toString());
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
      backgroundColor: Color(0xFF3AC5C9), // Fondo turquesa
      endDrawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildBackground(),
          Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: _buildBinnacleContent(),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
    );
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
            leading: Icon(Icons.desktop_access_disabled_outlined,
                color: Colors.teal),
            title: Text(
              'Desactivar Cuenta',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onTap: () {
              QuickAlert.show(
                context: context,
                type:
                    QuickAlertType.error, // Cambiar a 'error' para la cruz roja
                title: 'Eliminar Cuenta',
                text: 'Desactivar tu cuenta no te permitirá ingresar más',
                confirmBtnText: 'Continuar',
                onConfirmBtnTap: () {
                  usuarioProvider.desactivateAccount(
                      widget.login.passengerIdentificacion.toString());

                  logoutUser(context); // Cierra el QuickAlert
                },
              );
              // Acción para cerrar sesión
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
            backgroundImage: _image != null
                ? FileImage(File(_image!.path)) as ImageProvider<
                    Object> // Imagen seleccionada desde el dispositivo
                : (_imageUrl != null && _imageUrl!.isNotEmpty)
                    ? (_isBase64(
                            _imageUrl!) // Verifica si la URL es una imagen en Base64
                        ? MemoryImage(base64Decode(_imageUrl!.split(',').last))
                            as ImageProvider<
                                Object> // Decodifica y muestra imagen Base64
                        : NetworkImage(_imageUrl!) as ImageProvider<
                            Object>) // Carga imagen desde el servidor
                    : AssetImage('assets/profile.jpg')
                        as ImageProvider<Object>, // Imagen predeterminada
          ),
          SizedBox(width: 16),
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
                      builder: (context) => TravelFatherDashboard(
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

  Widget _buildBinnacleContent() {
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
          _buildFilterOptions(),
          SizedBox(height: 20),
          Expanded(
            child: _buildBinnacleEntries(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Centra el texto
      children: [
        Text(
          'Mis Documentos',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Future<List<Document>> fetchDocuments(String tourCode) async {
    try {
      List<Document> documents = await usuarioProvider.getDocument(tourCode);
      documents
          .removeWhere((document) => document.documentType == 'Nomina alumnos');
      return documents; // Devuelve la lista de documentos
    } catch (e) {
      print('Error: $e');
      return []; // Devuelve una lista vacía en caso de error
    }
  }

  Widget _buildBinnacleEntries() {
    return FutureBuilder<List<Document>>(
      future: _documentsFuture, // Usamos _documentsFuture aquí
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No documents found.'));
        }

        List<Document> documents = snapshot.data!;

        return ListView.builder(
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final document = documents[index];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: ListTile(
                leading: Icon(
                  _getIconForDocumentType(document.documentType),
                  color: Colors.teal,
                  size: 40,
                ),
                title: Text(
                  document.documentType ?? 'Sin nombre',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_red_eye, color: Colors.teal),
                      onPressed: () {
                        usuarioProvider.viewDocument(
                            document.tourSalesUuid,
                            document.documentName!,
                            widget.login.tourId.toString(),
                            context,
                            "documentosextras");
                        // Acción para descargar el documento
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.download, color: Colors.teal),
                      onPressed: () async {
                        await usuarioProvider.downloadDocument(
                            document.tourSalesUuid,
                            document.documentName!,
                            widget.login.tourId.toString(),
                            "documentosextras");
                        QuickAlert.show(
                          context: context,
                          type: QuickAlertType.success,
                          title: 'Éxito',
                          text: 'Documento Descargado',
                          confirmBtnText: 'Continuar',
                          onConfirmBtnTap: () {
                            Navigator.of(context).pop(); // Cierra el QuickAlert
                          },
                        );
                        // Acción para descargar el documento
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getIconForDocumentType(String documentType) {
    switch (documentType) {
      case 'poliza':
        return Icons.policy;
      case 'gira':
        return Icons.description;
      case 'hotel':
        return Icons.hotel;
      case 'Programa gira':
        return Icons.description;
      case 'Nomina alumnos':
        return Icons.people;
      default:
        return Icons.description; // Icono por defecto si no coincide
    }
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
          // Espacio entre filas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildBottomButton(Icons.book, 'Bitácora del Viaje', null,
                  BitacoraFatherScreen(login: widget.login)),
              buildBottomButton(Icons.directions_bus, 'Bus & Tripulación', null,
                  BusCrewFatherScreen(login: widget.login)),
              buildBottomButton(Icons.folder_open, 'Mis Documentos', null,
                  DocumentFatherScreen(login: widget.login)),
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
