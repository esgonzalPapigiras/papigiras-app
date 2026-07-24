import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class TravelPassengerDashboard extends StatefulWidget {
  final ResponseAttorney login;
  TravelPassengerDashboard({required this.login});
  @override
  _TravelPassengerDashboardState createState() => _TravelPassengerDashboardState();
}

class _TravelPassengerDashboardState extends State<TravelPassengerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final usuarioProvider = new CoordinatorProviders();
  String baseUrl = "https://stingray-app-9tqd9.ondigitalocean.app/app/services/get/information/passenger?tourPassenger=";
  XFile? _image;
  String? _imageUrl;

  String formatDate(String date) {
    DateTime parsedDate = DateTime.parse(date);
    String formattedDate = DateFormat('dd-MM-yyyy').format(parsedDate);
    return formattedDate;
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

  bool _isBase64(String data) {
    try {
      base64Decode(data.split(',').last);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFF3AC5C9),
      endDrawer: AppDrawerFather(login: widget.login, imageFile: _image, imageUrl: _imageUrl),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/background.png'), fit: BoxFit.cover),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
              child: Row(
                children: [
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
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(40.0), topRight: Radius.circular(40.0))),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 20),
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _image != null
                            ? FileImage(File(_image!.path)) as ImageProvider<Object>
                            : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                ? (_isBase64(_imageUrl!)
                                    ? MemoryImage(base64Decode(_imageUrl!.split(',').last)) as ImageProvider<Object>
                                    : NetworkImage(_imageUrl!) as ImageProvider<Object>)
                                : AssetImage('assets/profile.jpg') as ImageProvider<Object>,
                      ),
                      SizedBox(height: 10),
                      Text(
                        '${widget.login.passengerName!}\n${widget.login.passengerApellidos!}',
                        style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      Text(widget.login.passengerIdentificacion!, style: TextStyle(fontSize: 14, color: Colors.black)),
                      SizedBox(height: 8),
                      Divider(),
                      SizedBox(height: 100),
                      Center(
                        child: QrImageView(
                          data: jsonEncode({"id": 20, "url": baseUrl + widget.login.passengerId.toString()}),
                          size: 200,
                          embeddedImageStyle: QrEmbeddedImageStyle(size: const Size(100, 100)),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            // Sección inferior de botones
          ],
        ),
      ),
    );
  }

  void logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => WelcomeScreen()), (route) => false);
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
                    child: Text(badge, style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.teal, fontSize: 14)),
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
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }
}
