import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart' as native;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'offline.dart';
import 'session.dart';

export 'package:image_picker/image_picker.dart' show XFile, ImageSource;

/// Native pickers are opened only by a user's camera/gallery action.
class ImagePicker {
  final native.ImagePicker _picker = native.ImagePicker();

  Future<native.XFile?> pickImage({
    required native.ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      if (source == native.ImageSource.camera &&
          error.code == 'camera_unavailable') {
        labNotice(
          'La cámara no está disponible. Selecciona una imagen desde Galería.',
        );
        return null;
      }
      rethrow;
    }
  }

  Future<List<native.XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) => _picker.pickMultiImage(
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    imageQuality: imageQuality,
    requestFullMetadata: false,
  );
}

/// File-only native operations. This adapter never downloads or opens URLs.
class LabMedia {
  static void _requireCurrentExport(
    int generation,
    bool Function()? isCurrent,
  ) {
    if (generation != LabSession.generation ||
        (isCurrent != null && !isCurrent())) {
      throw StateError('La sesión o la vista del archivo cambió.');
    }
  }

  static String safePdfName(String name) {
    var leaf = name
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[^A-Za-zÀ-ÖØ-öø-ÿ0-9._ -]'), '_');
    if (leaf.isEmpty || leaf == '.' || leaf == '..') leaf = 'documento-lab';
    if (leaf.length > 100) leaf = leaf.substring(0, 100);
    if (!leaf.toLowerCase().endsWith('.pdf')) leaf += '.pdf';
    return leaf;
  }

  static void validatePdf(Uint8List bytes) {
    if (bytes.length < 5 ||
        bytes[0] != 37 ||
        bytes[1] != 80 ||
        bytes[2] != 68 ||
        bytes[3] != 70 ||
        bytes[4] != 45) {
      throw const FormatException('El servidor no devolvió un PDF válido.');
    }
  }

  static Future<Directory> documentDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/Papigiras LAB').create(recursive: true);
  }

  static Future<File> storePdf(Uint8List bytes, String name) async {
    validatePdf(bytes);
    final root = await getTemporaryDirectory();
    final directory = await Directory(
      '${root.path}/Papigiras LAB previews',
    ).create(recursive: true);
    return File(
      '${directory.path}/documento-${DateTime.now().microsecondsSinceEpoch}.pdf',
    ).writeAsBytes(bytes, flush: true);
  }

  static Future<void> removePreview(String path) async {
    final root = await getTemporaryDirectory();
    final file = File(path);
    if (file.parent.path != '${root.path}/Papigiras LAB previews') return;
    if (await file.exists()) await file.delete();
  }

  static Future<String?> exportPdf(
    Uint8List bytes,
    String name, {
    String dialogTitle = 'Guardar PDF de PapiGiras',
    bool Function()? isCurrent,
  }) async {
    validatePdf(bytes);
    _requireCurrentExport(LabSession.generation, isCurrent);
    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: safePdfName(name),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
  }

  static Rect _shareOrigin(BuildContext? context) {
    final object = context?.findRenderObject();
    if (object is RenderBox && object.hasSize) {
      return object.localToGlobal(Offset.zero) & object.size;
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    return Rect.fromLTWH(logical.width / 2, logical.height / 2, 1, 1);
  }

  static Future<ShareResult> sharePdf(
    File file, {
    BuildContext? context,
    bool Function()? isCurrent,
    String? name,
    String text = 'Documento de PapiGiras',
  }) async {
    final generation = LabSession.generation;
    final bytes = await file.readAsBytes();
    validatePdf(bytes);
    _requireCurrentExport(generation, isCurrent);
    Directory? exportDirectory;
    try {
      var sharedFile = file;
      if (name != null) {
        final root = await getTemporaryDirectory();
        final shares = await Directory(
          '${root.path}/Papigiras LAB shares',
        ).create(recursive: true);
        exportDirectory = await shares.createTemp('pdf-');
        sharedFile = await File(
          '${exportDirectory.path}/${safePdfName(name)}',
        ).writeAsBytes(bytes, flush: true);
      }
      _requireCurrentExport(generation, isCurrent);
      return await Share.shareXFiles(
        [XFile(sharedFile.path, mimeType: 'application/pdf')],
        text: text,
        sharePositionOrigin: _shareOrigin(context),
      );
    } finally {
      if (exportDirectory != null && await exportDirectory.exists()) {
        await exportDirectory.delete(recursive: true);
      }
    }
  }

  static Future<({Uint8List bytes, String extension, String mimeType})>
  _imageForExport(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        // The server's originals are JPEGs; historical PNGs are also retained.
        // Decode to validate them, but do not re-encode or reduce their quality.
        if (bytes.length >= 3 &&
            bytes[0] == 0xff &&
            bytes[1] == 0xd8 &&
            bytes[2] == 0xff) {
          return (bytes: bytes, extension: 'jpg', mimeType: 'image/jpeg');
        }
        if (bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4e &&
            bytes[3] == 0x47 &&
            bytes[4] == 0x0d &&
            bytes[5] == 0x0a &&
            bytes[6] == 0x1a &&
            bytes[7] == 0x0a) {
          return (bytes: bytes, extension: 'png', mimeType: 'image/png');
        }
        // Preserve the reference's PNG fallback for other decodable formats.
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null)
          throw const FormatException('No se pudo leer la imagen.');
        return (
          bytes: data.buffer.asUint8List(),
          extension: 'png',
          mimeType: 'image/png',
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  static Future<void> saveImage(
    Uint8List bytes, {
    bool Function()? isCurrent,
  }) async {
    final generation = LabSession.generation;
    final original = await _imageForExport(bytes);
    _requireCurrentExport(generation, isCurrent);
    await Gal.putImageBytes(
      original.bytes,
      name: 'PapiGiras_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  static Future<ShareResult> shareImage(
    Uint8List bytes,
    BuildContext context, {
    bool Function()? isCurrent,
  }) async {
    final generation = LabSession.generation;
    final original = await _imageForExport(bytes);
    _requireCurrentExport(generation, isCurrent);
    final root = await getTemporaryDirectory();
    final directory = await root.createTemp('papigiras-image-share-');
    try {
      final file = await File(
        '${directory.path}/PapiGiras.${original.extension}',
      ).writeAsBytes(original.bytes, flush: true);
      _requireCurrentExport(generation, isCurrent);
      if (!context.mounted) throw StateError('La vista del archivo se cerró.');
      return await Share.shareXFiles(
        [XFile(file.path, mimeType: original.mimeType)],
        text: 'Imagen de PapiGiras',
        sharePositionOrigin: _shareOrigin(context),
      );
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  static Future<Uint8List> compressForUpload(native.XFile file) async {
    final bytes = await file.readAsBytes();
    return FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1920,
      minHeight: 1920,
      quality: 80,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
  }
}
