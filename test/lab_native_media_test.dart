import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QR accepts the original JSON envelope with a LAB passenger URI', () {
    expect(labPassengerIdFromQr(jsonEncode({'id': 20, 'url': 'papigiras-lab:passenger/42'})), '42');
    expect(labPassengerIdFromQr('papigiras-lab:passenger/7'), '7');
  });

  test('QR rejects external links, arbitrary IDs and malformed payloads', () {
    for (final payload in [
      '1', 'https://example.invalid/passenger/1',
      'papigiras-lab://passenger/1', 'papigiras-lab:passenger/0',
      'papigiras-lab:passenger/-1', 'papigiras-lab:passenger/1?x=2',
      'papigiras-lab:passenger/1#x', '{broken', '{"id":20}',
      '{"url":42}', 'papigiras-lab:passenger/1/extra',
    ]) {
      expect(labPassengerIdFromQr(payload), isNull, reason: payload);
    }
  });

  test('a real generated QR image decodes its passenger, without camera/network', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 320), Paint()..color = Colors.white);
    canvas.translate(20, 20);
    QrPainter(
      data: jsonEncode({'id': 20, 'url': 'papigiras-lab:passenger/42'}),
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
    ).paint(canvas, const Size(280, 280));
    final picture = recorder.endRecording();
    final image = await picture.toImage(320, 320);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(await decodeLabPassengerQrImage(bytes!.buffer.asUint8List()), '42');
    image.dispose();
    picture.dispose();
  });

  test('PDF names cannot escape the selected local document directory', () {
    expect(LabMedia.safePdfName('../../ficha.pdf'), 'ficha.pdf');
    expect(LabMedia.safePdfName(r'C:\\secret\\ficha.pdf'), 'ficha.pdf');
    expect(LabMedia.safePdfName(''), 'documento-lab.pdf');
    expect(LabMedia.safePdfName('ficha'), 'ficha.pdf');
  });

  test('server errors and non-PDF bodies cannot reach the native PDF renderer', () {
    expect(() => LabMedia.validatePdf(Uint8List.fromList(utf8.encode('{"error":"denied"}'))), throwsFormatException);
    expect(() => LabMedia.validatePdf(Uint8List(0)), throwsFormatException);
    expect(() => LabMedia.validatePdf(Uint8List.fromList(utf8.encode('%PDF-1.4\n'))), returnsNormally);
  });
}
