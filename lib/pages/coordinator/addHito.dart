import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class HitoAddCoordScreen extends StatefulWidget {
  @override
  _HitoAddCoordScreenState createState() => _HitoAddCoordScreenState();
}

class _HitoAddCoordScreenState extends State<HitoAddCoordScreen> {
  String _formattedTime = '';
  String _location = 'Obteniendo ubicación...';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _getCurrentTimeInChile();
    _checkLocationService();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Actualiza la hora cada minuto
  void _getCurrentTimeInChile() {
    final now = DateTime.now();
    final chileTime =
        now.toUtc().add(Duration(hours: -3)); // Ajuste para UTC-3 (Chile)
    final formatter = DateFormat('HH:mm');
    setState(() {
      _formattedTime =
          formatter.format(chileTime); // Formatea la hora como '20:30'
    });
  }

  // Verifica servicios de ubicación y obtiene la dirección en tiempo real
  Future<void> _checkLocationService() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _location = 'Los servicios de ubicación están deshabilitados.';
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _location = 'Permiso de ubicación denegado.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _location = 'Permiso de ubicación permanentemente denegado.';
        });
        return;
      }

      _getCurrentLocation();
    } catch (e) {
      setState(() {
        print(e);
        _location = 'Error al obtener ubicación: $e';
      });
    }
  }

  // Obtiene la posición y convierte a una dirección legible
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        setState(() {
          _location = '${place.street}, ${place.locality}, ${place.country}';
        });
      } else {
        setState(() {
          _location = 'No se pudo obtener la dirección';
        });
      }
    } catch (e) {
      setState(() {
        _location = 'Error al obtener la posición: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '$_formattedTime Agregar Hito',
          style: TextStyle(
            color: Color(0xFF3AC5C9),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField('Título', 'Escribe un Título'),
              SizedBox(height: 16),
              _buildTextField('Descripción', 'Escribe una Descripción',
                  maxLength: 140),
              SizedBox(height: 16),
              Text(
                'Agregar Fotos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(3, (index) => _buildAddPhotoButton())
                    .toList(),
              ),
              SizedBox(height: 16),
              Text(
                'Ubicación',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                _location,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              SizedBox(height: 16),
              _buildTextField('Nota al cierre', 'Escribe un Título'),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3AC5C9),
                    padding: EdgeInsets.symmetric(horizontal: 60, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Agregar',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {int maxLength = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        TextFormField(
          maxLines: maxLength == 1 ? 1 : null,
          maxLength: maxLength > 1 ? maxLength : null,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.add, color: Colors.grey[500]),
      ),
    );
  }
}
