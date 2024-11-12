import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:papigiras_app/dto/TourSales.dart';
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

  final usuarioProvider = new CoordinatorProviders();
  List<XFile> _imageFiles =
      []; // Lista para almacenar las imágenes seleccionadas
  final ImagePicker _picker = ImagePicker(); // Instancia de ImagePicker

  Future<void> _pickImage() async {
    PermissionStatus status = await Permission.photos.request();

    if (status.isGranted) {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _imageFiles.add(pickedFile);
        });
      }
    } else {
      // Si el permiso es denegado, muestra un alerta con la opción de ir a la configuración
      Permission.photos.request();
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
              SizedBox(height: 16),
              _buildTextField('Ubicación', 'Escribe una Ubicación',
                  controller: ubicacionController),
              SizedBox(height: 16),
              _buildTextField('Nota al cierre', 'Escribe una Nota al Cierre',
                  controller: notaCierreController),
              SizedBox(height: 16),
              _buildTextField('Latitud', 'Escribe la Latitud',
                  controller: latitudController),
              SizedBox(height: 16),
              _buildTextField('Longitud', 'Escribe la Longitud',
                  controller: longitudController),
              SizedBox(height: 16),
              _buildTextField('Hora', 'Escribe la Hora',
                  controller: horaController),
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
                      ubicacion: ubicacionController.text,
                      notaCierre: notaCierreController.text,
                      latitud: latitudController.text,
                      longitud: longitudController.text,
                      hora: horaController.text,
                      idTour: widget.login.tourSalesId,
                    );

                    // Llamada al método para agregar el Hito
                    await usuarioProvider.addHito(hito);

                    // Mostrar un mensaje de éxito
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
                            builder: (context) =>
                                TravelCoordinatorDashboard(login: widget.login),
                          ),
                        );
                      },
                    );
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
