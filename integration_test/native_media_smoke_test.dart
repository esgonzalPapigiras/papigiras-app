import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/utils/PDFViewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _pdf() {
  const content = 'BT /F1 16 Tf 25 200 Td (Papigiras LAB - PDF ficticio) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
  ];
  var result = '%PDF-1.4\n';
  final offsets = <int>[];
  for (var index = 0; index < objects.length; index++) {
    offsets.add(result.length);
    result += '${index + 1} 0 obj\n${objects[index]}\nendobj\n';
  }
  final start = result.length;
  result += 'xref\n0 6\n0000000000 65535 f \n';
  for (final offset in offsets) {
    result += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  result += 'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$start\n%%EOF\n';
  return Uint8List.fromList(ascii.encode(result));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = LabOfflineHttpOverrides();

  testWidgets('native LAB media: preferences, JPEG compression, Photos and PDF rendering', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('_lab_native_smoke', 'ficticio');
    await preferences.reload();
    expect(preferences.getString('_lab_native_smoke'), 'ficticio');
    await preferences.remove('_lab_native_smoke');

    final documents = await LabMedia.documentDirectory();
    expect(documents.path, contains('Papigiras LAB'));
    final sample = await rootBundle.load('assets/logo-papigiras.png');
    final bytes = sample.buffer.asUint8List();
    final imageFile = await File('${documents.path}/smoke-ficticio.png').writeAsBytes(bytes);
    final compressed = await LabMedia.compressForUpload(XFile(imageFile.path));
    expect(compressed.take(2).toList(), [0xff, 0xd8]);
    final codec = await ui.instantiateImageCodec(compressed);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(0));
    frame.image.dispose();
    codec.dispose();

    // At most one fictitious fixture is added to this LAB simulator across reruns.
    if (preferences.getBool('_lab_native_smoke_photo_saved') != true) {
      await LabMedia.saveImage(bytes);
      await preferences.setBool('_lab_native_smoke_photo_saved', true);
    }

    final pdf = await LabMedia.storePdf(_pdf(), 'smoke-ficticio.pdf');
    await tester.pumpWidget(MaterialApp(home: PDFViewer(filePath: pdf.path)));
    for (var attempt = 0; attempt < 100 && find.text('1 / 1').evaluate().isEmpty; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byTooltip('Guardar PDF'), findsOneWidget);
    expect(find.byTooltip('Compartir PDF'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await imageFile.delete();
    await pdf.delete();
  });
}
