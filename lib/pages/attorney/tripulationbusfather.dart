import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/attorney/documentsfather.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class BusCrewFatherScreen extends StatefulWidget {
  final ResponseAttorney login;

  BusCrewFatherScreen({required this.login});

  @override
  _BusCrewFatherScreenState createState() => _BusCrewFatherScreenState();
}

class _BusCrewFatherScreenState extends State<BusCrewFatherScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<TourTripulation> _tripulations = [];
  final usuarioProvider = CoordinatorProviders();
  bool _isLoading = true;
  XFile? _image;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _loadTripulations(widget.login.tourId.toString()); // Usar tourSalesId
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

  void sendMessage({required String phone, required String message}) async {
    final whatsappUrl = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      print('No se puede abrir WhatsApp');
      final whatsappDirect = Uri.parse("whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(whatsappDirect)) {
        await launchUrl(whatsappDirect, mode: LaunchMode.externalApplication);
      } else {
        throw 'WhatsApp no está instalado o no puede manejar la URL';
      }
    }
  }

  void logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => WelcomeScreen()), (route) => false);
  }

  Future<void> _loadImage() async {
    try {
      Responseimagepassenger imageUrl = await usuarioProvider.getPicturePassenger(widget.login.passengerIdentificacion.toString(), widget.login.tourId.toString());
      if (imageUrl.image.isNotEmpty) {
        setState(() {
          _imageUrl = imageUrl.image;
        });
      } else {
        setState(() {
          _imageUrl = null;
        });
      }
    } catch (e) {
      setState(() {
        _imageUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFF3AC5C9),
      endDrawer: AppDrawerFather(login: widget.login, imageFile: _image, imageUrl: _imageUrl),
      body: Container(
        decoration: BoxDecoration(image: DecorationImage(image: AssetImage('assets/background.png'), fit: BoxFit.cover)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
            child: Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => TravelFatherDashboard(login: widget.login)));
                    },
                  ),
                ),
                Spacer(),
                Image.asset('assets/logo-letras-papigiras.png', height: 50),
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
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40))),
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text('Bus & Tripulación', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                                SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Image.asset('assets/bus.jpg', width: 100, height: 100, fit: BoxFit.cover),
                                    SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(text: 'Patente: ', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                                TextSpan(
                                                  text: _tripulations.isNotEmpty && _tripulations[0].tourTripulationBusPatent != null
                                                      ? _tripulations[0].tourTripulationBusPatent!
                                                      : "Sin patente",
                                                  style: TextStyle(color: Colors.grey[800]),
                                                ),
                                              ],
                                            ),
                                          ),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(text: 'Marca: ', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                                TextSpan(
                                                  text: _tripulations.isNotEmpty && _tripulations[0].tourTripulationBusBrand != null
                                                      ? _tripulations[0].tourTripulationBusBrand!
                                                      : "Sin marca",
                                                  style: TextStyle(color: Colors.grey[800]),
                                                ),
                                              ],
                                            ),
                                          ),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(text: 'Modelo: ', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                                TextSpan(
                                                  text: _tripulations.isNotEmpty && _tripulations[0].tourTripulationBusModel != null
                                                      ? _tripulations[0].tourTripulationBusModel!
                                                      : "Sin modelo",
                                                  style: TextStyle(color: Colors.grey[800]),
                                                ),
                                              ],
                                            ),
                                          ),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(text: 'Año: ', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                                TextSpan(
                                                  text: _tripulations.isNotEmpty && _tripulations[0].tourTripulationBusYear != null
                                                      ? _tripulations[0].tourTripulationBusYear.toString()
                                                      : "Año no disponible",
                                                  style: TextStyle(color: Colors.grey[800]),
                                                ),
                                              ],
                                            ),
                                          ),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(text: 'Empresa: ', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                                TextSpan(
                                                  text: _tripulations.isNotEmpty && _tripulations[0].tourTripulationBusEnterprise != null
                                                      ? _tripulations[0].tourTripulationBusEnterprise!
                                                      : "Sin empresa",
                                                  style: TextStyle(color: Colors.grey[800]),
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
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _tripulations.length,
                            itemBuilder: (context, index) {
                              final tripulation = _tripulations[index];
                              final role = tripulation.tourTripulationTypeId == 32 ? 'Coordinador' : 'Conductor';
                              final imagePath = role == 'Coordinador'
                                  ? 'assets/profile.jpg'
                                  : index == 0
                                      ? 'assets/conductor_one.jpg'
                                      : index == 1
                                          ? 'assets/conductor_two.jpg'
                                          : 'assets/conductor_three.jpg';
                              final position = role == 'Coordinador' ? 'Coordinador' : 'Licencia Clase A';
                              return _buildCrewMember(
                                role: role,
                                name: tripulation.tourTripulationNameId,
                                position: position,
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
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: 5, blurRadius: 10, offset: Offset(0, -3)),
              ],
            ),
            child: Column(
              children: [
                Divider(height: 1, color: Colors.grey[300]),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 35),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      buildBottomButton(Icons.book, 'Bitácora del Viaje', null, BitacoraFatherScreen(login: widget.login)),
                      buildBottomButton(Icons.directions_bus, 'Bus & Tripulación', null, BusCrewFatherScreen(login: widget.login)),
                      buildBottomButton(Icons.folder_open, 'Mis Documentos', null, DocumentFatherScreen(login: widget.login)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCrewMember({required String role, required String name, required String position, required String id, required String imagePath}) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 20.0),
      leading: Container(
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.fitHeight, alignment: Alignment.center)),
        ),
      ),
      title: Text(role, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
          Text(position, style: TextStyle(color: Colors.grey[600])),
          Text(id, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
      onTap: () {},
    );
  }

  Widget buildBottomButtonHito(IconData icon, String label, String? badge, Widget? destination) {
    return GestureDetector(
      onTap: () {
        if (destination != null) {
          Navigator.of(context).push(_createRoute(destination));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 70, color: Colors.teal), SizedBox(height: 8), Text(label, style: TextStyle(color: Colors.teal, fontSize: 8))],
      ),
    );
  }

  Widget buildBottomButton(IconData icon, String label, String? badge, Widget? destination) {
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
              Icon(icon, size: 40, color: Colors.teal),
              if (badge != null)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: Text(badge, style: TextStyle(color: Colors.white, fontSize: 8)),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.teal, fontSize: 8)),
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
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }
}
