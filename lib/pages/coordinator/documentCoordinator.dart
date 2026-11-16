import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../design/pilo_family_theme.dart';
import '../../navigation/family_navigation.dart';
import '../../documents/documents_ui.dart';
import 'package:papigiras_app/documents/internal_document_media.dart';
import 'package:papigiras_app/documents/internal_document_upload.dart';
import 'package:papigiras_app/documents/internal_documents_repository.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:papigiras_app/utils/page_navigation.dart';

class DocumentCoordScreen extends StatefulWidget {
  const DocumentCoordScreen({
    super.key,
    required this.login,
    this.provider,
    this.internalDocuments,
    this.media,
  });
  final TourSales login;
  final CoordinatorProviders? provider;
  final InternalDocumentsRepository? internalDocuments;
  final InternalDocumentMedia? media;

  @override
  State<DocumentCoordScreen> createState() => _DocumentCoordScreenState();
}

class _DocumentCoordScreenState extends State<DocumentCoordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late CoordinatorProviders _provider;
  late InternalDocumentsRepository _repository;
  late InternalDocumentMedia _media;
  List<Document>? _public;
  List<InternalTourDocument>? _internal;
  bool _publicLoading = false, _internalLoading = false;
  String? _publicError, _internalError;
  final _busy = <String>{};
  int _generation = 0;
  InternalDocumentCategory _category = InternalDocumentCategory.general;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  void _configure() {
    _provider = widget.provider ?? CoordinatorProviders();
    _repository = widget.internalDocuments ?? _provider;
    _media = widget.media ?? NativeInternalDocumentMedia();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant DocumentCoordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.login.tourSalesId != widget.login.tourSalesId ||
        oldWidget.provider != widget.provider ||
        oldWidget.internalDocuments != widget.internalDocuments) {
      ++_generation;
      if (oldWidget.provider == null) _provider.dispose();
      _public = null;
      _internal = null;
      _publicError = null;
      _internalError = null;
      _publicLoading = false;
      _internalLoading = false;
      _busy.clear();
      _category = InternalDocumentCategory.general;
      _configure();
    } else if (oldWidget.media != widget.media) {
      _media = widget.media ?? NativeInternalDocumentMedia();
    }
  }

  @override
  void dispose() {
    ++_generation;
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadPublic(), _loadInternal()]);
  }

  Future<void> _loadPublic() async {
    if (_publicLoading) return;
    final generation = _generation;
    setState(() => _publicLoading = true);
    try {
      final documents = await _provider.getDocument(
        widget.login.tourSalesId.toString(),
      );
      if (mounted && generation == _generation)
        setState(() {
          _public = documents;
          _publicError = null;
        });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(
          () => _publicError = 'No pudimos cargar los documentos de la gira.',
        );
    } finally {
      if (mounted && generation == _generation)
        setState(() => _publicLoading = false);
    }
  }

  Future<void> _loadInternal() async {
    if (_internalLoading) return;
    final generation = _generation;
    setState(() => _internalLoading = true);
    try {
      final documents = await _repository.listInternalDocuments(
        widget.login.tourSalesId,
      );
      if (mounted && generation == _generation)
        setState(() {
          _internal = documents;
          _internalError = null;
        });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(
          () => _internalError = 'No pudimos cargar los documentos internos.',
        );
    } finally {
      if (mounted && generation == _generation)
        setState(() => _internalLoading = false);
    }
  }

  Future<void> _add() async {
    final generation = _generation;
    final document = await Navigator.of(context).push<InternalTourDocument>(
      buildPapiRoute(
        InternalDocumentUploadScreen(
          tourId: widget.login.tourSalesId,
          repository: _repository,
          media: _media,
          initialCategory: _category,
        ),
      ),
    );
    if (!mounted || generation != _generation || document == null) return;
    setState(() => _category = document.category);
    await _loadInternal();
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Documento agregado.')));
  }

  Future<void> _action(String key, Future<void> Function() action) async {
    if (_busy.contains(key)) return;
    final generation = _generation;
    setState(() => _busy.add(key));
    try {
      await action();
    } on InternalDocumentValidationException catch (error) {
      if (mounted && generation == _generation)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
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

  Future<void> _readInternal(
    InternalTourDocument document, {
    required bool preview,
  }) {
    final generation = _generation;
    final tourId = widget.login.tourSalesId;
    return _action('internal-${document.id}', () async {
      final downloaded = await _repository.downloadInternalDocument(
        tourId: tourId,
        documentId: document.id,
      );
      if (!mounted || generation != _generation) return;
      if (preview) {
        await _media.preview(context, downloaded);
      } else {
        await _media.save(downloaded);
      }
    });
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      FamilyNavigationScope.maybeOf(context)?.back();
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      key: _scaffoldKey,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: _content(),
    ),
  );

  Widget _content() => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      key: PageStorageKey('coordinator-documents-${widget.login.tourSalesId}'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        PiloSectionBar(
          title: 'Documentos',
          subtitle: 'Archivos de la gira y de coordinación',
          compact: MediaQuery.sizeOf(context).height < 650,
          padding: EdgeInsets.zero,
          onBack: _back,
          actions: [
            IconButton(
              key: const ValueKey('documents-refresh'),
              tooltip: 'Actualizar documentos',
              onPressed: _publicLoading || _internalLoading ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Abrir menú',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
            IconButton.filled(
              key: const ValueKey('documents-add'),
              tooltip: 'Agregar documento',
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                backgroundColor: PiloFamilyTheme.mint,
                foregroundColor: PiloFamilyTheme.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sections(),
        const SizedBox(height: 24),
        if (_category == InternalDocumentCategory.general) ...[
          const DocumentSectionHeading('De la gira'),
          if (_publicLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              semanticsLabel: 'Cargando documentos de la gira',
            ),
          if (_publicError != null)
            DocumentListMessage(title: _publicError!, onRetry: _loadPublic),
          if (_public != null) ...[
            if (_public!.isEmpty && _publicError == null && !_publicLoading)
              const DocumentListMessage(
                title: 'Aún no hay documentos de la gira.',
              )
            else
              ..._public!.map(_publicRow),
          ],
          const SizedBox(height: 20),
        ],
        DocumentSectionHeading(
          _category == InternalDocumentCategory.general
              ? 'Internos'
              : 'Vouchers',
          private: true,
        ),
        if (_internalLoading)
          const LinearProgressIndicator(
            minHeight: 2,
            semanticsLabel: 'Cargando documentos internos',
          ),
        if (_internalError != null)
          DocumentListMessage(title: _internalError!, onRetry: _loadInternal),
        if (_internal != null) ...[
          if (!_internal!.any((doc) => doc.category == _category) &&
              _internalError == null &&
              !_internalLoading)
            DocumentListMessage(
              title: _category == InternalDocumentCategory.general
                  ? 'Aún no hay documentos internos.'
                  : 'Aún no hay vouchers.',
              message: 'Usa + para agregar un documento.',
            )
          else
            ..._internal!
                .where((doc) => doc.category == _category)
                .map(_internalRow),
        ],
      ],
    ),
  );

  Widget _sections() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        for (final category in InternalDocumentCategory.values)
          Expanded(
            child: Semantics(
              selected: _category == category,
              child: TextButton(
                key: ValueKey('documents-section-${category.wireValue}'),
                onPressed: () => setState(() => _category = category),
                style: TextButton.styleFrom(
                  foregroundColor: _category == category
                      ? PiloFamilyTheme.ink
                      : PiloFamilyTheme.secondary,
                  backgroundColor: _category == category
                      ? PiloFamilyTheme.mint
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
                child: Text(category.label, textAlign: TextAlign.center),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _publicRow(Document document) {
    final key = 'public-${document.tourSalesUuid}-${document.documentName}';
    final available = document.documentName?.trim().isNotEmpty == true;
    return PapiDocumentTile(
      key: ValueKey(key),
      pilo: true,
      title: available
          ? document.documentName!.trim()
          : publicDocumentTitle(document.documentType),
      subtitle: available
          ? documentFormatLabel(document.documentName)
          : 'Archivo no disponible',
      busy: _busy.contains(key),
      onView: !available
          ? null
          : () => _action(
              key,
              () => _provider.viewDocument(
                document.tourSalesUuid,
                document.documentName!,
                widget.login.tourSalesId.toString(),
                context,
                'documentosextras',
              ),
            ),
      onSave: !available
          ? null
          : () => _action(
              key,
              () => _provider.downloadDocument(
                document.tourSalesUuid,
                document.documentName!,
                widget.login.tourSalesId.toString(),
                'documentosextras',
              ),
            ),
    );
  }

  Widget _internalRow(InternalTourDocument document) {
    final date = document.createdAt?.toLocal();
    final dateLabel = date == null
        ? null
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final size = document.sizeBytes >= 1024 * 1024
        ? '${(document.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(document.sizeBytes / 1024).ceil()} KB';
    final activity = document.category == InternalDocumentCategory.voucher
        ? document.activityName
        : null;
    return PapiDocumentTile(
      key: ValueKey('internal-document-${document.id}'),
      pilo: true,
      title: document.name,
      subtitle: [
        if (activity?.trim().isNotEmpty == true) activity!,
        if (dateLabel != null) dateLabel,
        size,
      ].join(' · '),
      icon: document.contentType.startsWith('image/')
          ? CupertinoIcons.photo
          : CupertinoIcons.doc_text,
      busy: _busy.contains('internal-${document.id}'),
      onView: document.canPreview
          ? () => _readInternal(document, preview: true)
          : null,
      onSave: () => _readInternal(document, preview: false),
    );
  }
}
