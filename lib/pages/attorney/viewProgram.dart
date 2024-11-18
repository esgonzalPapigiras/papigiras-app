import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ProgramViewDto.dart';
import 'package:papigiras_app/dto/requestMedicalRecord.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/attorney/loginFather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewProgramScreen extends StatefulWidget {
  final ResponseAttorney login;
  ViewProgramScreen({required this.login});
  @override
  _ViewProgramScreenState createState() => _ViewProgramScreenState();
}

class _ViewProgramScreenState extends State<ViewProgramScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final usuarioProvider = new CoordinatorProviders();
  final TextEditingController _alergiasController = TextEditingController();
  final TextEditingController _enfermedadesController = TextEditingController();
  final TextEditingController _medicamentosController = TextEditingController();
  Future<ProgramViewDto>? _hitoDetailFuture;

  @override
  void initState() {
    super.initState();
    // Inicia la llamada al servicio para obtener los detalles del hito
    _hitoDetailFuture =
        usuarioProvider.getviewProgram(widget.login.tourId.toString());
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
                        widget.login.passengerName! +
                            " " +
                            widget.login.passengerApellidos!,
                        style: TextStyle(
                          fontSize: 18,
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
                              builder: (context) => TravelFatherDashboard(
                                  login: widget
                                      .login)), // Reemplaza con la ruta deseada
                        );
                      },
                    ),
                  ),
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
              child: FutureBuilder<ProgramViewDto>(
                future: _hitoDetailFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (snapshot.hasData) {
                    final programView = snapshot.data;

                    return SingleChildScrollView(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(40),
                              topRight: Radius.circular(40)),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Programa',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800]),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.teal,
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
                                      widget.login.passengerName! +
                                          " " +
                                          widget.login.passengerApellidos!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800]),
                                    ),
                                    Text(
                                      widget.login.passengerIdentificacion!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Divider(),
                            SizedBox(height: 10),
                            buildInfoSection(
                                'Curso',
                                programView?.courseClient ?? "",
                                programView?.nameClient ?? "",
                                programView?.seasonClient.toString() ?? ""),
                            SizedBox(height: 10),
                            buildInfoSectionEnfermedades(
                                'Fecha de Ida y Vuelta',
                                programView?.tourInit ?? "",
                                programView?.tourEnd ?? ""),
                            SizedBox(height: 10),
                            buildInfoSectionMedicamentos(
                                'Actividades de la Gira',
                                programView?.activities),
                            SizedBox(height: 200),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return Center(child: Text('No se encontraron datos'));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInfoSection(String title, String courseClient, String nameClient,
      String seasonClient) {
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
          child: SingleChildScrollView(
            // Permite desplazamiento si el texto es largo
            child: Text(
              nameClient +
                  " " +
                  courseClient +
                  " " +
                  seasonClient, // Muestra el contenido con los saltos de línea
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildInfoSectionEnfermedades(String title, String init, String end) {
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
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Columna de "Fecha de salida" centrada
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Centra la columna
                children: [
                  Text(
                    'Fecha de salida:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  Align(
                    alignment:
                        Alignment.center, // Centra el texto dentro del widget
                    child: Text(
                      init,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
              // Columna de "Fecha de regreso"
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Centra la columna
                children: [
                  Text(
                    'Fecha de regreso:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  Align(
                    alignment:
                        Alignment.center, // Centra el texto dentro del widget
                    child: Text(
                      end,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildInfoSectionMedicamentos(String title, List<String>? result) {
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
        SizedBox(height: 1),
        Container(
          constraints: BoxConstraints(
            maxHeight:
                400, // Esto asegura que el contenedor no se expanda más allá de la altura deseada
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.all(3),
          child: result == null || result.isEmpty
              ? Center(
                  child: Text(
                    'No hay actividades disponibles.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  itemCount: result.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(result[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget buildBottomButton(IconData icon, String label, String? badge) {
    return GestureDetector(
      onTap: () {
        print('$label presionado');

        if (label == 'Bitácora del Viaje') {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => BitacoraFatherScreen(
                      login: widget.login,
                    )),
          );
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
}
