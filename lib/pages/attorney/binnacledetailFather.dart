import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/FullscreenImageFather.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class DetalleBitacoraFatherScreen extends StatefulWidget {
  @override
  _DetalleBitacoraFatherScreenState createState() => _DetalleBitacoraFatherScreenState();
  final ResponseAttorney login;
  final String idHito;
  DetalleBitacoraFatherScreen({required this.idHito, required this.login});
}

class _DetalleBitacoraFatherScreenState extends State<DetalleBitacoraFatherScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final usuarioProvider = new CoordinatorProviders();
  Future<DetailHitoList>? _hitoDetailFuture;
  XFile? _image;
  String? _imageUrl;

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

  @override
  void initState() {
    super.initState();
    _loadImage();
    _hitoDetailFuture = usuarioProvider.getHitoComplete(widget.idHito.toString(), widget.login.tourId.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFF3AC5C9),
      endDrawer: AppDrawerFather(login: widget.login, imageFile: _image, imageUrl: _imageUrl),
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

  void logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => WelcomeScreen()), (route) => false);
  }

  Widget _buildBackground() {
    return Container(decoration: BoxDecoration(image: DecorationImage(image: AssetImage('assets/background.png'), fit: BoxFit.cover)));
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => BitacoraFatherScreen(login: widget.login)));
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
    );
  }

  Widget _buildBinnacleContent(DetailHitoList hitoDetail) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40))),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SizedBox(height: 20), Expanded(child: ListView(children: _buildBinnacleEntries(hitoDetail)))],
      ),
    );
  }

  List<Widget> _buildBinnacleEntries(DetailHitoList hitoDetail) {
    List<Map<String, dynamic>> entries = [];
    for (var i = 0; i < hitoDetail.images!.length; i++) {
      String base64Image = hitoDetail.images![i];
    }
    String time = hitoDetail.fecha ?? 'Sin hora';
    String activity = hitoDetail.titulo ?? 'Actividad no disponible';
    String description = hitoDetail.descripcion ?? 'Descripción no disponible';
    entries.add({'time': time, 'activity': activity, 'description': description, 'images': hitoDetail.images});
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
                  Text(entry['time']!, style: TextStyle(color: Colors.teal, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Text(entry['activity']!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: 8),
              Text(entry['description']!, style: TextStyle(color: Colors.grey, fontSize: 14)),
              SizedBox(height: 16),
              Column(
                children: [
                  for (var imageBase64 in entry['images'])
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenImagePage(imageBytes: base64Decode(imageBase64.split(',').last))));
                      },
                      child: Image.memory(base64Decode(imageBase64.split(',').last), height: 200, width: 200, fit: BoxFit.cover),
                    ),
                ],
              )
            ],
          ),
        ),
      );
    }).toList();
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
        children: [Icon(icon, size: 40, color: Colors.teal), SizedBox(height: 8), Text(label, style: TextStyle(color: Colors.teal, fontSize: 8))],
      ),
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
