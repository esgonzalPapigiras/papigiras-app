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
          'Este simulador no tiene cámara. Selecciona una imagen ficticia desde Galería.',
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
      throw const FormatException(
        'El servidor local no devolvió un PDF válido.',
      );
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
    String dialogTitle = 'Guardar PDF de Papigiras LAB',
  }) async {
    validatePdf(bytes);
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
    String text = 'Documento de Papigiras LAB',
  }) async {
    final bytes = await file.readAsBytes();
    validatePdf(bytes);
    if (isCurrent != null && !isCurrent()) {
      throw StateError('The PDF session is no longer current.');
    }
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
      if (isCurrent != null && !isCurrent()) {
        throw StateError('The PDF session is no longer current.');
      }
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

  static Future<Uint8List> _png(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null)
          throw const FormatException('No se pudo leer la imagen.');
        return data.buffer.asUint8List();
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  static Future<void> saveImage(Uint8List bytes) async {
    final png = await _png(bytes);
    await Gal.putImageBytes(
      png,
      name: 'Papigiras_LAB_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static Future<ShareResult> shareImage(
    Uint8List bytes,
    BuildContext context,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = await File(
      '${directory.path}/Papigiras_LAB_${DateTime.now().millisecondsSinceEpoch}.png',
    ).writeAsBytes(await _png(bytes), flush: true);
    return Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: 'Imagen de Papigiras LAB',
      sharePositionOrigin: _shareOrigin(context),
    );
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
