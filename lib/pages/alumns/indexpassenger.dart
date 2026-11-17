import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TravelPassengerDashboard extends StatefulWidget {
  const TravelPassengerDashboard({super.key, required this.login});

  final ResponseAttorney login;

  @override
  State<TravelPassengerDashboard> createState() =>
      _TravelPassengerDashboardState();
}

class _TravelPassengerDashboardState extends State<TravelPassengerDashboard> {
  static const _passengerInformationUrl =
      'https://stingray-app-9tqd9.ondigitalocean.app/app/services/get/information/passenger?tourPassenger=';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CoordinatorProviders _provider = CoordinatorProviders();
  String? _imageUrl;

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
      // The default profile image remains visible when no photo is available.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = [
      widget.login.passengerName ?? '',
      widget.login.passengerApellidos ?? '',
    ].where((part) => part.trim().isNotEmpty).join(' ');
    final identification = widget.login.passengerIdentificacion ?? '';
    final qrData = jsonEncode({
      'id': 20,
      'url': '$_passengerInformationUrl${widget.login.passengerId}',
    });

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppDrawerFather(
        login: widget.login,
        imageUrl: _imageUrl,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: PapigirasColors.soft,
                        backgroundImage: _passengerImage(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Alumno', style: theme.textTheme.bodySmall),
                            const SizedBox(height: 5),
                            Text(
                              name.isEmpty ? 'Mi perfil' : name,
                              style: theme.textTheme.headlineMedium,
                            ),
                            if (identification.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'RUT $identification',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Abrir menú del alumno',
                        onPressed: () =>
                            _scaffoldKey.currentState?.openEndDrawer(),
                        style: IconButton.styleFrom(
                          backgroundColor: PapigirasColors.soft,
                          minimumSize: const Size.square(48),
                        ),
                        icon: const Icon(Icons.menu_rounded, size: 26),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                    decoration: BoxDecoration(
                      color: PapigirasColors.ink,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Mi pase',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: PapigirasColors.surface,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.qr_code_rounded,
                              color: PapigirasColors.mint,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final size = math.min(218.0, constraints.maxWidth);
                            return Center(
                              child: Container(
                                width: size,
                                height: size,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: QrImageView(
                                  data: qrData,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Muéstralo al coordinador',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: PapigirasColors.line,
                          ),
                        ),
                      ],
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
