import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/requestMedicalRecord.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/attorney/fatherWelcome.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/attorney/loginFather.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicalRecordScreen extends StatefulWidget {
  final ResponseAttorney login;
  MedicalRecordScreen({required this.login});
  @override
  _MedicalRecordScreenState createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends State<MedicalRecordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final usuarioProvider = new CoordinatorProviders();

  final _formKey = GlobalKey<FormState>();
  XFile? _image;
  String? _imageUrl;

  // Controladores de texto
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _cursoController = TextEditingController();
  final TextEditingController _colegioController = TextEditingController();
  final TextEditingController _comunaController = TextEditingController();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _nombreEmergenciaController =
      TextEditingController();
  final TextEditingController _relacionEmergenciaController =
      TextEditingController();
  final TextEditingController _telefonoEmergenciaController =
      TextEditingController();
  final TextEditingController _emailEmergenciaController =
      TextEditingController();
  final TextEditingController _especificarEnfermedadesController =
      TextEditingController();
  final TextEditingController _isapreController = TextEditingController();
  final TextEditingController _medicamento1Controller = TextEditingController();
  final TextEditingController _dosis1Controller = TextEditingController();
  final TextEditingController _medicamento2Controller = TextEditingController();
  final TextEditingController _dosis2Controller = TextEditingController();
  final TextEditingController _medicamentosEvitarController =
      TextEditingController();
  final TextEditingController _cuidadosEspecialesController =
      TextEditingController();
  final TextEditingController _firmaController = TextEditingController();
  final TextEditingController _alergiasController = TextEditingController();
  final TextEditingController _enfermedadesController = TextEditingController();
  final TextEditingController _medicamentosController = TextEditingController();

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = image;
      });
      // Luego de seleccionar la imagen, se sube al servidor
      await usuarioProvider.addHitoFotoPassenger(
          widget.login.passengerId.toString(),
          widget.login.tourId.toString(),
          image); // 1 es un ejemplo de hitoId
      _loadImage(); // Recargamos la imagen después de la subida
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage(); // Cargar la imagen al inicio
  }

  // Variables para seleccionar opciones
  String? _grupoSanguineo;
  String? _sexo;
  bool _tieneFonasa = false;
  bool _tieneIsapre = false;
  String? _isapre;
  bool _tieneEnfermedades = false;
  bool _tomaMedicamentos = false;
  bool _evitarMedicamentos = false;
  bool _requiereCuidadosEspeciales = false;

  DateTime? _fechaNacimiento;
  DateTime? _fechaAutorizacion;

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
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
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
      print('No se puede abrir WhatsApp');
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borrar el estado de la sesión

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
                        radius: 35, // Tamaño de la imagen
                        backgroundImage: AssetImage('assets/profile.jpg'),
                      ),
                    ),
                    SizedBox(width: 16), // Espacio entre la imagen y el texto
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.login.passengerName!}\n${widget.login.passengerApellidos!}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.login.passengerIdentificacion!,
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
                      phone: "+56944087015", message: "Hola! Necesito ayuda");
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
                      phone: "+56944087015", message: "Hola! Necesito ayuda");
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
                      usuarioProvider.desactivateAccount(
                          widget.login.passengerIdentificacion.toString());

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
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(4), // Ancho del borde
                              decoration: BoxDecoration(
                                color: Colors.teal, // Color del borde
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 100,
                                backgroundImage: _image != null
                                    ? FileImage(
                                        File(
                                            _image!.path)) as ImageProvider<
                                        Object> // Imagen seleccionada desde el dispositivo
                                    : (_imageUrl != null &&
                                            _imageUrl!.isNotEmpty)
                                        ? (_isBase64(
                                                _imageUrl!) // Verifica si la URL es una imagen en Base64
                                            ? MemoryImage(base64Decode(
                                                _imageUrl!
                                                    .split(',')
                                                    .last)) as ImageProvider<
                                                Object> // Decodifica y muestra imagen Base64
                                            : NetworkImage(_imageUrl!)
                                                as ImageProvider<
                                                    Object>) // Carga imagen desde el servidor
                                        : AssetImage('assets/profile.jpg')
                                            as ImageProvider<
                                                Object>, // Imagen predeterminada
                              ),
                            ),
                            SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.login.passengerName!}\n${widget.login.passengerApellidos!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  widget.login.passengerIdentificacion!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Divider(),
                        SizedBox(height: 10),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. DATOS DEL PASAJERO
                              Text('1. Datos del Pasajero',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 10),
                              _buildTextField(
                                  'Nombres', _nombreController, null),
                              _buildTextField(
                                  'Apellidos', _apellidoController, null),
                              _buildTextField('Curso', _cursoController, null),
                              _buildTextField(
                                  'Colegio', _colegioController, null),
                              _buildTextField(
                                  'Comuna', _comunaController, null),
                              _buildTextFieldRut(
                                'RUT',
                                _rutController,
                                (value) {
                                  // Aquí puedes incluir validación adicional si es necesario
                                  if (value == null || value.isEmpty)
                                    return 'El RUT es obligatorio';
                                  return null;
                                },
                                keyboardType: TextInputType.text,
                                formatter: _formatRut,
                              ),
                              _buildDropdownField(
                                'Grupo Sanguíneo',
                                _grupoSanguineo,
                                [
                                  'A+',
                                  'A-',
                                  'B+',
                                  'B-',
                                  'AB+',
                                  'AB-',
                                  'O+',
                                  'O-'
                                ],
                                (value) =>
                                    setState(() => _grupoSanguineo = value),
                              ),
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
                              _buildTextField(
                                  'Teléfono Celular',
                                  _telefonoEmergenciaController,
                                  _validateTelefono),
                              _buildTextField('Correo Electrónico',
                                  _emailEmergenciaController, _validateEmail),
                              Divider(),
                              SizedBox(height: 10),

                              // 3. COBERTURA MÉDICA
                              Text('3. Cobertura Médica',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              _buildRadioGroup(
                                '¿Tiene FONASA?',
                                ['Sí', 'No'],
                                _tieneFonasa ? 'Sí' : 'No',
                                (value) => setState(
                                    () => _tieneFonasa = value == 'Sí'),
                              ),
                              _buildRadioGroup(
                                '¿Tiene ISAPRE?',
                                ['Sí', 'No'],
                                _tieneIsapre ? 'Sí' : 'No',
                                (value) => setState(() {
                                  _tieneIsapre = value == 'Sí';
                                  if (!_tieneIsapre) _isapre = null;
                                }),
                              ),
                              if (_tieneIsapre)
                                _buildTextField('Especifique ISAPRE',
                                    _isapreController, null),
                              Divider(),
                              SizedBox(height: 10),

                              // 4. ANTECEDENTES MÉDICOS
                              Text('4. Antecedentes Médicos',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              _buildRadioGroup(
                                '¿Tiene enfermedades crónicas o alergias?',
                                ['Sí', 'No'],
                                _tieneEnfermedades ? 'Sí' : 'No',
                                (value) => setState(
                                    () => _tieneEnfermedades = value == 'Sí'),
                              ),
                              if (_tieneEnfermedades)
                                _buildTextField('Especifique',
                                    _especificarEnfermedadesController, null),
                              Divider(),
                              SizedBox(height: 10),

                              // 5. MEDICAMENTOS
                              Text('5. Medicamentos',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              _buildRadioGroup(
                                '¿Toma medicamentos regularmente?',
                                ['Sí', 'No'],
                                _tomaMedicamentos ? 'Sí' : 'No',
                                (value) => setState(
                                    () => _tomaMedicamentos = value == 'Sí'),
                              ),
                              if (_tomaMedicamentos) ...[
                                _buildTextField('Medicamento 1 (Nombre)',
                                    _medicamento1Controller, null),
                                _buildTextField(
                                    'Dosis', _dosis1Controller, null),
                                _buildTextField('Medicamento 2 (Nombre)',
                                    _medicamento2Controller, null),
                                _buildTextField(
                                    'Dosis', _dosis2Controller, null),
                              ],
                              _buildRadioGroup(
                                '¿Debe evitar algún medicamento?',
                                ['Sí', 'No'],
                                _evitarMedicamentos ? 'Sí' : 'No',
                                (value) => setState(
                                    () => _evitarMedicamentos = value == 'Sí'),
                              ),
                              if (_evitarMedicamentos)
                                _buildTextField('Especifique',
                                    _medicamentosEvitarController, null),
                              Divider(),
                              SizedBox(height: 10),

                              // Botón Guardar
                              Center(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      // Construir el objeto para enviar
                                      RequestPassengerMedical medical =
                                          RequestPassengerMedical(
                                              nombres: _nombreController.text,
                                              apellidos:
                                                  _apellidoController.text,
                                              curso: _cursoController.text,
                                              colegio: _colegioController.text,
                                              comuna: _comunaController.text,
                                              rut: _rutController.text,
                                              grupoSanguineo:
                                                  _grupoSanguineo ?? '',
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
                                                  _emailEmergenciaController
                                                      .text,
                                              tieneFonasa: _tieneFonasa,
                                              tieneIsapre: _tieneIsapre,
                                              isapre: _isapreController.text,
                                              tieneEnfermedades:
                                                  _tieneEnfermedades,
                                              enfermedades: _tieneEnfermedades
                                                  ? _especificarEnfermedadesController
                                                      .text
                                                  : null,
                                              tomaMedicamentos:
                                                  _tomaMedicamentos,
                                              medicamentos: _tomaMedicamentos
                                                  ? [
                                                      {
                                                        'nombre':
                                                            _medicamento1Controller
                                                                .text,
                                                        'dosis':
                                                            _dosis1Controller
                                                                .text,
                                                      },
                                                      {
                                                        'nombre':
                                                            _medicamento2Controller
                                                                .text,
                                                        'dosis':
                                                            _dosis2Controller
                                                                .text,
                                                      }
                                                    ]
                                                  : [],
                                              evitarMedicamentos:
                                                  _evitarMedicamentos,
                                              medicamentosEvitar:
                                                  _evitarMedicamentos
                                                      ? _medicamentosEvitarController
                                                          .text
                                                      : null,
                                              requiereCuidadosEspeciales:
                                                  _requiereCuidadosEspeciales,
                                              cuidadosEspeciales:
                                                  _requiereCuidadosEspeciales
                                                      ? _cuidadosEspecialesController
                                                          .text
                                                      : null,
                                              fechaNacimiento:
                                                  _fechaNacimiento ??
                                                      DateTime.now(),
                                              fechaAutorizacion:
                                                  _fechaAutorizacion ??
                                                      DateTime.now(),
                                              idPassenger:
                                                  widget.login.passengerId!,
                                              idTour: widget.login.tourId!);

                                      showMedicalAuthorization(
                                          context, medical);
                                    }
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

  void showMedicalAuthorization(
      BuildContext context, RequestPassengerMedical medical) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'AUTORIZACIÓN MÉDICA',
      text:
          'Autorizo a los encargados del viaje y a los servicios médicos correspondientes a realizar procedimientos médicos de urgencia en caso de ser necesario.',
      confirmBtnText: 'Sí',
      cancelBtnText: 'No',
      confirmBtnColor: Colors.teal,
      onConfirmBtnTap: () {
        // Acción si el usuario selecciona "Sí"
        Navigator.of(context).pop(); // Cierra el QuickAlert

        usuarioProvider.createMedicalRecord(medical).then((response) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.success,
            title: 'Éxito',
            text: 'Ficha Médica Registrada',
            confirmBtnText: 'Continuar',
            onConfirmBtnTap: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TravelFatherDashboard(login: widget.login),
                ),
              ); // Cierra el QuickAlert
            },
          );
        }).catchError((error) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Error',
            text: 'No se pudo registrar la ficha médica',
          );
        });
      },
      onCancelBtnTap: () {
        // Acción si el usuario selecciona "No" (opcional)
        Navigator.of(context).pop(); // Cierra el QuickAlert
      },
    );
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

  Widget buildInfoSectionEnfermedades(String title) {
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
            controller: _enfermedadesController,
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

  Widget buildInfoSectionMedicamentos(String title) {
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
            controller: _medicamentosController,
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

  Widget buildBottomButton(IconData icon, String label, String? badge) {
    return GestureDetector(
      onTap: () {
        print('$label presionado');

        if (label == 'Bitácora del Viaje') {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => BitacoraFatherScreen(
                      login: widget.login,
                    )),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Icon(
                icon,
                size: 40,
                color: Colors.teal,
              ),
              if (badge != null)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.teal,
              fontSize: 14,
            ),
          ),
        ],
      ),
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
            hintText: 'Escribe aquí...',
          ),
        ),
        SizedBox(height: 15),
      ],
    );
  }

  Widget _buildTextFieldRut(
    String label,
    TextEditingController controller,
    String? Function(String?)? validator, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String)? formatter, // Función para formatear el texto
  }) {
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
            hintText: 'Escribe aquí...',
          ),
          onChanged: (value) {
            if (formatter != null) {
              final formattedValue = formatter(value);
              if (formattedValue != null && formattedValue != controller.text) {
                controller.value = TextEditingValue(
                  text: formattedValue,
                  selection:
                      TextSelection.collapsed(offset: formattedValue.length),
                );
              }
            }
          },
        ),
        SizedBox(height: 15),
      ],
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> options,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          items: options
              .map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 15),
      ],
    );
  }

  Widget _buildRadioGroup(String label, List<String> options,
      String? groupValue, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        ...options.map((option) {
          return RadioListTile<String>(
            value: option,
            groupValue: groupValue,
            title: Text(option),
            onChanged: onChanged,
          );
        }).toList(),
        SizedBox(height: 15),
      ],
    );
  }
}
