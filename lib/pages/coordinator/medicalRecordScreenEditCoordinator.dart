import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/requestMedicalRecord.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/dto/updateMedicalRecord.dart';
import 'package:papigiras_app/pages/attorney/viewmedicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

class MedicalRecordScreenEditCoordinator extends StatefulWidget {
  final TourSales login;
  final String idPassenger;
  final String idDocumento;
  final String nombrepassenger;
  final String passengerApellidos;

  const MedicalRecordScreenEditCoordinator(
      {Key? key,
      required this.login,
      required this.idPassenger,
      required this.idDocumento,
      required this.passengerApellidos,
      required this.nombrepassenger})
      : super(key: key);

  @override
  _MedicalRecordScreenEditState createState() =>
      _MedicalRecordScreenEditState();
}

class _MedicalRecordScreenEditState
    extends State<MedicalRecordScreenEditCoordinator> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final usuarioProvider = new CoordinatorProviders();

  final _formKey = GlobalKey<FormState>();
  XFile? _image;
  String? _imageUrl;

  List<String> enfermedades = [];
  List<String> medicamentos = [];
  List<String> medicamentosEvitar = [];
  PassengersMedicalRecordDTO? _record;

  // Controladores de texto
  final TextEditingController _especificarEnfermedadesController =
      TextEditingController();
  final TextEditingController _medicamentosController = TextEditingController();
  final TextEditingController _medicamentosEvitarController =
      TextEditingController();
  TextEditingController _nombreEmergenciaController = TextEditingController();
  TextEditingController _relacionEmergenciaController = TextEditingController();
  TextEditingController _telefonoEmergenciaController = TextEditingController();
  TextEditingController _emailEmergenciaController = TextEditingController();
  TextEditingController _alergiasController = TextEditingController();
  TextEditingController _GrupoSanguineoController = TextEditingController();

  Future<void> _loadRecord() async {
    try {
      final record = await usuarioProvider.getMedicalRecord(
        widget.login.tourSalesId.toString(),
        widget.idPassenger,
      );
      setState(() {
        _record = record;

        // Inicializamos controladores con los datos recibidos
        _nombreEmergenciaController.text = record.emergencyContactName!;
        _relacionEmergenciaController.text = record.emergencyContactRelation!;
        _telefonoEmergenciaController.text = record.emergencyContactPhone!;
        _emailEmergenciaController.text = record.emergencyContactEmail!;
        _GrupoSanguineoController.text = record.bloodType!;
        _especificarEnfermedadesController.text = record.diseases ?? '';
        _medicamentosController.text = record.medications ?? '';
        _medicamentosEvitarController.text = record.avoidMedications ?? '';

        // También llenamos las listas para tu lógica de envío
        enfermedades =
            record.diseases?.split('\n').where((e) => e.isNotEmpty).toList() ??
                [];
        medicamentos = record.medications
                ?.split('\n')
                .where((e) => e.isNotEmpty)
                .toList() ??
            [];
        medicamentosEvitar = record.avoidMedications
                ?.split('\n')
                .where((e) => e.isNotEmpty)
                .toList() ??
            [];
      });
    } catch (e) {
      // Aquí podrías mostrar un SnackBar o QuickAlert de error
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRecord(); // <-- traemos datos
    _loadImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationService>().startTracking();
    }); // <-- mantenemos tu carga de imagen
  }

  @override
  void dispose() {
    _medicamentosEvitarController.dispose();
    _medicamentosController.dispose();
    _especificarEnfermedadesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = image;
      });
      // Luego de seleccionar la imagen, se sube al servidor
      await usuarioProvider.addHitoFotoPassenger(
          widget.idPassenger.toString(),
          widget.login.tourSalesId.toString(),
          image); // 1 es un ejemplo de hitoId
      _loadImage(); // Recargamos la imagen después de la subida
    }
  }

  // Variables para seleccionar opciones
  String? _grupoSanguineo;

  // Métodos de validación
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'El correo es obligatorio';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) return 'Ingresa un correo válido';
    return null;
  }

  Future<void> _loadImage() async {
    try {
      Responseimagepassenger imageUrl =
          await usuarioProvider.getPicturePassenger(
        widget.idDocumento.toString(),
        widget.login.tourSalesId.toString(),
      );

      if (imageUrl.image.isNotEmpty) {
        setState(() {
          _imageUrl = imageUrl.image; // Si la imagen existe, la cargamos
        });
      } else {
        setState(() {
          _imageUrl = null; // Si no hay imagen, usar la predeterminada
        });
      }
    } catch (e) {
      setState(() {
        _imageUrl = null; // Si ocurre un error, usar la predeterminada
      });
    }
  }

  bool _isBase64(String data) {
    try {
      base64Decode(data
          .split(',')
          .last); // Intenta decodificar eliminando un posible prefijo
      return true;
    } catch (e) {
      return false; // Si falla, no es Base64
    }
  }

  String? _validateTelefono(String? value) {
    if (value == null || value.isEmpty) return 'El teléfono es obligatorio';
    final phoneRegex = RegExp(r'^[0-9]{9,12}$');
    if (!phoneRegex.hasMatch(value)) return 'Ingresa un teléfono válido';
    return null;
  }

  void sendMessage({required String phone, required String message}) async {
    final whatsappUrl =
        Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      // Intenta con el esquema directo
      final whatsappDirect = Uri.parse(
          "whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(whatsappDirect)) {
        await launchUrl(
          whatsappDirect,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'WhatsApp no está instalado o no puede manejar la URL';
      }
    }
  }

  String? _formatRut(String? text) {
    if (text == null || text.isEmpty)
      return null; // Manejo de entrada nula o vacía

    // Eliminar cualquier carácter que no sea un número o 'k'/'K'
    text = text.replaceAll(RegExp(r'[^0-9kK]'), '');

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == text.length - 1) {
        // Añade el guion antes del dígito verificador
        buffer.write('-');
      } else if ((text.length - i - 1) % 3 == 0 && i != text.length - 2) {
        // Añade un punto cada tres dígitos antes del guion
        buffer.write('.');
      }
      buffer.write(text[i]);
    }

    return buffer.toString();
  }

  void logoutUser(BuildContext context) async {
    // Borrar el estado de la sesión

    final locationService =
        Provider.of<LocationService>(context, listen: false);
    locationService.stopTracking();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Redirigir al login o realizar otra acción
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => WelcomeScreen()),
      (route) =>
          false, // Esto elimina todas las rutas anteriores de la pila de navegación
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_record == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Color(0xFF3AC5C9),
        endDrawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              // Encabezado personalizado
              Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(4), // Ancho del borde
                      decoration: BoxDecoration(
                        color: Colors.teal, // Color del borde
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundImage: _image != null
                            ? FileImage(File(_image!.path)) as ImageProvider<
                                Object> // Imagen seleccionada desde el dispositivo
                            : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                ? (_isBase64(
                                        _imageUrl!) // Verifica si la URL es una imagen en Base64
                                    ? MemoryImage(base64Decode(
                                        _imageUrl!
                                            .split(',')
                                            .last)) as ImageProvider<
                                        Object> // Decodifica y muestra imagen Base64
                                    : NetworkImage(_imageUrl!) as ImageProvider<
                                        Object>) // Carga imagen desde el servidor
                                : AssetImage('assets/profile.jpg')
                                    as ImageProvider<
                                        Object>, // Imagen predeterminada
                      ),
                    ),
                    SizedBox(width: 16), // Espacio entre la imagen y el texto
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.nombrepassenger}\n${widget.passengerApellidos}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.idDocumento,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.phone, color: Colors.teal),
                title: Text(
                  'Contactar Agencia',
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () {
                  sendMessage(
                      phone: "+56932157564", message: "Hola! Necesito ayuda");
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, color: Colors.teal),
                    SizedBox(width: 10),
                    Icon(FontAwesomeIcons.whatsapp, color: Colors.teal),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.report_problem, color: Colors.teal),
                title: Text(
                  'Reportar un Problema',
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () {
                  sendMessage(
                      phone: "+56932157564", message: "Hola! Necesito ayuda");
                },
              ),
              ListTile(
                leading: Icon(Icons.desktop_access_disabled_outlined,
                    color: Colors.teal),
                title: Text(
                  'Desactivar Cuenta',
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () {
                  QuickAlert.show(
                    context: context,
                    type: QuickAlertType
                        .error, // Cambiar a 'error' para la cruz roja
                    title: 'Eliminar Cuenta',
                    text: 'Desactivar tu cuenta no te permitirá ingresar más',
                    confirmBtnText: 'Continuar',
                    onConfirmBtnTap: () {
                      usuarioProvider
                          .desactivateAccount(widget.idDocumento.toString());

                      logoutUser(context); // Cierra el QuickAlert
                    },
                  );
                  // Acción para cerrar sesión
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.teal),
                title: Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () {
                  logoutUser(context);
                },
              ),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 30.0, horizontal: 16.0),
                child: Row(
                  children: [
                    Spacer(),
                    Image.asset(
                      'assets/logo-letras-papigiras.png', // Logo de la app
                      height: 50,
                    ),
                    Spacer(),
                    Builder(
                      builder: (context) => IconButton(
                        icon: Icon(Icons.menu, color: Colors.white, size: 30),
                        onPressed: () {
                          _scaffoldKey.currentState
                              ?.openEndDrawer(); // Abre el Drawer desde la derecha
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Ficha Médica',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. DATOS DEL PASAJERO
                              _buildTextField('Grupo Sanguineo',
                                  _GrupoSanguineoController, null),
                              Divider(),
                              SizedBox(height: 10),

                              // 2. CONTACTOS DE EMERGENCIA
                              Text('2. Contactos de Emergencia',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              _buildTextField('Nombre y Apellido',
                                  _nombreEmergenciaController, null),
                              _buildTextField('Relación con el Alumno(a)',
                                  _relacionEmergenciaController, null),
                              _buildTextFieldCelular(
                                  'Teléfono Celular',
                                  _telefonoEmergenciaController,
                                  _validateTelefono),
                              _buildTextField('Correo Electrónico',
                                  _emailEmergenciaController, _validateEmail),
                              Divider(),
                              SizedBox(height: 10),
                              SizedBox(height: 10),
                              // 4. ANTECEDENTES MÉDICOS
                              Text('4. Antecedentes Médicos',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              buildInfoSectionEnfermedades(
                                  '',
                                  _record!.diseases ??
                                      "No hay enfermedades registradas"),
                              Divider(),
                              SizedBox(height: 10),

                              // 5. MEDICAMENTOS
                              Text('5. Medicamentos',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              buildInfoSectionMedicamentos(
                                  '',
                                  _record!.medications ??
                                      "No hay medicamentos registradas"),
                              Divider(),
                              SizedBox(height: 10),

                              // 5. MEDICAMENTOS
                              Text('5. Medicamentos a Evitar',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              buildInfoSectionMedicamentosEvitar(
                                  '',
                                  _record!.avoidMedications ??
                                      "No hay medicamentos registradas"),

                              SizedBox(height: 10),
                              Center(
                                child: ElevatedButton(
                                  onPressed: () {
                                    handleMedicamentos();
                                    handleEnfermedades();
                                    handleMedicamentosEvitar();
                                    RequestPassengerMedicalEdit medical =
                                        RequestPassengerMedicalEdit(
                                            grupoSanguineo:
                                                _GrupoSanguineoController.text,
                                            contactoEmergenciaNombre:
                                                _nombreEmergenciaController
                                                    .text,
                                            contactoEmergenciaRelacion:
                                                _relacionEmergenciaController
                                                    .text,
                                            contactoEmergenciaTelefono:
                                                _telefonoEmergenciaController
                                                    .text,
                                            contactoEmergenciaEmail:
                                                _emailEmergenciaController.text,
                                            enfermedades: enfermedades,
                                            idPassenger:
                                                int.parse(widget.idPassenger),
                                            idTour: widget.login.tourSalesId,
                                            medicamentos: medicamentos,
                                            medicamentosEvitar:
                                                medicamentosEvitar);

                                    usuarioProvider
                                        .sendMedicalDataEdit(medical)
                                        .then((response) {
                                      QuickAlert.show(
                                        context: context,
                                        type: QuickAlertType.success,
                                        title: 'Éxito',
                                        text: 'Ficha Médica Actualizada',
                                        confirmBtnText: 'Continuar',
                                        onConfirmBtnTap: () {
                                          Navigator.of(context).pop();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  MedicalCoordScreen(
                                                      login: widget.login),
                                            ),
                                          ); // Cierra el QuickAlert
                                        },
                                      );
                                    }).catchError((error) {
                                      QuickAlert.show(
                                        context: context,
                                        type: QuickAlertType.error,
                                        title: 'Error',
                                        text:
                                            'No se pudo Actualizar la ficha médica',
                                      );
                                    });
                                    ;
                                  },
                                  child: Text('Guardar Ficha Médica'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 15,
                                    ),
                                    textStyle: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Barra de navegación inferior con sombreado
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 10,
                      offset: Offset(0, -3), // Sombra hacia arriba
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  Widget buildInfoSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 5),
        Container(
          constraints: BoxConstraints(
            maxHeight: 80,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.all(10),
          child: TextField(
            controller: _alergiasController,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Escribe aquí...',
              hintStyle: TextStyle(color: Colors.grey[600]),
            ),
            style: TextStyle(color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildInfoSectionEnfermedades(String title, String content) {
    // Reemplazar los guiones con saltos de línea para mostrar correctamente
    String formattedContent = content.replaceAll('-', '\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 5),
        Container(
          constraints: BoxConstraints(
            maxHeight: 150, // Ajusta la altura máxima según el contenido
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.all(10),
          child: TextField(
            controller:
                _especificarEnfermedadesController, // Usamos el controlador persistente
            maxLines: null, // Permite múltiples líneas
            expands:
                true, // Expande el campo para ocupar todo el espacio disponible
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Escribe aquí...', // Texto de ejemplo
              hintStyle: TextStyle(color: Colors.grey[600]),
            ),
            style: TextStyle(color: Colors.grey[800]),
            onChanged: (newValue) {
              setState(() {
                // Dividimos el contenido editado en un arreglo basado en los saltos de línea
                enfermedades = newValue
                    .split('\n')
                    .where((element) => element.isNotEmpty)
                    .toList();
              });
            },
          ),
        ),
      ],
    );
  }

  void handleEnfermedades() {
    if (enfermedades.isEmpty) {
      enfermedades = _especificarEnfermedadesController.text
          .split('\n')
          .where((element) => element.isNotEmpty)
          .toList();
    } else {}
  }

  void handleMedicamentos() {
    if (medicamentos.isEmpty) {
      medicamentos = _medicamentosController.text
          .split('\n')
          .where((element) => element.isNotEmpty)
          .toList();
    } else {}
  }

  void handleMedicamentosEvitar() {
    if (medicamentosEvitar.isEmpty) {
      medicamentosEvitar = _medicamentosEvitarController.text
          .split('\n')
          .where((element) => element.isNotEmpty)
          .toList();
    } else {}
  }

  @override
  Widget buildInfoSectionMedicamentos(String title, String content) {
    // Reemplazar los guiones con saltos de línea para mostrar correctamente
    String formattedContent = content.replaceAll('-', '\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 5),
        Container(
          constraints: BoxConstraints(
            maxHeight: 150, // Ajusta la altura máxima según el contenido
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.all(10),
          child: TextField(
            controller:
                _medicamentosController, // Usamos el controlador persistente
            maxLines: null, // Permite múltiples líneas
            expands:
                true, // Expande el campo para ocupar todo el espacio disponible
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Escribe aquí...', // Texto de ejemplo
              hintStyle: TextStyle(color: Colors.grey[600]),
            ),
            style: TextStyle(color: Colors.grey[800]),
            onChanged: (newValue) {
              setState(() {
                // Dividimos el contenido editado en un arreglo basado en los saltos de línea
                medicamentos = newValue
                    .split('\n')
                    .where((element) => element.isNotEmpty)
                    .toList();
                // Aquí puedes usar el arreglo `medicamentos` como desees
                // Imprime el arreglo para ver cómo se ve
              });
            },
          ),
        ),
      ],
    );
  }

  Widget buildInfoSectionMedicamentosEvitar(String title, String content) {
    // Reemplazar los guiones con saltos de línea para mostrar correctamente
    String formattedContent = content.replaceAll('-', '\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 5),
        Container(
          constraints: BoxConstraints(
            maxHeight: 150, // Ajusta la altura máxima según el contenido
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.all(10),
          child: TextField(
            controller:
                _medicamentosEvitarController, // Usamos el controlador persistente
            maxLines: null, // Permite múltiples líneas
            expands:
                true, // Expande el campo para ocupar todo el espacio disponible
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Escribe aquí...', // Texto de ejemplo
              hintStyle: TextStyle(color: Colors.grey[600]),
            ),
            style: TextStyle(color: Colors.grey[800]),
            onChanged: (newValue) {
              setState(() {
                // Dividimos el contenido editado en un arreglo basado en los saltos de línea
                medicamentosEvitar = newValue
                    .split('\n')
                    .where((element) => element.isNotEmpty)
                    .toList();
                // Imprimir la lista de medicamentos evitados
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldCelular(String label, TextEditingController controller,
      String? Function(String?)? validator,
      {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: '923223212 ejemplo',
          ),
        ),
        SizedBox(height: 15),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      String? Function(String?)? validator,
      {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Escribe Aqui ....',
          ),
        ),
        SizedBox(height: 15),
      ],
    );
  }
}
