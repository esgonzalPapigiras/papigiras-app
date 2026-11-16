import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/utils/PDFViewer.dart';
import 'package:papigiras_app/utils/page_navigation.dart';

import 'internal_documents_repository.dart';

enum InternalDocumentSource { camera, gallery, file }

abstract interface class InternalDocumentMedia {
  Future<InternalDocumentFile?> pick(InternalDocumentSource source);
  Future<void> preview(BuildContext context, InternalDocumentDownload file);
  Future<bool> save(InternalDocumentDownload file);
}

class NativeInternalDocumentMedia implements InternalDocumentMedia {
  final _picker = ImagePicker();

  @override
  Future<InternalDocumentFile?> pick(InternalDocumentSource source) async {
    XFile? chosen;
    var image = source != InternalDocumentSource.file;
    if (image) {
      chosen = await _picker.pickImage(
        source: source == InternalDocumentSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: internalDocumentExtensions,
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      final extension = (file.extension ?? '').toLowerCase();
      if (!internalDocumentExtensions.contains(extension)) {
        throw const InternalDocumentValidationException(
          'Elige un PDF, Word, Excel o una imagen JPG, PNG o WEBP.',
        );
      }
      image = const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension);
      if (!image && file.size > internalDocumentMaxBytes) {
        throw const InternalDocumentValidationException(
          'El archivo supera los 10 MB. Elige uno más pequeño.',
        );
      }
      chosen = file.xFile;
    }
    if (chosen == null) return null;
    final bytes = image
        ? await LabMedia.compressForUpload(chosen)
        : await chosen.readAsBytes();
    final name = image
        ? 'imagen.jpg'
        : chosen.name.split(RegExp(r'[/\\]')).last;
    final file = InternalDocumentFile(
      fileName: name,
      contentType: image
          ? 'image/jpeg'
          : internalDocumentMime(name.split('.').last),
      bytes: bytes,
    );
    validateInternalDocumentFile(file);
    return file;
  }

  @override
  Future<void> preview(
    BuildContext context,
    InternalDocumentDownload file,
  ) async {
    if (file.contentType == 'application/pdf') {
      final local = await LabMedia.storePdf(file.bytes, file.fileName);
      if (!context.mounted) {
        await LabMedia.removePreview(local.path);
        return;
      }
      try {
        await Navigator.of(
          context,
        ).push(buildPapiRoute<void>(PDFViewer(filePath: local.path)));
      } catch (_) {
        await LabMedia.removePreview(local.path);
        rethrow;
      }
      // PDFViewer owns normal cleanup when its route is disposed.
      return;
    }
    if (!const {
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(file.contentType)) {
      throw const InternalDocumentValidationException(
        'Guarda este archivo para abrirlo en una aplicación compatible.',
      );
    }
    await Navigator.of(context).push(
      buildPapiRoute<void>(
        Scaffold(
          backgroundColor: tripSurface,
          appBar: AppBar(
            backgroundColor: tripSurface,
            foregroundColor: tripInk,
            title: Text(
              file.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.memory(
                  file.bytes,
                  cacheWidth: 2048,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No pudimos abrir esta imagen.'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Future<bool> save(InternalDocumentDownload file) async {
    final name = file.fileName.split(RegExp(r'[/\\]')).last;
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar documento',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: [name.split('.').last.toLowerCase()],
      bytes: file.bytes,
    );
    return destination != null;
  }
}
