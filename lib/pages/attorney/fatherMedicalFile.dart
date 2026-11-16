import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/design/medical_form_components.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/dto/requestMedicalRecord.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';
import 'package:papigiras_app/utils/page_navigation.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';

class MedicalRecordScreen extends StatefulWidget {
  const MedicalRecordScreen({
    super.key,
    required this.login,
    this.provider,
    this.pickProfileImage,
    this.savedRecord,
    this.startEditing = false,
    this.inSheet = false,
  });
  final ResponseAttorney login;
  final PassengersMedicalRecordDTO? savedRecord;
  final bool startEditing;
  final bool inSheet;
  @visibleForTesting
  final CoordinatorProviders? provider;
  @visibleForTesting
  final Future<XFile?> Function()? pickProfileImage;

  @override
  State<MedicalRecordScreen> createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends State<MedicalRecordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final usuarioProvider = widget.provider ?? CoordinatorProviders();
  final _formKey = GlobalKey<FormState>();
  // Controladores de texto
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _cursoController = TextEditingController();
  final TextEditingController _colegioController = TextEditingController();
  final TextEditingController _comunaController = TextEditingController();
  TextEditingController _rutController = TextEditingController();
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

  PassengersMedicalRecordDTO? _savedRecord;
  bool _editing = true;
  bool _exporting = false;
  bool _leaving = false;
  String? _notice;
  String? _exportError;
  bool get _isExisting => _savedRecord != null;
  bool get _readOnly => _isExisting && !_editing;
  bool get _legacyMedications =>
      _savedRecord != null &&
      (_savedRecord!.medicationItems == null ||
          _savedRecord!.takesMedications == false) &&
      _savedRecord!.medications.trim().isNotEmpty;
  final _legacyMedicines = TextEditingController();
  bool _showValidationError = false;
  bool _isSaving = false;
  bool _confirming = false;
  String? _saveError;
  final _telefonoEmergenciaKey = GlobalKey();
  final _emailEmergenciaKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  GlobalKey? _firstInvalidFieldKey;

  String? _grupoSanguineo;
  bool _tieneFonasa = false;
  bool _tieneIsapre = false;
  bool _tieneEnfermedades = false;
  bool _tomaMedicamentos = false;
  bool _evitarMedicamentos = false;

  // Existing request defaults: these fields were not rendered in the initial
  // form. Do not invent new medical questions or change their stored meaning.
  final bool _requiereCuidadosEspeciales = false;
  final DateTime? _fechaNacimiento = null;
  final DateTime? _fechaAutorizacion = null;

  @override
  void initState() {
    super.initState();
    _rutController.text = widget.login.passengerIdentificacion ?? '';
    _savedRecord = widget.savedRecord;
    _editing = _savedRecord == null || widget.startEditing;
    if (_savedRecord != null) _restoreSaved();
  }

  @override
  void dispose() {
    _legacyMedicines.dispose();
    _nombreController.dispose();
    _apellidoController.dispose();
    _cursoController.dispose();
    _colegioController.dispose();
    _comunaController.dispose();
    _rutController.dispose();
    _nombreEmergenciaController.dispose();
    _relacionEmergenciaController.dispose();
    _telefonoEmergenciaController.dispose();
    _emailEmergenciaController.dispose();
    _especificarEnfermedadesController.dispose();
    _isapreController.dispose();
    _medicamento1Controller.dispose();
    _dosis1Controller.dispose();
    _medicamento2Controller.dispose();
    _dosis2Controller.dispose();
    _medicamentosEvitarController.dispose();
    _cuidadosEspecialesController.dispose();
    _scrollController.dispose();
    if (widget.provider == null) usuarioProvider.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'El correo es obligatorio';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) return 'Ingresa un correo válido';
    return null;
  }

  String? _validateTelefono(String? value) {
    if (value == null || value.isEmpty) return 'El teléfono es obligatorio';
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), '');
    final phoneRegex = RegExp(r'^[0-9]{9,12}$');
    if (!phoneRegex.hasMatch(normalized)) return 'Ingresa un teléfono válido';
    return null;
  }

  Future<void> _scrollToFirstInvalidField(BuildContext context) async {
    // Validate synchronously, then wait for the inline errors to lay out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _firstInvalidFieldKey?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: .15,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      MedicalFormScope(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: !_isSaving && (!_isExisting || !_editing),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSaving && _editing) {
          _discard(context, closeSheet: widget.inSheet);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: colors.surface,
        endDrawer: widget.inSheet ? null : AppDrawerFather(login: widget.login),
        body: SingleChildScrollView(
          key: const PageStorageKey('initial-medical-form'),
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.inSheet)
                PiloSectionBar(
                  title: 'Ficha médica',
                  onBack: _isExisting ? () => _back(context) : null,
                  actions: [
                    if (!_isSaving && (!_isExisting || !_editing))
                      IconButton(
                        tooltip: 'Abrir menú',
                        onPressed: () =>
                            _scaffoldKey.currentState?.openEndDrawer(),
                        icon: const Icon(Icons.menu_rounded),
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SafeArea(
                      top: false,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _profile(context),
                            if (_isExisting) ...[
                              const SizedBox(height: 18),
                              _savedActions(context),
                            ],
                            MedicalFormReadOnly(
                              readOnly: _readOnly,
                              child: AbsorbPointer(
                                absorbing: _isSaving,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MedicalFormSection(
                                      title: 'Datos del pasajero',
                                      children: [
                                        Text(
                                          'Grupo sanguíneo',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 7),
                                        if (_readOnly)
                                          InputDecorator(
                                            decoration: const InputDecoration(),
                                            child: Text(
                                              _grupoSanguineo?.isNotEmpty ==
                                                      true
                                                  ? _grupoSanguineo!
                                                  : 'Sin informar',
                                            ),
                                          )
                                        else
                                          DropdownButtonFormField<String>(
                                            key: const ValueKey(
                                              'medical-blood-type',
                                            ),
                                            initialValue: _grupoSanguineo,
                                            isExpanded: true,
                                            itemHeight: null,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            style: theme.textTheme.bodyLarge,
                                            decoration: const InputDecoration(
                                              hintText: 'Selecciona una opción',
                                            ),
                                            items:
                                                [
                                                      'A+',
                                                      'A-',
                                                      'B+',
                                                      'B-',
                                                      'AB+',
                                                      'AB-',
                                                      'O+',
                                                      'O-',
                                                      'Otro',
                                                      if (_grupoSanguineo !=
                                                              null &&
                                                          ![
                                                            'A+',
                                                            'A-',
                                                            'B+',
                                                            'B-',
                                                            'AB+',
                                                            'AB-',
                                                            'O+',
                                                            'O-',
                                                            'Otro',
                                                          ].contains(
                                                            _grupoSanguineo,
                                                          ) &&
                                                          _grupoSanguineo!
                                                              .isNotEmpty)
                                                        _grupoSanguineo!,
                                                    ]
                                                    .map(
                                                      (
                                                        value,
                                                      ) => DropdownMenuItem(
                                                        value: value,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 12,
                                                              ),
                                                          child: Text(value),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                            onChanged: (value) => setState(
                                              () => _grupoSanguineo = value,
                                            ),
                                          ),
                                      ],
                                    ),
                                    MedicalFormSection(
                                      title: 'Contacto de emergencia',
                                      children: [
                                        MedicalFormField(
                                          key: const ValueKey(
                                            'medical-contact-name',
                                          ),
                                          label: 'Nombre y apellido',
                                          controller:
                                              _nombreEmergenciaController,
                                          capitalization:
                                              TextCapitalization.words,
                                        ),
                                        MedicalFormField(
                                          key: const ValueKey(
                                            'medical-contact-relation',
                                          ),
                                          label: 'Relación con el alumno(a)',
                                          controller:
                                              _relacionEmergenciaController,
                                        ),
                                        MedicalFormField(
                                          key: _telefonoEmergenciaKey,
                                          label: 'Teléfono celular',
                                          controller:
                                              _telefonoEmergenciaController,
                                          keyboardType: TextInputType.phone,
                                          capitalization:
                                              TextCapitalization.none,
                                          validator: (v) {
                                            final result = _validateTelefono(v);
                                            if (result != null)
                                              _firstInvalidFieldKey ??=
                                                  _telefonoEmergenciaKey;
                                            return result;
                                          },
                                        ),
                                        MedicalFormField(
                                          key: _emailEmergenciaKey,
                                          label: 'Correo electrónico',
                                          controller:
                                              _emailEmergenciaController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          capitalization:
                                              TextCapitalization.none,
                                          validator: (v) {
                                            final result = _validateEmail(v);
                                            if (result != null)
                                              _firstInvalidFieldKey ??=
                                                  _emailEmergenciaKey;
                                            return result;
                                          },
                                        ),
                                      ],
                                    ),
                                    MedicalFormSection(
                                      title: 'Cobertura médica',
                                      children: [
                                        MedicalYesNo(
                                          key: const ValueKey('medical-fonasa'),
                                          label: '¿Tiene FONASA?',
                                          value: _tieneFonasa,
                                          onChanged: (value) => setState(
                                            () => _tieneFonasa = value,
                                          ),
                                        ),
                                        MedicalYesNo(
                                          key: const ValueKey('medical-isapre'),
                                          label: '¿Tiene ISAPRE?',
                                          value: _tieneIsapre,
                                          onChanged: (value) => setState(
                                            () => _tieneIsapre = value,
                                          ),
                                        ),
                                        if (_tieneIsapre)
                                          MedicalFormField(
                                            key: const ValueKey(
                                              'medical-isapre-name',
                                            ),
                                            label: 'Nombre de la ISAPRE',
                                            controller: _isapreController,
                                          ),
                                      ],
                                    ),
                                    MedicalFormSection(
                                      title: 'Antecedentes médicos',
                                      children: [
                                        MedicalYesNo(
                                          key: const ValueKey(
                                            'medical-diseases',
                                          ),
                                          label:
                                              '¿Tiene enfermedades crónicas o alergias?',
                                          value: _tieneEnfermedades,
                                          onChanged: (value) => setState(
                                            () => _tieneEnfermedades = value,
                                          ),
                                        ),
                                        if (_tieneEnfermedades ||
                                            (_readOnly &&
                                                _especificarEnfermedadesController
                                                    .text
                                                    .isNotEmpty))
                                          MedicalFormField(
                                            key: const ValueKey(
                                              'medical-diseases-detail',
                                            ),
                                            label:
                                                'Enfermedades crónicas o alergias',
                                            controller:
                                                _especificarEnfermedadesController,
                                            keyboardType:
                                                TextInputType.multiline,
                                            maxLines: 4,
                                          ),
                                      ],
                                    ),
                                    MedicalFormSection(
                                      title: 'Medicamentos',
                                      children: [
                                        MedicalFormReadOnly(
                                          readOnly:
                                              _readOnly || _legacyMedications,
                                          child: MedicalYesNo(
                                            key: const ValueKey(
                                              'medical-medication',
                                            ),
                                            label:
                                                '¿Toma medicamentos regularmente?',
                                            value: _tomaMedicamentos,
                                            onChanged: (value) => setState(
                                              () => _tomaMedicamentos = value,
                                            ),
                                          ),
                                        ),
                                        if (_legacyMedications)
                                          MedicalFormReadOnly(
                                            readOnly: true,
                                            child: MedicalFormField(
                                              label: 'Medicamentos registrados',
                                              controller: _legacyMedicines,
                                              maxLines: 8,
                                            ),
                                          ),
                                        if (_tomaMedicamentos &&
                                            !_legacyMedications) ...[
                                          MedicalFormField(
                                            key: const ValueKey(
                                              'medical-medication-1',
                                            ),
                                            label: 'Medicamento 1',
                                            controller: _medicamento1Controller,
                                          ),
                                          MedicalFormField(
                                            key: const ValueKey(
                                              'medical-dose-1',
                                            ),
                                            label: 'Dosis del medicamento 1',
                                            controller: _dosis1Controller,
                                          ),
                                          MedicalFormField(
                                            key: const ValueKey(
                                              'medical-medication-2',
                                            ),
                                            label: 'Medicamento 2',
                                            controller: _medicamento2Controller,
                                          ),
                                          MedicalFormField(
                                            key: const ValueKey(
                                              'medical-dose-2',
                                            ),
                                            label: 'Dosis del medicamento 2',
                                            controller: _dosis2Controller,
                                          ),
                                        ],
                                        MedicalYesNo(
                                          key: const ValueKey('medical-avoid'),
                                          label:
                                              '¿Debe evitar algún medicamento?',
                                          value: _evitarMedicamentos,
                                          onChanged: (value) => setState(
                                            () => _evitarMedicamentos = value,
                                          ),
                                        ),
                                        if (_evitarMedicamentos ||
                                            (_readOnly &&
                                                _medicamentosEvitarController
                                                    .text
                                                    .isNotEmpty))
                                          MedicalFormField(
                                            key: const ValueKey(
                                              'medical-avoid-detail',
                                            ),
                                            label:
                                                'Medicamentos que debe evitar',
                                            controller:
                                                _medicamentosEvitarController,
                                            keyboardType:
                                                TextInputType.multiline,
                                            maxLines: 4,
                                            action: TextInputAction.done,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_readOnly)
                              MedicalFormSection(
                                title: 'Autorización médica',
                                children: [
                                  Text(
                                    'Autorización registrada${_savedDate().isEmpty ? '' : ' · ${_savedDate()}'}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Autorizo a los encargados del viaje y a los servicios médicos correspondientes a realizar procedimientos médicos de urgencia en caso de ser necesario.',
                                  ),
                                ],
                              ),
                            if (_showValidationError || _saveError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _saveError ??
                                        'Revisa el teléfono y el correo electrónico antes de guardar.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.error,
                                    ),
                                  ),
                                ),
                              ),
                            if (!_readOnly)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  key: const ValueKey('medical-save'),
                                  onPressed: (_isSaving || _confirming)
                                      ? null
                                      : () => _save(context),
                                  child: _isSaving
                                      ? Wrap(
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 12,
                                          runSpacing: 8,
                                          children: [
                                            const SizedBox.square(
                                              dimension: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: PiloFamilyTheme.ink,
                                              ),
                                            ),
                                            Text(
                                              'Guardando ficha',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ],
                                        )
                                      : Text(
                                          _isExisting
                                              ? 'Guardar cambios'
                                              : 'Guardar ficha médica',
                                          textAlign: TextAlign.center,
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profile(BuildContext context) {
    final theme = Theme.of(context);
    final name = formatStudentName(
      widget.login.passengerName,
      widget.login.passengerApellidos,
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(
          'RUT ${_rutController.text.isEmpty ? 'no disponible' : _rutController.text}',
          key: const ValueKey('medical-rut'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final avatar = ProfilePhotoAvatar(
      key: const ValueKey('medical-profile-photo'),
      radius: 42,
      passenger: widget.login,
      provider: usuarioProvider,
      pickImage: widget.pickProfileImage,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 340 &&
                MediaQuery.textScalerOf(context).scale(17) > 25) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [avatar, const SizedBox(height: 14), identity],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(child: identity),
              ],
            );
          },
        ),
      ),
    );
  }

  void _restoreSaved() {
    final r = _savedRecord!;
    _grupoSanguineo = (r.bloodType?.isEmpty ?? true) ? null : r.bloodType;
    _nombreEmergenciaController.text = r.emergencyContactName ?? '';
    _relacionEmergenciaController.text = r.emergencyContactRelation ?? '';
    _telefonoEmergenciaController.text = r.emergencyContactPhone ?? '';
    _emailEmergenciaController.text = r.emergencyContactEmail ?? '';
    _tieneFonasa = r.hasFonasa;
    _tieneIsapre = r.hasIsapre;
    _isapreController.text = r.isapre ?? '';
    _tieneEnfermedades = r.hasDiseases ?? (r.diseases?.isNotEmpty ?? false);
    _especificarEnfermedadesController.text = r.diseases ?? '';
    _tomaMedicamentos = r.takesMedications ?? r.medications.isNotEmpty;
    final items = r.medicationItems ?? <Map<String, String>>[];
    _medicamento1Controller.text = items.isNotEmpty
        ? items[0]['nombre'] ?? ''
        : '';
    _dosis1Controller.text = items.isNotEmpty ? items[0]['dosis'] ?? '' : '';
    _medicamento2Controller.text = items.length > 1
        ? items[1]['nombre'] ?? ''
        : '';
    _dosis2Controller.text = items.length > 1 ? items[1]['dosis'] ?? '' : '';
    _legacyMedicines.text = r.medications;
    _evitarMedicamentos =
        r.avoidsMedications ?? (r.avoidMedications?.isNotEmpty ?? false);
    _medicamentosEvitarController.text = r.avoidMedications ?? '';
  }

  String _savedDate() {
    final date = DateTime.tryParse(_savedRecord?.authorizationDate ?? '');
    return date == null
        ? ''
        : DateFormat('dd/MM/yyyy · HH:mm').format(date.toLocal());
  }

  Future<void> _discard(BuildContext context, {bool closeSheet = false}) async {
    if (_leaving || _isSaving) return;
    _leaving = true;
    final discard = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      animationStyle: AnimationStyle.noAnimation,
      builder: (dialog) => const MedicalDecisionDialog(
        title: '¿Descartar los cambios?',
        message: 'La ficha guardada se mantendrá sin cambios.',
        primaryLabel: 'Descartar',
        secondaryLabel: 'Seguir editando',
      ),
    );
    _leaving = false;
    if (!mounted || !context.mounted || discard != true) return;
    if (closeSheet) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _editing = false;
      _restoreSaved();
      _saveError = null;
      _showValidationError = false;
    });
  }

  void _back(BuildContext context) {
    if (_isSaving) return;
    if (_isExisting && _editing) {
      _discard(context);
      return;
    }
    Navigator.maybePop(context);
  }

  Future<void> _export(BuildContext context, {required bool share}) async {
    if (_exporting || _editing) return;
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    try {
      if (share) {
        await usuarioProvider.shareDocumentMedicalRecord(
          widget.login.tourId.toString(),
          widget.login.passengerId.toString(),
          widget.login.passengerIdentificacion ?? 'pasajero',
        );
      } else {
        await usuarioProvider.downloadDocumentMedicalRecord(
          widget.login.tourId.toString(),
          widget.login.passengerId.toString(),
          widget.login.passengerIdentificacion ?? 'pasajero',
        );
      }
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _exportError = 'No se pudo obtener el PDF. Vuelve a intentarlo.',
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _savedActions(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _editing ? Icons.edit_outlined : Icons.lock_outline_rounded,
              size: 17,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                _editing
                    ? 'Editando ficha médica'
                    : 'Ficha guardada · Solo lectura',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _notice!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (!_editing)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('medical-edit'),
              onPressed: _exporting
                  ? null
                  : () {
                      setState(() {
                        _editing = true;
                        _notice = null;
                        _saveError = null;
                      });
                    },
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Editar ficha médica'),
            ),
          )
        else
          TextButton.icon(
            key: const ValueKey('medical-cancel-edit'),
            onPressed: _isSaving ? null : () => _discard(context),
            icon: const Icon(Icons.close_rounded, size: 20),
            label: const Text('Cancelar edición'),
          ),
        if (!_editing)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              TextButton.icon(
                key: const ValueKey('medical-download'),
                onPressed: _exporting
                    ? null
                    : () => _export(context, share: false),
                icon: const Icon(Icons.download_outlined, size: 20),
                label: const Text('Descargar PDF'),
              ),
              TextButton.icon(
                key: const ValueKey('medical-share'),
                onPressed: _exporting
                    ? null
                    : () => _export(context, share: true),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                label: const Text('Compartir PDF'),
              ),
            ],
          ),
        if (_exporting) const LinearProgressIndicator(),
        if (_exportError != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _exportError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    if (_isSaving || _confirming || _readOnly) return;
    _firstInvalidFieldKey = null;
    final valid = _formKey.currentState!.validate();
    setState(() {
      _showValidationError = !valid;
      _saveError = null;
    });
    if (!valid) {
      _scrollToFirstInvalidField(context);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _confirming = true);
    final authorized = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      animationStyle: AnimationStyle.noAnimation,
      builder: (dialogContext) => MedicalDecisionDialog(
        title: 'Autorización médica',
        message:
            'Autorizo a los encargados del viaje y a los servicios médicos correspondientes a realizar procedimientos médicos de urgencia en caso de ser necesario.',
        primaryLabel: _isExisting
            ? 'Autorizar y actualizar'
            : 'Autorizar y guardar',
        secondaryLabel: 'Volver',
        primaryKey: const ValueKey('medical-confirm-save'),
      ),
    );
    if (!mounted) return;
    if (authorized != true) {
      setState(() => _confirming = false);
      return;
    }
    setState(() {
      _confirming = false;
      _isSaving = true;
    });
    RequestPassengerMedical medical = RequestPassengerMedical(
      nombres: _nombreController.text,
      apellidos: _apellidoController.text,
      curso: _cursoController.text,
      colegio: _colegioController.text,
      comuna: _comunaController.text,
      rut: _rutController.text,
      grupoSanguineo: _grupoSanguineo ?? '',
      contactoEmergenciaNombre: _nombreEmergenciaController.text,
      contactoEmergenciaRelacion: _relacionEmergenciaController.text,
      contactoEmergenciaTelefono: _telefonoEmergenciaController.text,
      contactoEmergenciaEmail: _emailEmergenciaController.text,
      tieneFonasa: _tieneFonasa,
      tieneIsapre: _tieneIsapre,
      isapre: _isapreController.text,
      tieneEnfermedades: _tieneEnfermedades,
      enfermedades: _tieneEnfermedades
          ? _especificarEnfermedadesController.text
          : null,
      tomaMedicamentos: _tomaMedicamentos,
      medicamentos: _tomaMedicamentos
          ? [
              {
                'nombre': _medicamento1Controller.text,
                'dosis': _dosis1Controller.text,
              },
              {
                'nombre': _medicamento2Controller.text,
                'dosis': _dosis2Controller.text,
              },
            ]
          : [],
      evitarMedicamentos: _evitarMedicamentos,
      medicamentosEvitar: _evitarMedicamentos
          ? _medicamentosEvitarController.text
          : null,
      requiereCuidadosEspeciales: _requiereCuidadosEspeciales,
      cuidadosEspeciales: _requiereCuidadosEspeciales
          ? _cuidadosEspecialesController.text
          : null,
      fechaNacimiento: _fechaNacimiento ?? DateTime.now(),
      fechaAutorizacion: _fechaAutorizacion ?? DateTime.now(),
      idPassenger: widget.login.passengerId!,
      idTour: widget.login.tourId!,
    );
    try {
      if (_isExisting) {
        final updated = await usuarioProvider.updateFamilyMedicalRecord(
          medical,
          revision: _savedRecord!.revision ?? '',
          preserveLegacyMedications: _legacyMedications,
        );
        if (!mounted) return;
        setState(() {
          _savedRecord = updated;
          _editing = false;
          _isSaving = false;
          _restoreSaved();
          _notice = 'Ficha médica actualizada y guardada';
        });
        _scrollController.jumpTo(0);
        return;
      }
      final saved = await usuarioProvider.createMedicalRecord(medical);
      if (!mounted || !context.mounted) return;
      if (!saved) throw StateError('Medical record not saved');
      setState(() => _isSaving = false);
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        animationStyle: AnimationStyle.noAnimation,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            scrollable: true,
            title: const Text('Ficha médica guardada'),
            content: const Text(
              'La información del pasajero quedó registrada.',
            ),
            actions: [
              FilledButton(
                key: const ValueKey('medical-continue'),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || !context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        buildPapiRoute(TravelFatherDashboard(login: widget.login)),
        (_) => false,
      );
    } on LabApiException catch (error) {
      if (mounted)
        setState(
          () => _saveError = error.statusCode == 409
              ? 'La ficha cambió en otra sesión. Conservamos tus respuestas; vuelve a abrir la ficha para revisar la versión actual antes de editar.'
              : 'No se pudo guardar la ficha médica. Tus respuestas siguen aquí; vuelve a intentarlo.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _saveError =
              'No se pudo guardar la ficha médica. Tus respuestas siguen aquí; vuelve a intentarlo.',
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
