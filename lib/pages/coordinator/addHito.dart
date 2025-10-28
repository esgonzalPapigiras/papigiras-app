import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
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
  List<XFile> _imageFiles =
      []; // Lista para almacenar las imágenes seleccionadas
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _getCurrentTimeInChile();
    _checkLocationService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationService>().startTracking();
    });
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
      // Comentar o descomentar esta línea según tu caso:
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _location = 'Los servicios de ubicación están deshabilitados.';
        });
        return;
      }

      // Verificar permisos
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

      // Obtener la ubicación
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

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

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

/*
  // Permiso para acceder a la galería
  Future<void> requestPermissions() async {
    PermissionStatus status = await Permission.photos.status;

    if (status.isGranted) {
      // Permiso ya concedido
      print("Permiso ya concedido para acceder a la galería");
      await pickImage();
    } else if (status.isDenied || status.isLimited) {
      // Si el permiso está denegado o limitado, solicita el permiso
      PermissionStatus newStatus = await Permission.photos.request();
      if (newStatus.isGranted) {
        print("Permiso concedido tras solicitarlo");
        await pickImage();
      } else {
        print("Permiso denegado tras solicitarlo");
      }
    } else if (status.isPermanentlyDenied) {
      // Si está denegado permanentemente, dirige al usuario a la configuración
      print(
          "Permiso permanentemente denegado, solicita al usuario ir a configuración");
      openAppSettings();
    }
  }

  // Seleccionar imagen de la galería
  Future<void> pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File image = File(pickedFile.path);
      setState(() {
        _imageFiles.add(pickedFile);
      });
      print("Imagen seleccionada: ${image.path}");
    } else {
      print("No se seleccionó ninguna imagen");
    }
  }
  */

  // Permiso para acceder a la galería y seleccionar fotos
  Future<void> requestPermissions() async {
    // Detectar versión de Android
    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      int sdkInt = androidInfo.version.sdkInt ?? 0;

      if (sdkInt < 33) {
        // Android <13 necesita permiso de almacenamiento
        PermissionStatus status = await Permission.storage.status;

        if (status.isDenied || status.isLimited) {
          PermissionStatus newStatus = await Permission.storage.request();
          if (!newStatus.isGranted) {
            if (newStatus.isPermanentlyDenied) {
              print(
                  "Permiso permanentemente denegado, solicita al usuario ir a configuración");
              openAppSettings();
            }
            return;
          }
        }
      }
      // Android 13+ no necesita permiso para Photo Picker
    }

    // Abrir galería y seleccionar imagen
    await pickImage();
  }

// Seleccionar imagen de la galería
  Future<void> pickImage() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);

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

  bool _isLoading = false;

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
                  onPressed: _isLoading
                      ? null // Deshabilitar el botón si está en estado de carga
                      : () async {
                          // Cambiar el estado a cargando
                          setState(() {
                            _isLoading = true;
                          });

                          // Mostrar el mensaje de "Cargando"
                          QuickAlert.show(
                            context: context,
                            type: QuickAlertType.loading,
                            title: 'Estamos cargando',
                            text: 'Por favor espere un momento',
                          );

                          // Validaciones de los campos
                          if (tituloController.text.isEmpty ||
                              descripcionController.text.isEmpty ||
                              notaCierreController.text.isEmpty) {
                            Navigator.of(context).pop(); // Cierra el QuickAlert
                            QuickAlert.show(
                              context: context,
                              type: QuickAlertType.error,
                              title: 'Error',
                              text: 'Por favor complete todos los campos',
                              confirmBtnText: 'OK',
                              onConfirmBtnTap: () {
                                Navigator.of(context)
                                    .pop(); // Cierra el QuickAlert
                              },
                            );
                            setState(() {
                              _isLoading =
                                  false; // Habilitar el botón nuevamente
                            });
                            return;
                          }

                          DateTime now = DateTime.now();
                          String formattedDate =
                              DateFormat('dd/MM/yyyy').format(now);

                          // Crear el objeto RequestHito
                          RequestHito hito = RequestHito(
                              titulo: tituloController.text,
                              descripcion: descripcionController.text,
                              ubicacion: _location,
                              notaCierre: notaCierreController.text,
                              latitud: position.latitude.toString(),
                              longitud: position.longitude.toString(),
                              hora: _formattedTime,
                              idTour: widget.login.tourSalesId,
                              fecha: formattedDate);

                          // Simular un retraso de 20 segundos
                          await Future.delayed(Duration(seconds: 5));

                          // Llamada al método para agregar el Hito
                          var consolidate = await usuarioProvider.addHito(hito);
                          if (consolidate != null) {
                            await usuarioProvider.addHitoFoto(
                                consolidate.binnacleDetailId,
                                widget.login.tourSalesId.toString(),
                                _imageFiles);
                            Navigator.of(context)
                                .pop(); // Cierra el QuickAlert de "Cargando"
                            QuickAlert.show(
                              context: context,
                              type: QuickAlertType.success,
                              title: 'Éxito',
                              text: 'Hito agregado con éxito',
                              confirmBtnText: 'Continuar',
                              onConfirmBtnTap: () {
                                Navigator.of(context)
                                    .pop(); // Cierra el QuickAlert
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TravelCoordinatorDashboard(
                                            login: widget.login),
                                  ),
                                );
                              },
                            );
                          } else {
                            Navigator.of(context)
                                .pop(); // Cierra el QuickAlert de "Cargando"
                            QuickAlert.show(
                              context: context,
                              type: QuickAlertType.error,
                              title: 'Error',
                              text:
                                  'No se pudo agregar el hito, intente nuevamente',
                              confirmBtnText: 'OK',
                              onConfirmBtnTap: () {
                                Navigator.of(context)
                                    .pop(); // Cierra el QuickAlert
                              },
                            );
                          }

                          // Habilitar el botón después de completar la operación
                          setState(() {
                            _isLoading = false;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3AC5C9),
                    padding: EdgeInsets.symmetric(horizontal: 60, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
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
        onTap: requestPermissions, // Al hacer clic, abre la galería
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
