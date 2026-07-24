import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/updateMedicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:quickalert/quickalert.dart';
import 'package:provider/provider.dart';

class MedicalRecordScreenEditCoordinator extends StatefulWidget {
  final TourSales login;
  final String idPassenger;
  final String idDocumento;
  final String nombrepassenger;
  final String passengerApellidos;

  const MedicalRecordScreenEditCoordinator(
      {Key? key, required this.login, required this.idPassenger, required this.idDocumento, required this.passengerApellidos, required this.nombrepassenger})
      : super(key: key);

  @override
  _MedicalRecordScreenEditState createState() => _MedicalRecordScreenEditState();
}

class _MedicalRecordScreenEditState extends State<MedicalRecordScreenEditCoordinator> {
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
  String? _grupoSanguineo;
  PassengersMedicalRecordDTO? _record;
  final TextEditingController _isapreController = TextEditingController();
  bool _requiereCuidadosEspeciales = false;
  final TextEditingController _cuidadosEspecialesController = TextEditingController();
  final TextEditingController _especificarEnfermedadesController = TextEditingController();
  final TextEditingController _medicamentosController = TextEditingController();
  final TextEditingController _medicamentosEvitarController = TextEditingController();
  TextEditingController _nombreEmergenciaController = TextEditingController();
  TextEditingController _relacionEmergenciaController = TextEditingController();
  TextEditingController _telefonoEmergenciaController = TextEditingController();
  TextEditingController _emailEmergenciaController = TextEditingController();
  TextEditingController _alergiasController = TextEditingController();
  TextEditingController _GrupoSanguineoController = TextEditingController();

  Future<void> _loadRecord() async {
    try {
      final record = await usuarioProvider.getMedicalRecord(widget.login.tourSalesId.toString(), widget.idPassenger);
      setState(() {
        _record = record;
        _nombreEmergenciaController.text = record.emergencyContactName!;
        _relacionEmergenciaController.text = record.emergencyContactRelation!;
        _telefonoEmergenciaController.text = record.emergencyContactPhone!;
        _emailEmergenciaController.text = record.emergencyContactEmail!;
        _GrupoSanguineoController.text = record.bloodType!;
        _especificarEnfermedadesController.text = record.diseases ?? '';
        _medicamentosController.text = record.medications ?? '';
        _medicamentosEvitarController.text = record.avoidMedications ?? '';
        enfermedades = record.diseases?.split('\n').where((e) => e.isNotEmpty).toList() ?? [];
        medicamentos = record.medications?.split('\n').where((e) => e.isNotEmpty).toList() ?? [];
        medicamentosEvitar = record.avoidMedications?.split('\n').where((e) => e.isNotEmpty).toList() ?? [];
      });
    } catch (e) {}
  }

  @override
  void initState() {
    super.initState();
    _loadRecord();
    _loadImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationService>().startTracking();
    });
  }

  @override
  void dispose() {
    _medicamentosEvitarController.dispose();
    _medicamentosController.dispose();
    _especificarEnfermedadesController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'El correo es obligatorio';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) return 'Ingresa un correo válido';
    return null;
  }

  Future<void> _loadImage() async {
    try {
      Responseimagepassenger imageUrl = await usuarioProvider.getPicturePassenger(widget.idDocumento.toString(), widget.login.tourSalesId.toString());
      if (imageUrl.image.isNotEmpty) {
        setState(() {
          _imageUrl = imageUrl.image;
        });
      } else {
        setState(() {
          _imageUrl = null;
        });
      }
    } catch (e) {
      setState(() {
        _imageUrl = null;
      });
    }
  }

  bool _isBase64(String data) {
    try {
      base64Decode(data.split(',').last);
      return true;
    } catch (e) {
      return false;
    }
  }

  String? _validateTelefono(String? value) {
    if (value == null || value.isEmpty) return 'El teléfono es obligatorio';
    final phoneRegex = RegExp(r'^[0-9]{9,12}$');
    if (!phoneRegex.hasMatch(value)) return 'Ingresa un teléfono válido';
    return null;
  }

  String? _formatRut(String? text) {
    if (text == null || text.isEmpty) return null;
    text = text.replaceAll(RegExp(r'[^0-9kK]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == text.length - 1) {
        buffer.write('-');
      } else if ((text.length - i - 1) % 3 == 0 && i != text.length - 2) {
        buffer.write('.');
      }
      buffer.write(text[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_record == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFF3AC5C9),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: _image != null
                          ? FileImage(File(_image!.path)) as ImageProvider<Object>
                          : (_imageUrl != null && _imageUrl!.isNotEmpty)
                              ? (_isBase64(_imageUrl!)
                                  ? MemoryImage(base64Decode(_imageUrl!.split(',').last)) as ImageProvider<Object>
                                  : NetworkImage(_imageUrl!) as ImageProvider<Object>)
                              : AssetImage('assets/profile.jpg') as ImageProvider<Object>,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${widget.nombrepassenger}\n${widget.passengerApellidos}', style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold)),
                      Text(widget.idDocumento, style: TextStyle(fontSize: 14, color: Colors.black)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/background.png'), fit: BoxFit.cover),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
              child: Row(
                children: [
                  Spacer(),
                  Image.asset('assets/logo-letras-papigiras.png', height: 50),
                  Spacer(),
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu, color: Colors.white, size: 30),
                      onPressed: () {
                        _scaffoldKey.currentState?.openEndDrawer();
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
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Text('Ficha Médica', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800]))],
                      ),
                      SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. DATOS DEL PASAJERO
                            _buildTextField('Grupo Sanguineo', _GrupoSanguineoController, null),
                            Divider(),
                            SizedBox(height: 10),
                            // 2. CONTACTOS DE EMERGENCIA
                            Text('Contactos de Emergencia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            _buildTextField('Nombre y Apellido', _nombreEmergenciaController, null),
                            _buildTextField('Relación con el Alumno(a)', _relacionEmergenciaController, null),
                            _buildTextFieldCelular('Teléfono Celular', _telefonoEmergenciaController, _validateTelefono),
                            _buildTextField('Correo Electrónico', _emailEmergenciaController, _validateEmail),
                            Divider(),
                            SizedBox(height: 10),
                            Text('Cobertura', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 10),
                            SwitchListTile(
                              title: Text('FONASA'),
                              value: _tieneFonasa,
                              onChanged: (value) {
                                setState(() {
                                  _tieneFonasa = value;
                                  if (value) _tieneIsapre = false;
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
                            if (_tieneIsapre) _buildTextField('Nombre de la Isapre', _isapreController, null),
                            Divider(),
                            SizedBox(height: 10),
                            // 4. ANTECEDENTES MÉDICOS
                            Text('Enfermedades', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            buildInfoSectionEnfermedades('', _record!.diseases ?? "No hay enfermedades registradas"),
                            Divider(),
                            SizedBox(height: 10),
                            // 5. MEDICAMENTOS
                            Text('Medicamentos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            buildInfoSectionMedicamentos('', _record!.medications ?? "No hay medicamentos registradas"),
                            Divider(),
                            SizedBox(height: 10),
                            // 5. MEDICAMENTOS
                            Text('Medicamentos a Evitar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            buildInfoSectionMedicamentosEvitar('', _record!.avoidMedications ?? "No hay medicamentos registradas"),
                            SizedBox(height: 10),
                            Text('Cuidados especiales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            buildInfoSectionCuidados('', _record!.specialCareDetails ?? "No hay cuidados especiales"),
                            Divider(),
                            SizedBox(height: 10),
                            Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  handleMedicamentos();
                                  handleEnfermedades();
                                  handleMedicamentosEvitar();
                                  RequestPassengerMedicalEdit medical = RequestPassengerMedicalEdit(
                                    grupoSanguineo: _GrupoSanguineoController.text,
                                    contactoEmergenciaNombre: _nombreEmergenciaController.text,
                                    contactoEmergenciaRelacion: _relacionEmergenciaController.text,
                                    contactoEmergenciaTelefono: _telefonoEmergenciaController.text,
                                    contactoEmergenciaEmail: _emailEmergenciaController.text,
                                    enfermedades: enfermedades,
                                    idPassenger: int.parse(widget.idPassenger),
                                    idTour: widget.login.tourSalesId,
                                    medicamentos: medicamentos,
                                    medicamentosEvitar: medicamentosEvitar,
                                    requiereCuidadosEspeciales: _requiereCuidadosEspeciales,
                                    cuidadosEspeciales: _requiereCuidadosEspeciales ? _cuidadosEspecialesController.text : null,
                                    tieneFonasa: _tieneFonasa,
                                    tieneIsapre: _tieneIsapre,
                                    nombreIsapre: _tieneIsapre ? _isapreController.text : null,
                                  );
                                  usuarioProvider.sendMedicalDataEdit(medical).then((response) {
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
                                            builder: (context) => MedicalCoordScreen(login: widget.login),
                                          ),
                                        ); // Cierra el QuickAlert
                                      },
                                    );
                                  }).catchError((error) {
                                    QuickAlert.show(context: context, type: QuickAlertType.error, title: 'Error', text: 'No se pudo Actualizar la ficha médica');
                                  });
                                  ;
                                },
                                child: Text('Guardar Ficha Médica'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                  textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: 5, blurRadius: 10, offset: Offset(0, -3))],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInfoSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        SizedBox(height: 5),
        Container(
          constraints: BoxConstraints(maxHeight: 80),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.all(10),
          child: TextField(
            controller: _alergiasController,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(border: InputBorder.none, hintText: 'Escribe aquí...', hintStyle: TextStyle(color: Colors.grey[600])),
            style: TextStyle(color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildInfoSectionEnfermedades(String title, String content) {
    String formattedContent = content.replaceAll('-', '\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        SizedBox(height: 5),
        Container(
          constraints: BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.all(10),
          child: TextField(
            controller: _especificarEnfermedadesController,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(border: InputBorder.none, hintText: 'Escribe aquí...', hintStyle: TextStyle(color: Colors.grey[600])),
            style: TextStyle(color: Colors.grey[800]),
            onChanged: (newValue) {
              setState(() {
                enfermedades = newValue.split('\n').where((element) => element.isNotEmpty).toList();
              });
            },
          ),
        ),
      ],
    );
  }

  void handleEnfermedades() {
    if (enfermedades.isEmpty) {
      enfermedades = _especificarEnfermedadesController.text.split('\n').where((element) => element.isNotEmpty).toList();
    } else {}
  }

  void handleMedicamentos() {
    if (medicamentos.isEmpty) {
      medicamentos = _medicamentosController.text.split('\n').where((element) => element.isNotEmpty).toList();
    } else {}
  }

  void handleMedicamentosEvitar() {
    if (medicamentosEvitar.isEmpty) {
      medicamentosEvitar = _medicamentosEvitarController.text.split('\n').where((element) => element.isNotEmpty).toList();
    } else {}
  }

  Widget buildInfoSectionCuidados(String title, String content) {
    String formattedContent = content.replaceAll('-', '\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        SizedBox(height: 5),
        Container(
          constraints: BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.all(10),
          child: TextField(
            controller: _cuidadosEspecialesController,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(border: InputBorder.none, hintText: 'Escribe aquí...', hintStyle: TextStyle(color: Colors.grey[600])),
            style: TextStyle(color: Colors.grey[800]),
            onChanged: (newValue) {
              setState(() {
                cuidados = newValue.split('\n').where((element) => element.isNotEmpty).toList();
              });
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget buildInfoSectionMedicamentos(String title, String content) {
    String formattedContent = content.replaceAll('-', '\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        SizedBox(height: 5),
        Container(
          constraints: BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.all(10),
          child: TextField(
            controller: _medicamentosController,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(border: InputBorder.none, hintText: 'Escribe aquí...', hintStyle: TextStyle(color: Colors.grey[600])),
            style: TextStyle(color: Colors.grey[800]),
            onChanged: (newValue) {
              setState(() {
                medicamentos = newValue.split('\n').where((element) => element.isNotEmpty).toList();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget buildInfoSectionMedicamentosEvitar(String title, String content) {
    String formattedContent = content.replaceAll('-', '\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        SizedBox(height: 5),
        Container(
          constraints: BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.all(10),
          child: TextField(
            controller: _medicamentosEvitarController,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(border: InputBorder.none, hintText: 'Escribe aquí...', hintStyle: TextStyle(color: Colors.grey[600])),
            style: TextStyle(color: Colors.grey[800]),
            onChanged: (newValue) {
              setState(() {
                medicamentosEvitar = newValue.split('\n').where((element) => element.isNotEmpty).toList();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldCelular(String label, TextEditingController controller, String? Function(String?)? validator, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          decoration: InputDecoration(border: OutlineInputBorder(), hintText: '923223212 ejemplo'),
        ),
        SizedBox(height: 15),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String? Function(String?)? validator, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          decoration: InputDecoration(border: OutlineInputBorder(), hintText: 'Escribe Aqui ....'),
        ),
        SizedBox(height: 15),
      ],
    );
  }
}
