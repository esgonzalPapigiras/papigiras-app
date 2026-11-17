import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/FullscreenImage.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class DetalleBitacoraCoordScreen extends StatefulWidget {
  final TourSales login;
  final String idHito;
  final bool canModify;

  const DetalleBitacoraCoordScreen({
    super.key,
    required this.idHito,
    required this.login,
    required this.canModify,
  });

  @override
  State<DetalleBitacoraCoordScreen> createState() =>
      _DetalleBitacoraCoordScreenState();
}

class _DetalleBitacoraCoordScreenState
    extends State<DetalleBitacoraCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _coordinatorProvider = CoordinatorProviders();
  Future<DetailHitoList>? _hitoDetailFuture;

  @override
  void initState() {
    super.initState();
    _hitoDetailFuture = _coordinatorProvider.getHitoComplete(
        widget.idHito, widget.login.tourSalesId.toString());
  }

  Future<void> _openHitoPhoto(int? photoId, String previewBase64) async {
    if (photoId == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullscreenImagePage(
            imageBytes: base64Decode(previewBase64.split(',').last),
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await _coordinatorProvider.getHitoPhoto(
        photoId,
        widget.login.tourSalesId.toString(),
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullscreenImagePage(imageBytes: bytes),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la foto: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kCoordinatorTeal,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: Stack(
        children: [
          _buildBackground(),
          Column(
            children: [
              CoordinatorTopBar(login: widget.login, scaffoldKey: _scaffoldKey),
              Expanded(
                child: FutureBuilder<DetailHitoList>(
                  future: _hitoDetailFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: Text('No data available'));
                    }
                    return _buildContent(snapshot.data!);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
        decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover)));
  }

  Widget _buildContent(DetailHitoList hitoDetail) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(40), topRight: Radius.circular(40))),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          if (widget.canModify)
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  QuickAlert.show(
                    context: context,
                    type: QuickAlertType.confirm,
                    title: 'Confirmación',
                    text:
                        '¿Está seguro que quiere borrar el hito? Se perderá para siempre.',
                    confirmBtnText: 'Sí',
                    cancelBtnText: 'No',
                    onConfirmBtnTap: () async {
                      Navigator.of(context).pop();
                      await _coordinatorProvider.deleteHito(
                          widget.idHito, widget.login.tourSalesId.toString());
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
                    onCancelBtnTap: () {
                      Navigator.of(context).pop();
                    },
                  );
                },
                icon: const Icon(Icons.delete, color: Colors.white),
                label: const Text('Eliminar Hito',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ),
          if (widget.canModify) const SizedBox(height: 20),
          Expanded(
              child: ListView(children: _buildBinnacleEntries(hitoDetail))),
        ],
      ),
    );
  }

  List<Widget> _buildBinnacleEntries(DetailHitoList hitoDetail) {
    final entries = [
      {
        'time': hitoDetail.hora ?? 'Sin hora',
        'activity': hitoDetail.titulo ?? 'Actividad no disponible',
        'description': hitoDetail.descripcion ?? 'Descripción no disponible',
        'images': hitoDetail.images ?? const <String>[],
        'thumbnails': hitoDetail.thumbnails ?? const <String>[],
        'photoIds': hitoDetail.photoIds ?? const <int>[],
      }
    ];

    return entries.map((entry) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.place, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(entry['time'].toString(),
                      style: const TextStyle(
                          color: Colors.teal,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(entry['activity'].toString(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600))),
                ],
              ),
              const SizedBox(height: 8),
              Text(entry['description'].toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 16),
              Column(
                children: [
                  for (var index = 0;
                      index < (entry['images'] as List).length;
                      index++)
                    GestureDetector(
                      onTap: () => _openHitoPhoto(
                        index < (entry['photoIds'] as List).length
                            ? (entry['photoIds'] as List)[index] as int
                            : null,
                        (entry['images'] as List)[index] as String,
                      ),
                      child: Image.memory(
                          base64Decode(((entry['thumbnails'] as List?) ??
                                  entry['images'] as List)[index]
                              .split(',')
                              .last),
                          height: 200,
                          width: 200,
                          fit: BoxFit.cover),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
