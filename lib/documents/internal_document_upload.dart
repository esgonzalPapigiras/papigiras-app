import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';

import 'internal_document_media.dart';
import 'internal_documents_repository.dart';

class InternalDocumentUploadScreen extends StatefulWidget {
  const InternalDocumentUploadScreen({
    super.key,
    required this.tourId,
    required this.repository,
    required this.media,
    this.initialCategory = InternalDocumentCategory.general,
  });
  final int tourId;
  final InternalDocumentsRepository repository;
  final InternalDocumentMedia media;
  final InternalDocumentCategory initialCategory;

  @override
  State<InternalDocumentUploadScreen> createState() =>
      _InternalDocumentUploadScreenState();
}

class _InternalDocumentUploadScreenState
    extends State<InternalDocumentUploadScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late InternalDocumentCategory _category;
  InternalDocumentFile? _file;
  bool _picking = false;
  bool _uploading = false;
  double _progress = 0;
  String? _fileError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(InternalDocumentSource source) async {
    if (_picking || _uploading) return;
    setState(() {
      _picking = true;
      _fileError = null;
    });
    try {
      final file = await widget.media.pick(source);
      if (file == null || !mounted) return;
      validateInternalDocumentFile(file);
      setState(() => _file = file);
    } on InternalDocumentValidationException catch (error) {
      if (mounted) setState(() => _fileError = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _fileError =
              'No pudimos preparar el archivo. Inténtalo nuevamente.',
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _upload() async {
    if (_uploading || _picking) return;
    final valid = _form.currentState!.validate();
    setState(() {
      _fileError = _file == null ? 'Elige una foto o un archivo.' : null;
      _error = null;
    });
    if (!valid || _file == null) return;
    try {
      validateInternalDocumentFile(_file!);
    } on InternalDocumentValidationException catch (error) {
      setState(() => _fileError = error.message);
      return;
    }
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    try {
      final document = await widget.repository.uploadInternalDocument(
        tourId: widget.tourId,
        name: _name.text.trim(),
        category: _category,
        file: _file!,
        onProgress: (progress) {
          if (mounted && _uploading)
            setState(() => _progress = progress.clamp(0, 1));
        },
      );
      if (mounted) Navigator.of(context).pop(document);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'No pudimos agregar el documento. Tus datos siguen aquí para reintentar.',
        );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: PopScope(
      canPop: !_uploading,
      child: Scaffold(
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                PiloSectionBar(
                  title: 'Agregar documento',
                  subtitle: 'Solo coordinación y administración',
                  onBack: _uploading ? null : () => Navigator.maybePop(context),
                  compact: true,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<InternalDocumentCategory>(
                  key: const ValueKey('internal-upload-category'),
                  initialValue: _category,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Sección',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final category in InternalDocumentCategory.values)
                      DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                  ],
                  onChanged: _uploading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _category = value);
                        },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('internal-upload-name'),
                  controller: _name,
                  enabled: !_uploading,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del documento',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe un nombre para el documento.'
                      : value.trim().length > 120
                      ? 'Usa hasta 120 caracteres.'
                      : null,
                ),
                const SizedBox(height: 22),
                const Text(
                  'Archivo',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PiloFamilyTheme.ink,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _sourceButton(
                      InternalDocumentSource.camera,
                      Icons.camera_alt_outlined,
                      'Cámara',
                    ),
                    _sourceButton(
                      InternalDocumentSource.gallery,
                      Icons.photo_library_outlined,
                      'Galería',
                    ),
                    _sourceButton(
                      InternalDocumentSource.file,
                      Icons.attach_file,
                      'Archivos',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'PDF, Word, Excel o imágenes. Máximo 10 MB.',
                  style: TextStyle(
                    color: PiloFamilyTheme.secondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (_picking)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(
                      color: PiloFamilyTheme.accentText,
                    ),
                  ),
                if (_file != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file_outlined,
                          color: PiloFamilyTheme.accentText,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _file!.fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: PiloFamilyTheme.ink),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('internal-upload-remove'),
                          tooltip: 'Quitar archivo',
                          onPressed: _uploading
                              ? null
                              : () => setState(() => _file = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                if (_fileError != null)
                  Text(
                    _fileError!,
                    key: const ValueKey('internal-upload-file-error'),
                    style: const TextStyle(color: Colors.red, height: 1.4),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, height: 1.4),
                    ),
                  ),
                if (_uploading)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(
                          value: _progress,
                          color: PiloFamilyTheme.accentText,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _progress >= 1
                              ? 'Confirmando archivo…'
                              : '${(_progress * 100).floor()} % enviado',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('internal-upload-submit'),
                  onPressed: _uploading || _picking ? null : _upload,
                  style: FilledButton.styleFrom(
                    backgroundColor: PiloFamilyTheme.accentText,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 48),
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(_uploading ? 'Agregando…' : 'Agregar documento'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _sourceButton(
    InternalDocumentSource source,
    IconData icon,
    String label,
  ) => OutlinedButton.icon(
    key: ValueKey('internal-upload-${source.name}'),
    onPressed: _uploading || _picking ? null : () => _pick(source),
    style: OutlinedButton.styleFrom(
      foregroundColor: PiloFamilyTheme.accentText,
      minimumSize: const Size(44, 44),
    ),
    icon: Icon(icon, size: 20),
    label: Text(label),
  );
}
