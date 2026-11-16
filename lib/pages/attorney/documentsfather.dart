import '../../navigation/family_navigation.dart';
import 'package:flutter/material.dart';
import '../../design/pilo_family_theme.dart';
import '../../documents/documents_ui.dart';
import '../../dto/document.dart';
import '../../dto/responseAttorney.dart';
import '../../provider/coordinatorProvider.dart';
import '../../utils/app_drawer_father.dart';
import '../../utils/page_navigation.dart';
import 'indexFather.dart';

class DocumentFatherScreen extends StatefulWidget {
  const DocumentFatherScreen({super.key, required this.login, this.provider});
  final ResponseAttorney login;
  final CoordinatorProviders? provider;
  @override
  State<DocumentFatherScreen> createState() => _DocumentFatherScreenState();
}

class _DocumentFatherScreenState extends State<DocumentFatherScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late CoordinatorProviders usuarioProvider =
      widget.provider ?? CoordinatorProviders();
  late Future<List<Document>> _documentsFuture;
  String? _imageUrl;
  final _busy = <String>{};
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _documentsFuture = fetchDocuments('${widget.login.tourId}');
  }

  @override
  void didUpdateWidget(covariant DocumentFatherScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.login.tourId != widget.login.tourId ||
        oldWidget.provider != widget.provider ||
        oldWidget.login.passengerId != widget.login.passengerId) {
      ++_generation;
      if (oldWidget.provider == null) usuarioProvider.dispose();
      usuarioProvider = widget.provider ?? CoordinatorProviders();
      _imageUrl = null;
      _busy.clear();
      _loadImage();
      _documentsFuture = fetchDocuments('${widget.login.tourId}');
    }
  }

  @override
  void dispose() {
    ++_generation;
    if (widget.provider == null) usuarioProvider.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final generation = _generation;
    try {
      final photo = await usuarioProvider.getPicturePassenger(
        '${widget.login.passengerIdentificacion}',
        '${widget.login.tourId}',
      );
      if (mounted && generation == _generation)
        setState(() => _imageUrl = photo.image.isEmpty ? null : photo.image);
    } catch (_) {
      /* Existing drawer fallback; never display a different profile. */
    }
  }

  Future<List<Document>> fetchDocuments(String tourCode) async {
    final documents = await usuarioProvider.getDocument(tourCode);
    // Preserve the existing family visibility rules. Never request internal docs.
    return documents
        .where((d) => d.documentType != 'Nomina alumnos' && d.visibleToAll)
        .toList();
  }

  Future<void> _refresh() async {
    final future = fetchDocuments('${widget.login.tourId}');
    setState(() {
      _documentsFuture = future;
    });
    try {
      await future;
    } catch (_) {
      /* FutureBuilder presents the recovery state. */
    }
  }

  Future<void> _action(Document document, bool preview) async {
    final key = '${document.tourSalesUuid}-${document.documentName}';
    if (_busy.contains(key) || document.documentName?.trim().isNotEmpty != true)
      return;
    final generation = _generation;
    setState(() => _busy.add(key));
    try {
      if (preview) {
        await usuarioProvider.viewDocument(
          document.tourSalesUuid,
          document.documentName!,
          '${widget.login.tourId}',
          context,
          'documentosextras',
        );
      } else {
        await usuarioProvider.downloadDocument(
          document.tourSalesUuid,
          document.documentName!,
          '${widget.login.tourId}',
          'documentosextras',
        );
      }
      // The native save sheet owns its result. Cancellation is not a success.
    } catch (_) {
      if (mounted && generation == _generation)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos abrir o guardar el documento. Inténtalo nuevamente.',
            ),
          ),
        );
    } finally {
      if (mounted && generation == _generation)
        setState(() => _busy.remove(key));
    }
  }

  void _back() {
    final navigation = FamilyNavigationScope.maybeOf(context);
    if (navigation != null) {
      navigation.back();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        buildPapiRoute(TravelFatherDashboard(login: widget.login)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: PiloFamilyTheme.paper,
      endDrawer: AppDrawerFather(
        login: widget.login,
        imageFile: null,
        imageUrl: _imageUrl,
      ),
      body: SafeArea(bottom: false, child: _content()),
    ),
  );

  Widget _content() => FutureBuilder<List<Document>>(
    future: _documentsFuture,
    builder: (context, snapshot) {
      final loading = snapshot.connectionState == ConnectionState.waiting;
      final documents = snapshot.data ?? const <Document>[];
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: PageStorageKey('family-documents-${widget.login.tourId}'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            PiloSectionBar(
              title: 'Documentos',
              subtitle: 'Archivos de la gira',
              padding: const EdgeInsets.only(bottom: 16),
              onBack: _back,
              actions: [
                IconButton(
                  key: const ValueKey('documents-refresh'),
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
            if (loading)
              const LinearProgressIndicator(
                minHeight: 2,
                semanticsLabel: 'Cargando documentos',
              ),
            if (snapshot.hasError)
              DocumentListMessage(
                title: 'No pudimos cargar los documentos.',
                message: 'Vuelve a intentarlo.',
                onRetry: _refresh,
                large: true,
              )
            else if (!loading && documents.isEmpty)
              const DocumentListMessage(
                title: 'Aún no hay documentos',
                message: 'Los documentos de la gira aparecerán aquí.',
                large: true,
              ),
            for (final (index, document) in documents.indexed)
              _documentTile(document, index),
          ],
        ),
      );
    },
  );

  Widget _documentTile(Document document, int index) {
    final name = document.documentName?.trim() ?? '';
    final available = name.isNotEmpty;
    final actionKey = '${document.tourSalesUuid}-${document.documentName}';
    return PapiDocumentTile(
      key: ValueKey('public-$actionKey-${document.documentType}-$index'),
      title: available ? name : publicDocumentTitle(document.documentType),
      pilo: true,
      subtitle: available
          ? documentFormatLabel(document.documentName)
          : 'Archivo no disponible',
      busy: _busy.contains(actionKey),
      onView: available ? () => _action(document, true) : null,
      onSave: available ? () => _action(document, false) : null,
    );
  }
}
