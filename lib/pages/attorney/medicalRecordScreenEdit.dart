import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/dto/updateMedicalRecord.dart';
import 'package:papigiras_app/pages/attorney/viewmedicalRecord.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class MedicalRecordScreenEdit extends StatefulWidget {
  final ResponseAttorney login;
  final PassengersMedicalRecordDTO record;

  const MedicalRecordScreenEdit({
    Key? key,
    required this.login,
    required this.record,
  }) : super(key: key);

  @override
  _MedicalRecordScreenEditState createState() =>
      _MedicalRecordScreenEditState();
}

class _MedicalRecordScreenEditState extends State<MedicalRecordScreenEdit> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final usuarioProvider = new CoordinatorProviders();
  final _formKey = GlobalKey<FormState>();
  XFile? _image;
  String? _imageUrl;
  List<String> enfermedades = [];
  List<String> medicamentos = [];
  List<String> medicamentosEvitar = [];
  List<String> cuidados = [];
  bool _tieneFonasa = false;
  bool _tieneIsapre = false;
  final TextEditingController _isapreController = TextEditingController();
  bool _requiereCuidadosEspeciales = false;
  final TextEditingController _cuidadosEspecialesController =
      TextEditingController();
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
  @override
  void initState() {
    super.initState();
    _loadImage();
    _nombreEmergenciaController =
        TextEditingController(text: widget.record.emergencyContactName);
    _relacionEmergenciaController =
        TextEditingController(text: widget.record.emergencyContactRelation);
    _telefonoEmergenciaController =
        TextEditingController(text: widget.record.emergencyContactPhone);
    _emailEmergenciaController =
        TextEditingController(text: widget.record.emergencyContactEmail);
    _GrupoSanguineoController =
        TextEditingController(text: widget.record.bloodType);
    _tieneFonasa = widget.record?.hasFonasa ?? false;
    _tieneIsapre = widget.record?.hasIsapre ?? false;
    _isapreController.text = widget.record?.isapre ?? '';
    _requiereCuidadosEspeciales = widget.record?.requiresSpecialCare ?? false;
    _cuidadosEspecialesController.text =
        widget.record?.specialCareDetails ?? '';
    _especificarEnfermedadesController.text = widget.record.diseases ?? '';
    _medicamentosController.text = widget.record.medications ?? '';
    _medicamentosEvitarController.text = widget.record.avoidMedications ?? '';
  }

  @override
  void dispose() {
    _medicamentosEvitarController.dispose();
    _medicamentosController.dispose();
    _especificarEnfermedadesController.dispose();
    super.dispose();
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

  void logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borrar el estado de la sesión

    // Redirigir al login o realizar otra acción
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (context) => ViewMedicalRecordScreen(login: widget.login)),
      (route) =>
          false, // Esto elimina todas las rutas anteriores de la pila de navegación
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Color(0xFF3AC5C9),
        endDrawer: AppDrawerFather(
          login: widget.login,
          imageFile: _image, // remove if the screen has no image picker
          imageUrl: _imageUrl, // remove if the screen has no image URL
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
                              Text('Contactos de Emergencias',
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

                              Text('Cobertura',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 10),
                              SwitchListTile(
                                title: Text('FONASA'),
                                value: _tieneFonasa,
                                onChanged: (value) {
                                  setState(() {
                                    _tieneFonasa = value;
                                    if (value)
                                      _tieneIsapre = false; // no overlap
                                  });
                                },
                              ),
                              SwitchListTile(
                                title: Text('ISAPRE'),
                                value: _tieneIsapre,
                                onChanged: (value) {
                                  setState(() {
                                    _tieneIsapre = value;
                                    if (value) _tieneFonasa = false;
                                  });
                                },
                              ),
                              if (_tieneIsapre)
                                _buildTextField('Nombre de la Isapre',
                                    _isapreController, null),
                              Divider(),
                              SizedBox(height: 10),
                              // 4. ANTECEDENTES MÉDICOS
                              Text('Enfermedades',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              buildInfoSectionEnfermedades(
                                  '',
                                  widget.record?.diseases ??
                                      "No hay enfermedades registradas"),
                              Divider(),
                              SizedBox(height: 10),

                              // 5. MEDICAMENTOS
                              Text('Medicamentos',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              buildInfoSectionMedicamentos(
                                  '',
                                  widget.record?.medications ??
                                      "No hay medicamentos registradas"),
                              Divider(),
                              SizedBox(height: 10),

                              // 5. MEDICAMENTOS
                              Text('Medicamentos a Evitar',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              buildInfoSectionMedicamentosEvitar(
                                  '',
                                  widget.record?.avoidMedications ??
                                      "No hay medicamentos registradas"),
                              Divider(),
                              SizedBox(height: 10),

                              // 5. MEDICAMENTOS
                              Text('Cuidados especiales',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              buildInfoSectionCuidados(
                                  '',
                                  widget.record?.specialCareDetails ??
                                      "No hay cuidados especiales"),
                              Divider(),
                              SizedBox(height: 10),

                              // Botón Guardar
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
                                          _nombreEmergenciaController.text,
                                      contactoEmergenciaRelacion:
                                          _relacionEmergenciaController.text,
                                      contactoEmergenciaTelefono:
                                          _telefonoEmergenciaController.text,
                                      contactoEmergenciaEmail:
                                          _emailEmergenciaController.text,
                                      enfermedades: enfermedades,
                                      idPassenger: widget.login.passengerId!,
                                      idTour: widget.login.tourId!,
                                      medicamentos: medicamentos,
                                      medicamentosEvitar: medicamentosEvitar,
                                      requiereCuidadosEspeciales:
                                          _requiereCuidadosEspeciales,
                                      cuidadosEspeciales:
                                          _requiereCuidadosEspeciales
                                              ? _cuidadosEspecialesController
                                                  .text
                                              : null,
                                      tieneFonasa: _tieneFonasa,
                                      tieneIsapre: _tieneIsapre,
                                      nombreIsapre: _tieneIsapre
                                          ? _isapreController.text
                                          : null,
                                    );

                                    usuarioProvider
                                        .sendMedicalDataEdit(medical)
                                        .then((response) {
                                      print(response);
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
                                                  ViewMedicalRecordScreen(
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

  Widget buildInfoSectionCuidados(String title, String content) {
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
                _cuidadosEspecialesController, // Usamos el controlador persistente
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
                cuidados = newValue
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
