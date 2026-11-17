import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/updateMedicalRecord.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:quickalert/quickalert.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';

class MedicalRecordScreenEditCoordinator extends StatefulWidget {
  final TourSales login;
  final String idPassenger;
  final String idDocumento;
  final String nombrepassenger;
  final String passengerApellidos;

  const MedicalRecordScreenEditCoordinator(
      {super.key,
      required this.login,
      required this.idPassenger,
      required this.idDocumento,
      required this.nombrepassenger,
      required this.passengerApellidos});

  @override
  State<MedicalRecordScreenEditCoordinator> createState() =>
      _MedicalRecordScreenEditState();
}

class _MedicalRecordScreenEditState
    extends State<MedicalRecordScreenEditCoordinator> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final CoordinatorProviders _coordinatorProvider = CoordinatorProviders();
  final TextEditingController _grupoSanguineoController =
      TextEditingController();
  final TextEditingController _nombreEmergenciaController =
      TextEditingController();
  final TextEditingController _relacionEmergenciaController =
      TextEditingController();
  final TextEditingController _telefonoEmergenciaController =
      TextEditingController();
  final TextEditingController _emailEmergenciaController =
      TextEditingController();
  final TextEditingController _isapreController = TextEditingController();
  final TextEditingController _enfermedadesController = TextEditingController();
  final TextEditingController _medicamentosController = TextEditingController();
  final TextEditingController _medicamentosEvitarController =
      TextEditingController();
  final TextEditingController _cuidadosEspecialesController =
      TextEditingController();
  PassengersMedicalRecordDTO? _record;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _tieneFonasa = false;
  bool _tieneIsapre = false;
  bool _requiereCuidadosEspeciales = false;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  @override
  void dispose() {
    _coordinatorProvider.dispose();
    _grupoSanguineoController.dispose();
    _nombreEmergenciaController.dispose();
    _relacionEmergenciaController.dispose();
    _telefonoEmergenciaController.dispose();
    _emailEmergenciaController.dispose();
    _isapreController.dispose();
    _enfermedadesController.dispose();
    _medicamentosController.dispose();
    _medicamentosEvitarController.dispose();
    _cuidadosEspecialesController.dispose();
    super.dispose();
  }

  Future<void> _loadRecord() async {
    try {
      final record = await _coordinatorProvider.getMedicalRecord(
          widget.login.tourSalesId.toString(), widget.idPassenger);
      if (!mounted) return;
      _record = record;
      _grupoSanguineoController.text = record.bloodType ?? '';
      _nombreEmergenciaController.text = record.emergencyContactName ?? '';
      _relacionEmergenciaController.text =
          record.emergencyContactRelation ?? '';
      _telefonoEmergenciaController.text = record.emergencyContactPhone ?? '';
      _emailEmergenciaController.text = record.emergencyContactEmail ?? '';
      _tieneFonasa = record.hasFonasa;
      _tieneIsapre = record.hasIsapre;
      _isapreController.text = record.isapre ?? '';
      _enfermedadesController.text = _formatMultilineValue(record.diseases);
      _medicamentosController.text = _formatMultilineValue(record.medications);
      _medicamentosEvitarController.text =
          _formatMultilineValue(record.avoidMedications);
      _cuidadosEspecialesController.text =
          _formatMultilineValue(record.specialCareDetails);
      _requiereCuidadosEspeciales = record.requiresSpecialCare ||
          _cuidadosEspecialesController.text.trim().isNotEmpty;
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Error',
          text: 'No se pudo cargar la ficha médica.',
          confirmBtnText: 'Aceptar');
    }
  }

  String _formatMultilineValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }
    return value.replaceAll(' - ', '\n').replaceAll('-', '\n').trim();
  }

  List<String> _controllerToList(TextEditingController controller) {
    return controller.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: PapigirasColors.canvas,
        endDrawer: CoordinatorEndDrawer(login: widget.login),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Volver',
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Ficha médica',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Abrir menú',
                      onPressed: _isSaving
                          ? null
                          : () => _scaffoldKey.currentState?.openEndDrawer(),
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_record == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se encontró la ficha médica.'),
            TextButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadRecord();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return _buildContent();
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(),
            const SizedBox(height: 24),
            _buildPassengerInformationSection(),
            _buildSectionDivider(),
            _buildEmergencyContactSection(),
            _buildSectionDivider(),
            _buildCoverageSection(),
            _buildSectionDivider(),
            _buildMedicalBackgroundSection(),
            _buildSectionDivider(),
            _buildSpecialCareSection(),
            const SizedBox(height: 30),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: PapigirasColors.mint,
            foregroundColor: PapigirasColors.onMint,
            child: Icon(Icons.medical_services_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.nombrepassenger} ${widget.passengerApellidos}'
                      .trim(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(widget.idDocumento,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerInformationSection() {
    return _buildFormSection(
      title: 'Datos del pasajero',
      icon: Icons.person,
      children: [
        _buildTextFormField(
            label: 'Grupo sanguíneo',
            controller: _grupoSanguineoController,
            hintText: 'Ejemplo: O+',
            validator: _validateRequiredField)
      ],
    );
  }

  Widget _buildEmergencyContactSection() {
    return _buildFormSection(
      title: 'Contacto de emergencia',
      icon: Icons.emergency,
      children: [
        _buildTextFormField(
            label: 'Nombre y apellido',
            controller: _nombreEmergenciaController,
            hintText: 'Nombre del contacto',
            validator: _validateRequiredField),
        _buildTextFormField(
            label: 'Relación con el alumno(a)',
            controller: _relacionEmergenciaController,
            hintText: 'Ejemplo: Madre, padre o tutor',
            validator: _validateRequiredField),
        _buildTextFormField(
            label: 'Teléfono celular',
            controller: _telefonoEmergenciaController,
            hintText: 'Ejemplo: 923223212',
            keyboardType: TextInputType.phone,
            validator: _validatePhone),
        _buildTextFormField(
            label: 'Correo electrónico',
            controller: _emailEmergenciaController,
            hintText: 'correo@ejemplo.com',
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail),
      ],
    );
  }

  Widget _buildCoverageSection() {
    return _buildFormSection(
      title: 'Cobertura de salud',
      icon: Icons.health_and_safety,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('FONASA'),
          subtitle: const Text('El pasajero tiene cobertura FONASA'),
          value: _tieneFonasa,
          activeTrackColor: PapigirasColors.mint,
          onChanged: _isSaving
              ? null
              : (value) {
                  setState(() {
                    _tieneFonasa = value;
                    if (value) {
                      _tieneIsapre = false;
                      _isapreController.clear();
                    }
                  });
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ISAPRE'),
          subtitle: const Text('El pasajero tiene cobertura ISAPRE'),
          value: _tieneIsapre,
          activeTrackColor: PapigirasColors.mint,
          onChanged: _isSaving
              ? null
              : (value) {
                  setState(() {
                    _tieneIsapre = value;
                    if (value) {
                      _tieneFonasa = false;
                    } else {
                      _isapreController.clear();
                    }
                  });
                },
        ),
        if (_tieneIsapre)
          _buildTextFormField(
            label: 'Nombre de la ISAPRE',
            controller: _isapreController,
            hintText: 'Escriba el nombre de la ISAPRE',
            validator: (value) {
              if (!_tieneIsapre) return null;
              return _validateRequiredField(value);
            },
          ),
      ],
    );
  }

  Widget _buildMedicalBackgroundSection() {
    return _buildFormSection(
      title: 'Antecedentes médicos',
      icon: Icons.medical_services,
      children: [
        _buildMultilineField(
            label: 'Enfermedades',
            controller: _enfermedadesController,
            hintText: 'Escriba una enfermedad por línea'),
        _buildMultilineField(
            label: 'Medicamentos',
            controller: _medicamentosController,
            hintText: 'Escriba un medicamento por línea'),
        _buildMultilineField(
            label: 'Medicamentos a evitar',
            controller: _medicamentosEvitarController,
            hintText: 'Escriba un medicamento por línea'),
      ],
    );
  }

  Widget _buildSpecialCareSection() {
    return _buildFormSection(
      title: 'Cuidados especiales',
      icon: Icons.volunteer_activism,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Requiere cuidados especiales'),
          subtitle: const Text(
              'Active esta opción si debe registrar indicaciones adicionales'),
          value: _requiereCuidadosEspeciales,
          activeTrackColor: PapigirasColors.mint,
          onChanged: _isSaving
              ? null
              : (value) {
                  setState(() {
                    _requiereCuidadosEspeciales = value;
                    if (!value) {
                      _cuidadosEspecialesController.clear();
                    }
                  });
                },
        ),
        if (_requiereCuidadosEspeciales)
          _buildMultilineField(
            label: 'Detalle de los cuidados',
            controller: _cuidadosEspecialesController,
            hintText: 'Describa los cuidados especiales requeridos',
            validator: (value) {
              if (!_requiereCuidadosEspeciales) return null;
              if (value == null || value.trim().isEmpty) {
                return 'Debe describir los cuidados especiales';
              }
              return null;
            },
          ),
      ],
    );
  }

  Widget _buildFormSection(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: PapigirasColors.teal, size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: PapigirasColors.ink))),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextFormField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          enabled: !_isSaving,
          decoration: _buildInputDecoration(label: label, hintText: hintText)),
    );
  }

  Widget _buildMultilineField(
      {required String label,
      required TextEditingController controller,
      required String hintText,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        validator: validator,
        enabled: !_isSaving,
        minLines: 4,
        maxLines: 7,
        textCapitalization: TextCapitalization.sentences,
        decoration: _buildInputDecoration(
            label: label, hintText: hintText, alignLabelWithHint: true),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
      {required String label,
      String? hintText,
      bool alignLabelWithHint = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: PapigirasColors.soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: PapigirasColors.teal, width: 2)),
    );
  }

  Widget _buildSectionDivider() {
    return const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 16), child: Divider());
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveMedicalRecord,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.check_rounded),
        label: Text(
          _isSaving ? 'Guardando…' : 'Guardar ficha médica',
        ),
      ),
    );
  }

  Future<void> _saveMedicalRecord() async {
    FocusScope.of(context).unfocus();
    final formIsValid = _formKey.currentState?.validate() ?? false;
    if (!formIsValid) {
      return;
    }
    final passengerId = int.tryParse(widget.idPassenger);
    if (passengerId == null) {
      await QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Error',
          text: 'El identificador del pasajero no es válido.',
          confirmBtnText: 'Aceptar');
      return;
    }
    setState(() {
      _isSaving = true;
    });

    final request = RequestPassengerMedicalEdit(
      grupoSanguineo: _grupoSanguineoController.text.trim(),
      contactoEmergenciaNombre: _nombreEmergenciaController.text.trim(),
      contactoEmergenciaRelacion: _relacionEmergenciaController.text.trim(),
      contactoEmergenciaTelefono: _telefonoEmergenciaController.text.trim(),
      contactoEmergenciaEmail: _emailEmergenciaController.text.trim(),
      enfermedades: _controllerToList(_enfermedadesController),
      medicamentos: _controllerToList(_medicamentosController),
      medicamentosEvitar: _controllerToList(_medicamentosEvitarController),
      idPassenger: passengerId,
      idTour: widget.login.tourSalesId,
      requiereCuidadosEspeciales: _requiereCuidadosEspeciales,
      cuidadosEspeciales: _requiereCuidadosEspeciales
          ? _cuidadosEspecialesController.text.trim()
          : null,
      tieneFonasa: _tieneFonasa,
      tieneIsapre: _tieneIsapre,
      nombreIsapre: _tieneIsapre ? _isapreController.text.trim() : null,
    );
    try {
      await _coordinatorProvider.sendMedicalDataEdit(request);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'Éxito',
        text: 'Ficha médica actualizada.',
        confirmBtnText: 'Continuar',
        onConfirmBtnTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop(true);
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      await QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Error',
          text: 'No se pudo actualizar la ficha médica.',
          confirmBtnText: 'Aceptar');
    }
  }

  String? _validateRequiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es obligatorio';
    }
    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Ingrese un correo válido';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El teléfono es obligatorio';
    }
    final normalizedPhone = value.replaceAll(RegExp(r'[\s()+-]'), '');
    final phoneRegex = RegExp(r'^[0-9]{9,12}$');
    if (!phoneRegex.hasMatch(normalizedPhone)) {
      return 'Ingrese un teléfono válido';
    }
    return null;
  }
}
