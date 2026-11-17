import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/pages/attorney/documentsfather.dart';
import 'package:papigiras_app/pages/attorney/tripulationbusfather.dart';
import 'package:papigiras_app/pages/attorney/viewProgram.dart';
import 'package:papigiras_app/pages/attorney/viewmedicalRecord.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/TraceMap.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class TravelFatherDashboard extends StatefulWidget {
  const TravelFatherDashboard({super.key, required this.login});
  final ResponseAttorney login;

  @override
  State<TravelFatherDashboard> createState() => _TravelFatherDashboardState();
}

class _TravelFatherDashboardState extends State<TravelFatherDashboard> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  XFile? _image;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _image = image);
    try {
      await _provider.addHitoFotoPassenger(
        widget.login.passengerId.toString(),
        widget.login.tourId.toString(),
        image,
      );
      await _loadImage();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la fotografía.')),
        );
      }
    }
  }

  Future<void> _loadImage() async {
    try {
      final photo = await _provider.getPicturePassenger(
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
      );
      if (mounted) {
        setState(() => _imageUrl = photo.image.isEmpty ? null : photo.image);
      }
    } catch (_) {
      if (mounted) setState(() => _imageUrl = null);
    }
  }

  ImageProvider<Object> _profileImage() {
    if (_image != null) return FileImage(File(_image!.path));
    final source = _imageUrl;
    if (source != null && source.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(source.split(',').last));
      } catch (_) {
        return NetworkImage(source);
      }
    }
    return const AssetImage('assets/profile.jpg');
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return 'Sin fecha';
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = [widget.login.passengerName, widget.login.passengerApellidos]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    final tour = [
      widget.login.tourName,
      widget.login.tourCourse,
      widget.login.tourYear?.toString(),
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PapigirasColors.canvas,
      endDrawer: AppDrawerFather(
        login: widget.login,
        imageFile: _image,
        imageUrl: _imageUrl,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Inicio',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                IconButton(
                  tooltip: 'Abrir menú',
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: PapigirasColors.soft,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                            radius: 40, backgroundImage: _profileImage()),
                        const Positioned(
                          right: -3,
                          bottom: -3,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: PapigirasColors.mint,
                            foregroundColor: PapigirasColors.onMint,
                            child: Icon(Icons.edit_rounded, size: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? 'Pasajero' : name,
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(widget.login.passengerIdentificacion ?? '',
                            style: Theme.of(context).textTheme.bodySmall),
                        TextButton.icon(
                          onPressed: () => _open(
                              ViewMedicalRecordScreen(login: widget.login)),
                          icon: const Icon(Icons.medical_information_outlined,
                              size: 18),
                          label: const Text('Ficha médica'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PapigirasColors.ink,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gira actual',
                      style: TextStyle(
                          color: PapigirasColors.mint,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(
                    tour.isEmpty ? 'Información de gira no disponible' : tour,
                    style: const TextStyle(
                        color: PapigirasColors.surface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: _date('Salida',
                              _formatDate(widget.login.tourSalesdateInitial))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _date('Regreso',
                              _formatDate(widget.login.tourSalesdateFinal))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Tu gira', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                _action(Icons.route_outlined, 'Bitácora',
                    () => _open(BitacoraFatherScreen(login: widget.login))),
                _action(Icons.event_note_outlined, 'Programa',
                    () => _open(ViewProgramScreen(login: widget.login))),
                _action(Icons.directions_bus_outlined, 'Tripulación',
                    () => _open(BusCrewFatherScreen(login: widget.login))),
                _action(Icons.folder_open_outlined, 'Documentos',
                    () => _open(DocumentFatherScreen(login: widget.login))),
              ],
            ),
            const SizedBox(height: 18),
            Text('Ubicación de la gira',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (widget.login.tourId != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: TraceMap(tourCode: widget.login.tourId!),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    _open(TraceMapFullScreen(tourCode: widget.login.tourId!)),
                icon: const Icon(Icons.open_in_full_rounded),
                label: const Text('Ampliar mapa'),
              ),
            ] else
              const Text('No hay una gira asociada para mostrar el mapa.'),
          ],
        ),
      ),
    );
  }

  Widget _date(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: PapigirasColors.mint)),
        Text(value,
            style: const TextStyle(
                color: PapigirasColors.surface, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PapigirasColors.soft,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: PapigirasColors.teal, size: 30),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _open(Widget destination) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => destination),
    );
  }
}
