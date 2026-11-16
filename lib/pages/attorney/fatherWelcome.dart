import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/media_data.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class WelcomeFatherScreen extends StatefulWidget {
  const WelcomeFatherScreen({super.key, required this.login});

  final ResponseAttorney login;

  @override
  State<WelcomeFatherScreen> createState() => _WelcomeFatherScreenState();
}

class _WelcomeFatherScreenState extends State<WelcomeFatherScreen> {
  final _provider = CoordinatorProviders();
  Uint8List? _photo;
  bool _checkingRecord = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    try {
      final result = await _provider.getPicturePassenger(
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
      );
      if (!mounted) return;
      final photo = LocalImageData.decode(result.image);
      if (photo != null) setState(() => _photo = photo);
    } catch (_) {
      // A missing or unreadable photo leaves the default avatar visible.
    }
  }

  Future<void> _continue() async {
    if (_checkingRecord) return;
    setState(() => _checkingRecord = true);
    try {
      final complete = await _provider.validateMedicalRecord(
        widget.login.passengerId.toString(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => complete
              ? TravelFatherDashboard(login: widget.login)
              : MedicalRecordScreen(login: widget.login),
        ),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos verificar la ficha médica. Intenta otra vez.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingRecord = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = formatStudentName(
      widget.login.passengerName,
      widget.login.passengerApellidos,
    );
    final school = formatSchoolName(widget.login.tourName);
    final theme = PiloFamilyTheme.theme(Theme.of(context));
    return Theme(
      data: theme,
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Image.asset(
                      'assets/logo-letras-papigiras.png',
                      width: 148,
                      semanticLabel: 'PapiGiras',
                    ),
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    header: true,
                    child: Text(
                      'Bienvenidos a bordo',
                      style: PiloFamilyTheme.display(50),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: PiloFamilyTheme.soft,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: _photo == null
                                ? const AssetImage('assets/profile.jpg')
                                : MemoryImage(_photo!),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name.isEmpty ? 'Estudiante' : name,
                            style: theme.textTheme.titleLarge,
                          ),
                          if (school.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(school, style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _checkingRecord ? null : _continue,
                    icon: _checkingRecord
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded, size: 20),
                    iconAlignment: IconAlignment.end,
                    label: Text(
                      _checkingRecord
                          ? 'Verificando ficha médica…'
                          : 'Continuar',
                      textAlign: TextAlign.center,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
