import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
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
  final usuarioProvider = new CoordinatorProviders();
  List<XFile> _imageFiles = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

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
    final chileTime = now.toUtc().add(Duration(hours: -3));
    final formatter = DateFormat('HH:mm');
    setState(() {
      _formattedTime = formatter.format(chileTime);
    });
  }

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
        _location = 'Error al obtener ubicación: $e';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
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

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      int sdkInt = androidInfo.version.sdkInt ?? 0;
      if (sdkInt < 33) {
        PermissionStatus status = await Permission.storage.status;
        if (status.isDenied || status.isLimited) {
          PermissionStatus newStatus = await Permission.storage.request();
          if (!newStatus.isGranted) {
            if (newStatus.isPermanentlyDenied) {
              print("Permiso permanentemente denegado, solicita al usuario ir a configuración");
              openAppSettings();
            }
            return;
          }
        }
      }
    }
    await pickImage();
  }

  Future<void> requestCameraPermission() async {
    PermissionStatus status = await Permission.camera.status;
    if (!status.isGranted) {
      final newStatus = await Permission.camera.request();
      if (!newStatus.isGranted) {
        print("Permiso de cámara no otorgado");
        return;
      }
    }
    pickCameraPhoto();
  }

  Future<void> pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFiles.add(pickedFile);
        });
        print("Imagen seleccionada: ${pickedFile.path}");
      } else {
        print("No se seleccionó ninguna imagen");
      }
    } catch (e) {
      print("Error al seleccionar imagen: $e");
    }
  }

  Future<void> pickMultipleImages() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _imageFiles.addAll(images);
        });
        print("Imagenes seleccionadas: ${images.map((e) => e.path)}");
      } else {
        print("No se seleccionaron imágenes");
      }
    } catch (e) {
      print("Error al seleccionar múltiples imágenes: $e");
    }
  }

  Future<void> pickCameraPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _imageFiles.add(photo);
        });
        print("Foto tomada: ${photo.path}");
      } else {
        print("No se tomó ninguna foto");
      }
    } catch (e) {
      print("Error al tomar foto: $e");
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
              _buildTextField('Título', 'Escribe un Título', controller: tituloController),
              SizedBox(height: 16),
              _buildTextField('Descripción', 'Escribe una Descripción', controller: descripcionController, maxLength: 140),
              SizedBox(height: 16),
              Text('Agregar Fotos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [_buildCameraButton(), _buildMultiSelectButton(), ...List.generate(10, (index) => _buildAddPhotoButton(index))],
              ),
              SizedBox(height: 15),
              Text('Ubicación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(_location, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              SizedBox(height: 16),
              _buildTextField('Nota al cierre', 'Escribe una Nota al Cierre', controller: notaCierreController),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                          });
                          QuickAlert.show(context: context, type: QuickAlertType.loading, title: 'Estamos cargando', text: 'Por favor espere un momento');
                          if (tituloController.text.isEmpty || descripcionController.text.isEmpty) {
                            Navigator.of(context).pop();
                            QuickAlert.show(
                                context: context,
                                type: QuickAlertType.error,
                                title: 'Error',
                                text: 'Por favor complete todos los campos',
                                confirmBtnText: 'OK',
                                onConfirmBtnTap: () {
                                  Navigator.of(context).pop();
                                });
                            setState(() {
                              _isLoading = false;
                            });
                            return;
                          }
                          DateTime now = DateTime.now();
                          String formattedDate = DateFormat('dd/MM/yyyy').format(now);
                          RequestHito hito = RequestHito(
                              titulo: tituloController.text,
                              descripcion: descripcionController.text,
                              ubicacion: _location,
                              notaCierre: notaCierreController.text.isEmpty ? "." : notaCierreController.text,
                              latitud: position.latitude.toString(),
                              longitud: position.longitude.toString(),
                              hora: _formattedTime,
                              idTour: widget.login.tourSalesId,
                              fecha: formattedDate);
                          await Future.delayed(Duration(seconds: 5));
                          var consolidate = await usuarioProvider.addHito(hito);
                          if (consolidate != null) {
                            await usuarioProvider.addHitoFoto(consolidate.binnacleDetailId, widget.login.tourSalesId.toString(), _imageFiles);
                            Navigator.of(context).pop();
                            QuickAlert.show(
                              context: context,
                              type: QuickAlertType.success,
                              title: 'Éxito',
                              text: 'Hito agregado con éxito',
                              confirmBtnText: 'Continuar',
                              onConfirmBtnTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              },
                            );
                          } else {
                            Navigator.of(context).pop();
                            QuickAlert.show(
                                context: context,
                                type: QuickAlertType.error,
                                title: 'Error',
                                text: 'No se pudo agregar el hito, intente nuevamente',
                                confirmBtnText: 'OK',
                                onConfirmBtnTap: () {
                                  Navigator.of(context).pop();
                                });
                          }
                          setState(() {
                            _isLoading = false;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3AC5C9),
                      padding: EdgeInsets.symmetric(horizontal: 60, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: _isLoading
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Agregar', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {TextEditingController? controller, int maxLength = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLength == 1 ? 1 : null,
          maxLength: maxLength > 1 ? maxLength : null,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
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
        onTap: requestPermissions, // Al hacer clic, abre la galería
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
          child:
              _imageFiles.isNotEmpty && index < _imageFiles.length ? Image.file(File(_imageFiles[index].path), fit: BoxFit.cover) : Icon(Icons.add, color: Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildMultiSelectButton() {
    return GestureDetector(
      onTap: pickMultipleImages,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.collections, color: Colors.green),
      ),
    );
  }

  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: requestCameraPermission,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(border: Border.all(color: Colors.blue), borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.camera_alt, color: Colors.blue),
      ),
    );
  }
}
