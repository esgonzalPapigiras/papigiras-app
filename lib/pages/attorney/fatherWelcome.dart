import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class WelcomeFatherScreen extends StatefulWidget {
  final ResponseAttorney login;
  WelcomeFatherScreen({required this.login});
  @override
  _WelcomeFatherScreenState createState() => _WelcomeFatherScreenState();
}

class _WelcomeFatherScreenState extends State<WelcomeFatherScreen> {
  final usuarioProvider = new CoordinatorProviders();
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
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/background.png', fit: BoxFit.cover)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight, minWidth: constraints.maxWidth),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 20),
                        Image.asset('assets/logo-papigiras.png', height: 350),
                        SizedBox(height: 20),
                        Text('Bienvenidos a bordo junto a:', style: TextStyle(fontSize: 16, color: Colors.white)),
                        SizedBox(height: 10),
                        Text(
                          '${widget.login.passengerName} ${widget.login.passengerApellidos}',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundImage: _image != null
                                ? FileImage(File(_image!.path)) as ImageProvider<Object>
                                : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                    ? (_isBase64(_imageUrl!)
                                        ? MemoryImage(base64Decode(_imageUrl!.split(',').last)) as ImageProvider<Object>
                                        : NetworkImage(_imageUrl!) as ImageProvider<Object>)
                                    : AssetImage('assets/profile.jpg') as ImageProvider<Object>,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text('¡Emprenderemos este viaje inolvidable!', style: TextStyle(fontSize: 16, color: Colors.white)),
                        SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: () async {
                            if (await usuarioProvider.validateMedicalRecord(widget.login.passengerId.toString())) {
                              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => TravelFatherDashboard(login: widget.login)), (route) => false);
                            } else {
                              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MedicalRecordScreen(login: widget.login)), (route) => false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          ),
                          child: Text('Continuar', style: TextStyle(fontSize: 18.0, color: Colors.white)),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
