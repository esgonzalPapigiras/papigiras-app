import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/medicalRecordScreenEdit.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class ViewMedicalRecordScreen extends StatefulWidget {
  const ViewMedicalRecordScreen({super.key, required this.login});
  final ResponseAttorney login;

  @override
  State<ViewMedicalRecordScreen> createState() =>
      _ViewMedicalRecordScreenState();
}

class _ViewMedicalRecordScreenState extends State<ViewMedicalRecordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  late Future<PassengersMedicalRecordDTO> _record;
  String? _drawerImage;

  @override
  void initState() {
    super.initState();
    _record = _loadRecord();
    _loadImage();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<PassengersMedicalRecordDTO> _loadRecord() =>
      _provider.getMedicalRecord(
        widget.login.tourId.toString(),
        widget.login.passengerId.toString(),
      );

  void _refresh() => setState(() => _record = _loadRecord());

  Future<void> _loadImage() async {
    try {
      final photo = await _provider.getPicturePassenger(
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
      );
      if (mounted) {
        setState(() => _drawerImage = photo.image.isEmpty ? null : photo.image);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PapigirasColors.canvas,
      endDrawer: AppDrawerFather(
        login: widget.login,
        imageFile: null,
        imageUrl: _drawerImage,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<PassengersMedicalRecordDTO>(
                future: _record,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final record = snapshot.data;
                  if (snapshot.hasError || record == null) {
                    return _MessageState(onRetry: _refresh);
                  }
                  return _RecordContent(
                    record: record,
                    login: widget.login,
                    onEdit: () => _openEditor(record),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
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
            tooltip: 'Actualizar ficha',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Abrir menú',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(PassengersMedicalRecordDTO record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicalRecordScreenEdit(
          login: widget.login,
          record: record,
        ),
      ),
    );
    if (mounted) _refresh();
  }
}

class _RecordContent extends StatelessWidget {
  const _RecordContent({
    required this.record,
    required this.login,
    required this.onEdit,
  });

  final PassengersMedicalRecordDTO record;
  final ResponseAttorney login;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final passenger = [login.passengerName, login.passengerApellidos]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PapigirasColors.soft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 23,
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
                      passenger.isEmpty ? 'Pasajero' : passenger,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      login.passengerIdentificacion ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _RecordSection(
          title: 'Datos médicos',
          icon: Icons.bloodtype_outlined,
          rows: [
            _RecordRow('Grupo sanguíneo', record.bloodType),
            _RecordRow('Enfermedades', record.diseases),
            _RecordRow('Medicamentos', record.medications),
            _RecordRow('Medicamentos a evitar', record.avoidMedications),
          ],
        ),
        const SizedBox(height: 14),
        _RecordSection(
          title: 'Contacto de emergencia',
          icon: Icons.emergency_outlined,
          rows: [
            _RecordRow('Nombre', record.emergencyContactName),
            _RecordRow('Relación', record.emergencyContactRelation),
            _RecordRow('Teléfono', record.emergencyContactPhone),
            _RecordRow('Correo', record.emergencyContactEmail),
          ],
        ),
        const SizedBox(height: 14),
        _RecordSection(
          title: 'Cobertura y cuidados',
          icon: Icons.health_and_safety_outlined,
          rows: [
            _RecordRow(
              'Cobertura',
              record.hasFonasa
                  ? 'FONASA'
                  : record.hasIsapre
                      ? 'ISAPRE${record.isapre?.trim().isNotEmpty == true ? ': ${record.isapre}' : ''}'
                      : 'Sin información',
            ),
            _RecordRow(
              'Cuidados especiales',
              record.requiresSpecialCare
                  ? record.specialCareDetails
                  : 'No requiere cuidados especiales',
            ),
            _RecordRow('Fecha de autorización', record.authorizationDate),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar ficha médica'),
        ),
      ],
    );
  }
}

class _RecordSection extends StatelessWidget {
  const _RecordSection(
      {required this.title, required this.icon, required this.rows});
  final String title;
  final IconData icon;
  final List<_RecordRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: PapigirasColors.teal),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index < rows.length - 1) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final content = value?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(content?.isNotEmpty == true ? content! : 'Sin información'),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.medical_information_outlined,
              size: 48, color: PapigirasColors.teal),
          const SizedBox(height: 14),
          const Text('No pudimos cargar la ficha médica.'),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
