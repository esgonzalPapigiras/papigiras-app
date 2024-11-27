import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
      String imageUrl = await usuarioProvider.getPicturePassenger(
          widget.login.passengerId.toString(), widget.login.tourId.toString());
      setState(() {
        _imageUrl = imageUrl; // Si la imagen existe, la cargamos
      });
    } catch (e) {
      setState(() {
        _imageUrl = null; // Si no hay imagen, usar la imagen predeterminada
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage(); // Cargar la imagen al inicio
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xFF3AC5C9),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment
                  .center, // Esto asegura que el contenido se alinee horizontalmente
              children: [
                // Logo y nombre de la app
                Image.asset(
                  'assets/logo-papigiras.png',
                  height: 350,
                ),
                SizedBox(height: 20),
                Text(
                  'Bienvenidos a bordo junto a:',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                SizedBox(height: 10),
                // Nombre del pasajero centrado
                Text(
                  widget.login.passengerName! +
                      " " +
                      widget.login.passengerApellidos!,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign:
                      TextAlign.center, // Asegura que el texto esté centrado
                ),
                SizedBox(height: 20),
                // Imagen de perfil
                Container(
                  padding: EdgeInsets.all(4), // Ancho del borde
                  decoration: BoxDecoration(
                    color: Colors.white, // Color del borde
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: _image != null
                        ? FileImage(File(_image!.path))
                            as ImageProvider<Object> // Imagen seleccionada
                        : _imageUrl != null
                            ? NetworkImage(_imageUrl!) as ImageProvider<
                                Object> // Imagen desde el servidor
                            : AssetImage('assets/profile.jpg')
                                as ImageProvider<Object>, // Imagen por defecto
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '¡Emprenderemos este viaje inolvidable!',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                SizedBox(height: 40),
                // Botón de continuación
                ElevatedButton(
                  onPressed: () async {
                    if (await usuarioProvider.validateMedicalRecord(
                        widget.login.passengerId.toString())) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                TravelFatherDashboard(login: widget.login)),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                MedicalRecordScreen(login: widget.login)),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: Text(
                    'Continuar',
                    style: TextStyle(fontSize: 18.0, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
