import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'dart:async';

import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickalert/quickalert.dart';

class HitoAddCoordScreen extends StatefulWidget {
  @override
  _AddHitoScreenState createState() => _AddHitoScreenState();
  final TourSales login;
  HitoAddCoordScreen({required this.login});
}

class _AddHitoScreenState extends State<HitoAddCoordScreen> {
  final TextEditingController tituloController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController ubicacionController = TextEditingController();
  final TextEditingController notaCierreController = TextEditingController();
  final TextEditingController latitudController = TextEditingController();
  final TextEditingController longitudController = TextEditingController();
  final TextEditingController horaController = TextEditingController();

  String _formattedTime = '';
  String _location = 'Obteniendo ubicación...';
  Timer? _timer;
  late Position position;

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

  Future<void> _getCurrentLocation() async {
    try {
      position = await Geolocator.getCurrentPosition(
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

  final usuarioProvider = new CoordinatorProviders();
  List<XFile> _imageFiles =
      []; // Lista para almacenar las imágenes seleccionadas
  final ImagePicker _picker = ImagePicker();
  late ConsolidatedTourSalesDTO consolidate; // Instancia de ImagePicker

  Future<void> _pickImage() async {
    // Solicitar permiso de acceso completo al almacenamiento
    PermissionStatus status = await Permission.manageExternalStorage.request();

    if (status.isGranted) {
      // Si el permiso es concedido, puedes acceder a la galería o al almacenamiento completo
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFiles.add(pickedFile);
        });
      }
    } else {
      // Si el permiso es denegado, muestra un mensaje
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Permiso Denegado',
        text:
            'No se puede acceder al almacenamiento completo. Habilita el permiso en la configuración.',
        confirmBtnText: 'Ir a Configuración',
        onConfirmBtnTap: () async {
          // Abre la configuración de la aplicación para permitir que el usuario habilite el permiso
          await openAppSettings();
          Navigator.of(context).pop(); // Cierra el QuickAlert
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Agregar Hito')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField('Título', 'Escribe un Título',
                  controller: tituloController),
              SizedBox(height: 16),
              _buildTextField('Descripción', 'Escribe una Descripción',
                  controller: descripcionController, maxLength: 140),
              SizedBox(height: 16),
              Text(
                'Agregar Fotos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children:
                    List.generate(3, (index) => _buildAddPhotoButton(index))
                        .toList(),
              ),
              SizedBox(height: 15),
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
              _buildTextField('Nota al cierre', 'Escribe una Nota al Cierre',
                  controller: notaCierreController),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    // Validaciones de los campos
                    if (tituloController.text.isEmpty ||
                        descripcionController.text.isEmpty ||
                        ubicacionController.text.isEmpty ||
                        notaCierreController.text.isEmpty ||
                        latitudController.text.isEmpty ||
                        longitudController.text.isEmpty ||
                        horaController.text.isEmpty) {
                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.error,
                        title: 'Error',
                        text: 'Por favor complete todos los campos',
                        confirmBtnText: 'OK',
                        onConfirmBtnTap: () {
                          Navigator.of(context).pop(); // Cierra el QuickAlert
                        },
                      );
                      return;
                    }

                    // Crear el objeto RequestHito
                    RequestHito hito = RequestHito(
                      titulo: tituloController.text,
                      descripcion: descripcionController.text,
                      ubicacion: _location,
                      notaCierre: notaCierreController.text,
                      latitud: position.latitude.toString(),
                      longitud: position.longitude.toString(),
                      hora: _timer.toString(),
                      idTour: widget.login.tourSalesId,
                    );

                    // Llamada al método para agregar el Hito
                    consolidate = await usuarioProvider.addHito(hito);
                    if (consolidate != null) {
                      await usuarioProvider.addHitoFoto(
                          consolidate.binnacleDetailId,
                          widget.login.tourSalesId.toString(),
                          _imageFiles);
                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.success,
                        title: 'Éxito',
                        text: 'Hito agregado con éxito',
                        confirmBtnText: 'Continuar',
                        onConfirmBtnTap: () {
                          Navigator.of(context).pop(); // Cierra el QuickAlert
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TravelCoordinatorDashboard(
                                  login: widget.login),
                            ),
                          );
                        },
                      );
                    }

                    // Mostrar un mensaje de éxito
                  },
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
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint,
      {TextEditingController? controller, int maxLength = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
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

  Widget _buildAddPhotoButton(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: _pickImage, // Al hacer clic, abre la galería
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _imageFiles.isNotEmpty && index < _imageFiles.length
              ? Image.file(
                  File(_imageFiles[index]
                      .path), // Muestra la imagen seleccionada
                  fit: BoxFit.cover,
                )
              : Icon(
                  Icons.add,
                  color: Colors.grey[500],
                ),
        ),
      ),
    );
  }
}
