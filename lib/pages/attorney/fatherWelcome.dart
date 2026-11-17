import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
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
  final CoordinatorProviders _provider = CoordinatorProviders();
  String? _imageUrl;
  bool _checkingRecord = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final Responseimagepassenger result = await _provider.getPicturePassenger(
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
      );
      if (mounted && result.image.isNotEmpty) {
        setState(() => _imageUrl = result.image);
      }
    } catch (_) {
      // The default avatar remains visible when the passenger has no photo.
    }
  }

  ImageProvider<Object> _passengerImage() {
    final image = _imageUrl;
    if (image == null || image.isEmpty) {
      return const AssetImage('assets/profile.jpg');
    }
    try {
      return MemoryImage(base64Decode(image.split(',').last));
    } catch (_) {
      return NetworkImage(image);
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
            'No pudimos verificar la ficha médica. Intenta nuevamente.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingRecord = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passengerName = widget.login.passengerName ?? '';
    final passengerLastName = widget.login.passengerApellidos ?? '';
    final tourName = widget.login.tourName ?? '';
    final fullName = [
      passengerName,
      passengerLastName,
    ].where((part) => part.trim().isNotEmpty).join(' ');

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/logo-letras-papigiras.png',
                    width: 148,
                    semanticLabel: 'PapiGiras',
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Bienvenidos a bordo',
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: PapigirasColors.soft,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: PapigirasColors.surface,
                        backgroundImage: _passengerImage(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        fullName.isEmpty ? 'Estudiante' : fullName,
                        style: theme.textTheme.titleLarge,
                      ),
                      if (tourName.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          tourName,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
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
                    _checkingRecord ? 'Verificando ficha médica…' : 'Continuar',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
