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
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickalert/quickalert.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';

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
  Position? _position;
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
    tituloController.dispose();
    descripcionController.dispose();
    ubicacionController.dispose();
    notaCierreController.dispose();
    latitudController.dispose();
    longitudController.dispose();
    horaController.dispose();
    usuarioProvider.dispose();
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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _position = position;

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (!mounted) return;
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final address = [place.street, place.locality, place.country]
              .where((part) => part != null && part.trim().isNotEmpty)
              .join(', ');
          setState(() {
            _location =
                address.isNotEmpty ? address : _coordinateFallback(position);
          });
        } else {
          setState(() {
            _location = _coordinateFallback(position);
          });
        }
      } catch (error) {
        debugPrint('No se pudo obtener la dirección: $error');
        if (!mounted) return;
        setState(() {
          _location = _coordinateFallback(position);
        });
      }
    } catch (e) {
      _position = null;
      if (!mounted) return;
      setState(() {
        _location = 'No se pudo obtener la ubicación del dispositivo.';
      });
    }
  }

  String _coordinateFallback(Position position) {
    return 'Ubicación aproximada '
        '(${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)})';
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      int sdkInt = androidInfo.version.sdkInt;
      if (sdkInt < 33) {
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
      backgroundColor: PapigirasColors.canvas,
      appBar: AppBar(
        title: const Text('Nuevo hito'),
        actions: [
          IconButton(
            tooltip: 'Actualizar ubicación',
            onPressed: _isLoading ? null : _checkLocationService,
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGroup(
                  children: [
                    _buildTextField('Título', 'Escribe un título',
                        controller: tituloController),
                    const SizedBox(height: 16),
                    _buildTextField('Descripción', 'Cuenta qué está pasando',
                        controller: descripcionController, maxLength: 140),
                  ],
                ),
                const SizedBox(height: 14),
                _buildGroup(
                  children: [
                    Text('Fotografías',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildCameraButton(),
                        _buildMultiSelectButton(),
                        ...List.generate(
                            _imageFiles.length + 1, _buildAddPhotoButton),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildGroup(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_outlined,
                            color: PapigirasColors.teal),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_location)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                        'Nota al cierre', 'Agrega una nota opcional',
                        controller: notaCierreController),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() {
                              _isLoading = true;
                            });
                            QuickAlert.show(
                                context: context,
                                type: QuickAlertType.loading,
                                title: 'Estamos cargando',
                                text: 'Por favor espere un momento');
                            if (tituloController.text.isEmpty ||
                                descripcionController.text.isEmpty) {
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
                            final currentPosition = _position;
                            if (currentPosition == null) {
                              Navigator.of(context).pop();
                              QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.error,
                                  title: 'Ubicación no disponible',
                                  text:
                                      'No se pudo obtener la ubicación. Activa el GPS e inténtalo nuevamente.',
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
                            String formattedDate =
                                DateFormat('dd/MM/yyyy').format(now);
                            RequestHito hito = RequestHito(
                                titulo: tituloController.text,
                                descripcion: descripcionController.text,
                                ubicacion: _location,
                                notaCierre: notaCierreController.text.isEmpty
                                    ? "."
                                    : notaCierreController.text,
                                latitud: currentPosition.latitude.toString(),
                                longitud: currentPosition.longitude.toString(),
                                hora: _formattedTime,
                                idTour: widget.login.tourSalesId,
                                fecha: formattedDate);
                            await Future.delayed(Duration(seconds: 5));
                            var consolidate =
                                await usuarioProvider.addHito(hito);
                            if (consolidate != null) {
                              await usuarioProvider.addHitoFoto(
                                  consolidate.binnacleDetailId,
                                  widget.login.tourSalesId.toString(),
                                  _imageFiles);
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
                                  text:
                                      'No se pudo agregar el hito, intente nuevamente',
                                  confirmBtnText: 'OK',
                                  onConfirmBtnTap: () {
                                    Navigator.of(context).pop();
                                  });
                            }
                            setState(() {
                              _isLoading = false;
                            });
                          },
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.publish_rounded),
                    label: _isLoading
                        ? const Text('Publicando…')
                        : const Text('Publicar hito'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroup({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField(String label, String hint,
      {TextEditingController? controller, int maxLength = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLength == 1 ? 1 : null,
          maxLength: maxLength > 1 ? maxLength : null,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!)),
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
          width: 72,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PapigirasColors.surface,
            border: Border.all(color: PapigirasColors.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: _imageFiles.isNotEmpty && index < _imageFiles.length
              ? Image.file(File(_imageFiles[index].path), fit: BoxFit.cover)
              : Icon(Icons.add, color: Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildMultiSelectButton() {
    return GestureDetector(
      onTap: pickMultipleImages,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: PapigirasColors.surface,
          border: Border.all(color: PapigirasColors.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child:
            const Icon(Icons.collections_outlined, color: PapigirasColors.teal),
      ),
    );
  }

  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: requestCameraPermission,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: PapigirasColors.mint,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.camera_alt_outlined,
            color: PapigirasColors.onMint),
      ),
    );
  }
}
