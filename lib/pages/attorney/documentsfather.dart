import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class DocumentFatherScreen extends StatefulWidget {
  const DocumentFatherScreen({super.key, required this.login});

  final ResponseAttorney login;

  @override
  State<DocumentFatherScreen> createState() => _DocumentFatherScreenState();
}

class _DocumentFatherScreenState extends State<DocumentFatherScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  late Future<List<Document>> _documents;
  final _busy = <String>{};
  String? _drawerImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _documents = _fetchDocuments();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

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

  Future<List<Document>> _fetchDocuments() async {
    final documents =
        await _provider.getDocument(widget.login.tourId.toString());
    return documents
        .where(
          (document) =>
              document.documentType != 'Nomina alumnos' &&
              document.visibleToAll,
        )
        .toList();
  }

  Future<void> _refresh() async {
    final future = _fetchDocuments();
    setState(() => _documents = future);
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _runAction(Document document, {required bool preview}) async {
    final name = document.documentName?.trim() ?? '';
    if (name.isEmpty) return;
    final key = '${document.tourSalesUuid}-$name';
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      if (preview) {
        await _provider.viewDocument(
          document.tourSalesUuid,
          name,
          widget.login.tourId.toString(),
          context,
          'documentosextras',
        );
      } else {
        await _provider.downloadDocument(
          document.tourSalesUuid,
          name,
          widget.login.tourId.toString(),
          'documentosextras',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Documento descargado.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos abrir o guardar el documento.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
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
        child: FutureBuilder<List<Document>>(
          future: _documents,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final documents = snapshot.data ?? const <Document>[];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _buildHeader(loading),
                  if (loading)
                    const LinearProgressIndicator(minHeight: 2)
                  else if (snapshot.hasError)
                    _MessageState(
                      icon: Icons.cloud_off_outlined,
                      message: 'No pudimos cargar los documentos.',
                      onRetry: _refresh,
                    )
                  else if (documents.isEmpty)
                    const _MessageState(
                      icon: Icons.folder_open_outlined,
                      message: 'Aún no hay documentos para esta gira.',
                    )
                  else
                    for (final document in documents) _documentCard(document),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool loading) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Documentos',
                    style: Theme.of(context).textTheme.headlineMedium),
                Text('Archivos de la gira',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar documentos',
            onPressed: loading ? null : _refresh,
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

  Widget _documentCard(Document document) {
    final name = document.documentName?.trim() ?? '';
    final available = name.isNotEmpty;
    final key = '${document.tourSalesUuid}-$name';
    final busy = _busy.contains(key);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: PapigirasColors.surface,
            foregroundColor: PapigirasColors.teal,
            child: Icon(_iconFor(document.documentType)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  available ? name : document.documentType,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  available ? _formatLabel(name) : 'Archivo no disponible',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Ver documento',
              onPressed:
                  available ? () => _runAction(document, preview: true) : null,
              icon: const Icon(Icons.visibility_outlined),
            ),
            IconButton(
              tooltip: 'Descargar documento',
              onPressed:
                  available ? () => _runAction(document, preview: false) : null,
              icon: const Icon(Icons.download_rounded),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'poliza':
        return Icons.policy_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      case 'Nomina alumnos':
        return Icons.groups_outlined;
      case 'extra':
        return Icons.attach_file_rounded;
      default:
        return Icons.description_outlined;
    }
  }

  String _formatLabel(String name) {
    final extension =
        name.contains('.') ? name.split('.').last.toUpperCase() : '';
    return extension.isEmpty ? 'Documento de la gira' : 'Archivo $extension';
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState(
      {required this.icon, required this.message, this.onRetry});
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: PapigirasColors.teal),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ],
      ),
    );
  }
}
