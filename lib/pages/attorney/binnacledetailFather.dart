import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/FullscreenImageFather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class DetalleBitacoraFatherScreen extends StatefulWidget {
  const DetalleBitacoraFatherScreen({
    super.key,
    required this.idHito,
    required this.login,
  });

  final ResponseAttorney login;
  final String idHito;

  @override
  State<DetalleBitacoraFatherScreen> createState() =>
      _DetalleBitacoraFatherScreenState();
}

class _DetalleBitacoraFatherScreenState
    extends State<DetalleBitacoraFatherScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  late Future<DetailHitoList> _detail;
  String? _drawerImage;

  @override
  void initState() {
    super.initState();
    _detail = _load();
    _loadImage();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<DetailHitoList> _load() => _provider.getHitoComplete(
        widget.idHito,
        widget.login.tourId.toString(),
      );

  void _reload() => setState(() => _detail = _load());

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

  Future<void> _openPhoto(int? photoId, String previewBase64) async {
    if (photoId == null) {
      await Navigator.of(context).push(
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
      final bytes = await _provider.getHitoPhoto(
        photoId,
        widget.login.tourId.toString(),
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FullscreenImagePage(imageBytes: bytes),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar la foto.')),
      );
    }
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
              child: FutureBuilder<DetailHitoList>(
                future: _detail,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final detail = snapshot.data;
                  if (snapshot.hasError || detail == null) {
                    return _ErrorState(onRetry: _reload);
                  }
                  return _buildContent(detail);
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
            tooltip: 'Volver a la bitácora',
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(backgroundColor: PapigirasColors.soft),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Detalle del hito',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          IconButton(
            tooltip: 'Actualizar hito',
            onPressed: _reload,
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

  Widget _buildContent(DetailHitoList detail) {
    final images = detail.images ?? const <String>[];
    final thumbnails = detail.thumbnails ?? const <String>[];
    final photoIds = detail.photoIds ?? const <int>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: PapigirasColors.soft,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 23,
                    backgroundColor: PapigirasColors.mint,
                    foregroundColor: PapigirasColors.onMint,
                    child: Icon(Icons.place_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.titulo ?? 'Actividad no disponible',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail.fecha ?? detail.hora ?? 'Sin fecha',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: PapigirasColors.teal,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                detail.descripcion ?? 'Descripción no disponible',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text('Fotografías',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final preview = index < thumbnails.length
                        ? thumbnails[index]
                        : images[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openPhoto(
                        index < photoIds.length ? photoIds[index] : null,
                        images[index],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.memory(
                          base64Decode(preview.split(',').last),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: PapigirasColors.surface,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_outlined,
              size: 48, color: PapigirasColors.teal),
          const SizedBox(height: 14),
          const Text('No pudimos cargar este hito.'),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
