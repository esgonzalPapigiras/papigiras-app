import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/pilo_rut_input_formatter.dart';
import 'package:papigiras_app/design/pilo_student_home.dart';
import 'package:papigiras_app/design/pilo_student_medical_sheet.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';

class TravelPassengerDashboard extends StatefulWidget {
  const TravelPassengerDashboard({
    super.key,
    required this.login,
    this.provider,
  });
  final ResponseAttorney login;
  @visibleForTesting
  final CoordinatorProviders? provider;

  @override
  State<TravelPassengerDashboard> createState() =>
      _TravelPassengerDashboardState();
}

class _TravelPassengerDashboardState extends State<TravelPassengerDashboard>
    with WidgetsBindingObserver {
  late CoordinatorProviders _provider;
  PassengersMedicalRecordDTO? _record;
  PiloStudentMedicalStatus _status = PiloStudentMedicalStatus.loading;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? CoordinatorProviders();
    WidgetsBinding.instance.addObserver(this);
    LabSession.changed.addListener(_sessionChanged);
    _loadMedical();
  }

  @override
  void didUpdateWidget(covariant TravelPassengerDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      if (oldWidget.provider == null) _provider.dispose();
      _provider = widget.provider ?? CoordinatorProviders();
    }
    if (oldWidget.login.passengerId != widget.login.passengerId ||
        oldWidget.login.tourId != widget.login.tourId ||
        oldWidget.provider != widget.provider) {
      _loadMedical();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadMedical();
  }

  void _sessionChanged() {
    // Health data is held only in this signed-in view, never preferences/disk.
    ++_request;
    if (mounted)
      setState(() {
        _record = null;
        _status = PiloStudentMedicalStatus.failed;
      });
  }

  @override
  void dispose() {
    ++_request;
    LabSession.changed.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  Future<void> _loadMedical() async {
    final request = ++_request;
    final generation = LabSession.generation;
    final passenger = widget.login.passengerId;
    final tour = widget.login.tourId;
    setState(() {
      _record = null;
      _status = PiloStudentMedicalStatus.loading;
    });
    bool current() =>
        mounted && request == _request && generation == LabSession.generation;
    try {
      if (passenger == null || passenger <= 0 || tour == null || tour <= 0) {
        throw StateError('Missing medical identity');
      }
      final record = await _provider.getMedicalRecord('$tour', '$passenger');
      if (!current()) return;
      if (record.idPassengersMedicalRecord == null ||
          record.passengerId != passenger ||
          record.tourSalesId != tour) {
        throw StateError('Medical identity mismatch');
      }
      setState(() {
        _record = record;
        _status = PiloStudentMedicalStatus.ready;
      });
    } on LabApiException catch (error) {
      if (!current()) return;
      setState(
        () => _status = error.statusCode == 404
            ? PiloStudentMedicalStatus.missing
            : PiloStudentMedicalStatus.failed,
      );
    } catch (_) {
      if (!current()) return;
      setState(() => _status = PiloStudentMedicalStatus.failed);
    }
  }

  String get _name => formatStudentName(
    widget.login.passengerName,
    widget.login.passengerApellidos,
    short: true,
  );

  void _openMedical(BuildContext context) {
    final record = _record;
    if (_status != PiloStudentMedicalStatus.ready || record == null) return;
    final provider = _provider;
    final tour = record.tourSalesId;
    final passenger = record.passengerId;
    showPiloStudentMedicalSheet(
      context,
      studentName: formatStudentName(
        widget.login.passengerName,
        widget.login.passengerApellidos,
      ),
      studentIdentification: widget.login.passengerIdentificacion ?? '',
      loadPdf: () => provider.getMedicalRecordPdf('$tour', '$passenger'),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Builder(
      builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: PiloFamilyTheme.paper,
          body: PiloStudentHome(
            name: _name.isEmpty ? 'Estudiante' : _name,
            rut: PiloRutInputFormatter.formatDisplay(
              widget.login.passengerIdentificacion ?? '',
            ),
            avatar: ProfilePhotoAvatar(
              radius: 30,
              passenger: widget.login,
              provider: widget.provider,
            ),
            qr: Semantics(
              label: 'Código QR de identificación del estudiante',
              image: true,
              child: QrImageView(
                data: jsonEncode({
                  'id': 20,
                  'url': 'papigiras-lab:passenger/${widget.login.passengerId}',
                }),
                size: 200,
                padding: const EdgeInsets.all(12),
                backgroundColor: Colors.white,
              ),
            ),
            medicalStatus: _status,
            onMedical: () => _openMedical(context),
            onRetry: _loadMedical,
            onMenu: () => AppDrawerFather.showPiloStudentProfileSheet(
              context,
              login: widget.login,
              photoProvider: widget.provider,
            ),
          ),
        ),
      ),
    ),
  );
}
