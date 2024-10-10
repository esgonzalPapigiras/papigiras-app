import 'package:flutter/material.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';

class WelcomeFatherScreen extends StatelessWidget {
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
              children: [
                // Logo y nombre de la app
                Image.asset(
                  'assets/logo-papigiras.png',
                  height: 350,
                ),
                SizedBox(height: 20),
                SizedBox(height: 20),
                Text(
                  'Bienvenidos a bordo junto a:',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                SizedBox(height: 10),
                Text(
                  'Carlos Arancibia',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
                    backgroundImage: AssetImage('assets/profile.jpg'),
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => MedicalRecordScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Colors.teal,
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
