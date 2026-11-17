import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:quickalert/quickalert.dart';

class DocumentCoordScreen extends StatefulWidget {
  const DocumentCoordScreen({super.key, required this.login});

  final TourSales login;

  @override
  State<DocumentCoordScreen> createState() => _DocumentCoordScreenState();
}

class _DocumentCoordScreenState extends State<DocumentCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CoordinatorProviders _provider = CoordinatorProviders();
  List<Document> _documents = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _busyDocuments = {};

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final documents = await _provider.getDocument(
        widget.login.tourSalesId.toString(),
      );
      if (!mounted) return;
      setState(() => _documents = documents);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos cargar los documentos de la gira.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _fetchDocuments,
          child: ListView(
            key: PageStorageKey('documents-${widget.login.tourSalesId}'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _header(context),
              const SizedBox(height: 24),
              Text(
                'De la gira',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (_loading && _documents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Cargando documentos',
                    ),
                  ),
                )
              else ...[
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  _DocumentMessage(
                    title: _error!,
                    onRetry: _fetchDocuments,
                  )
                else if (_documents.isEmpty)
                  const _DocumentMessage(
                    title: 'Aún no hay documentos de la gira.',
                  )
                else
                  for (final document in _documents) _documentTile(document),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Volver',
              style: IconButton.styleFrom(
                backgroundColor: PapigirasColors.soft,
                minimumSize: const Size.square(48),
              ),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Actualizar documentos',
              onPressed: _loading ? null : _fetchDocuments,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Abrir menú',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(
            'Documentos',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Archivos disponibles para esta gira',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: PapigirasColors.muted),
        ),
      ],
    );
  }

  Widget _documentTile(Document document) {
    final available = document.documentName?.trim().isNotEmpty == true;
    final key = '${document.tourSalesUuid}-${document.documentName}';
    final busy = _busyDocuments.contains(key);
    final title = available
        ? document.documentName!.trim()
        : _documentTitle(document.documentType);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(26),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        leading: CircleAvatar(
          backgroundColor: PapigirasColors.surface,
          foregroundColor: PapigirasColors.teal,
          child: Icon(_iconForDocumentType(document.documentType)),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          available ? _formatLabel(document.documentName!) : 'No disponible',
        ),
        trailing: busy
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Ver documento',
                    onPressed: available
                        ? () => _perform(
                              key,
                              () => _provider.viewDocument(
                                document.tourSalesUuid,
                                document.documentName!,
                                widget.login.tourSalesId.toString(),
                                context,
                                'documentosextras',
                              ),
                            )
                        : null,
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                  IconButton(
                    tooltip: 'Guardar documento',
                    onPressed: available
                        ? () => _downloadDocument(document, key)
                        : null,
                    icon: const Icon(Icons.download_outlined),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _perform(String key, Future<void> Function() action) async {
    if (_busyDocuments.contains(key)) return;
    setState(() => _busyDocuments.add(key));
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos abrir o guardar el documento.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyDocuments.remove(key));
    }
  }

  Future<void> _downloadDocument(Document document, String key) async {
    var succeeded = false;
    await _perform(key, () async {
      await _provider.downloadDocument(
        document.tourSalesUuid,
        document.documentName!,
        widget.login.tourSalesId.toString(),
        'documentosextras',
      );
      succeeded = true;
    });
    if (!mounted || !succeeded) return;
    await QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: 'Éxito',
      text: 'Documento descargado',
      confirmBtnText: 'Continuar',
    );
  }

  String _formatLabel(String name) {
    final extension = name.contains('.') ? name.split('.').last : '';
    return extension.isEmpty ? 'Documento' : extension.toUpperCase();
  }

  String _documentTitle(String type) {
    switch (type) {
      case 'poliza':
        return 'Póliza';
      case 'gira':
        return 'Documento de la gira';
      case 'hotel':
        return 'Hotel';
      case 'Programa gira':
        return 'Programa de la gira';
      case 'Nomina alumnos':
        return 'Nómina de alumnos';
      default:
        return type.trim().isEmpty ? 'Documento' : type;
    }
  }

  IconData _iconForDocumentType(String type) {
    switch (type) {
      case 'poliza':
        return Icons.policy_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      case 'Nomina alumnos':
        return Icons.people_outline;
      default:
        return Icons.description_outlined;
    }
  }
}

class _DocumentMessage extends StatelessWidget {
  const _DocumentMessage({required this.title, this.onRetry});
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_rounded,
              color: PapigirasColors.teal,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      );
}
