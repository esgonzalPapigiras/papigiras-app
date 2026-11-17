import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/FullscreenImage.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class DetalleBitacoraCoordScreen extends StatefulWidget {
  const DetalleBitacoraCoordScreen({
    super.key,
    required this.idHito,
    required this.login,
    required this.canModify,
  });

  final TourSales login;
  final String idHito;
  final bool canModify;

  @override
  State<DetalleBitacoraCoordScreen> createState() =>
      _DetalleBitacoraCoordScreenState();
}

class _DetalleBitacoraCoordScreenState
    extends State<DetalleBitacoraCoordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  late Future<DetailHitoList> _detail;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _detail = _load();
  }

  Future<DetailHitoList> _load() => _provider.getHitoComplete(
        widget.idHito,
        widget.login.tourSalesId.toString(),
      );

  void _reload() => setState(() => _detail = _load());

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
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
        widget.login.tourSalesId.toString(),
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

  Future<void> _delete() async {
    if (!widget.canModify || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar este hito?'),
        content: const Text(
          'Se eliminarán el hito y sus fotografías. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style:
                TextButton.styleFrom(foregroundColor: PapigirasColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await _provider.deleteHito(
        widget.idHito,
        widget.login.tourSalesId.toString(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos eliminar el hito. Vuelve a intentarlo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: PapigirasColors.canvas,
        endDrawer: _deleting ? null : CoordinatorEndDrawer(login: widget.login),
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
            onPressed:
                _deleting ? null : () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(backgroundColor: PapigirasColors.soft),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Detalle del hito',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar hito',
            onPressed: _deleting ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Abrir menú',
            onPressed: _deleting
                ? null
                : () => _scaffoldKey.currentState?.openEndDrawer(),
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
                          detail.hora ?? 'Sin hora',
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
        if (widget.canModify) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _deleting ? null : _delete,
              style:
                  TextButton.styleFrom(foregroundColor: PapigirasColors.danger),
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(_deleting ? 'Eliminando hito…' : 'Eliminar hito'),
            ),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(28),
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
      ),
    );
  }
}
