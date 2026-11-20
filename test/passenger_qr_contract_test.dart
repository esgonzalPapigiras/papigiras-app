import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/runtime/api_destination.dart';
import 'package:papigiras_app/runtime/passenger_qr.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final official = PassengerQrCodec(
    destination: ApiDestination('https://api.example.test'),
  );
  const lab = PassengerQrCodec(destination: null);
  const path = PassengerQrCodec.informationPath;

  test(
    'official QR preserves envelope and passenger identity without secrets',
    () {
      final data = official.encode(42);
      expect(jsonDecode(data), {
        'id': 20,
        'url': 'https://api.example.test$path?tourPassenger=42',
      });
      expect(official.decode(data), '42');
      expect(
        official.decode(
          'https://${PassengerQrCodec.legacyHost}$path?tourPassenger=42',
        ),
        '42',
      );
      expect(() => official.encode(0), throwsArgumentError);
    },
  );

  test('connected and LAB formats remain separated', () {
    expect(lab.decode(lab.encode(42)), '42');
    expect(official.decode(lab.encode(42)), isNull);
    expect(lab.decode(official.encode(42)), isNull);
  });

  test(
    'rejects foreign, ambiguous, malformed or credential-bearing QR URLs',
    () {
      for (final value in [
        '42',
        '{broken',
        '{"url":42}',
        'https://foreign.example$path?tourPassenger=42',
        'https://api.example.test.evil.test$path?tourPassenger=42',
        'http://api.example.test$path?tourPassenger=42',
        'https://api.example.test:8443$path?tourPassenger=42',
        'https://user@api.example.test$path?tourPassenger=42',
        'https://api.example.test/other?tourPassenger=42',
        'https://api.example.test$path?tourPassenger=42#fragment',
        'https://api.example.test$path?tourPassenger=42&tourPassenger=43',
        'https://api.example.test$path?tourPassenger=42&token=anything',
        'https://api.example.test$path?tourPassenger=-1',
        'https://api.example.test$path?tourPassenger=0',
        'https://api.example.test$path?tourPassenger=1.0',
        'https://api.example.test$path?tourPassenger=',
        'x' * 2049,
      ]) {
        expect(official.decode(value), isNull, reason: value);
      }
    },
  );

  test(
    'the actual connected student QR decodes from PNG without network',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 400, 400),
        Paint()..color = Colors.white,
      );
      canvas.translate(20, 20);
      QrPainter(
        data: passengerQrCodec.encode(42),
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ).paint(canvas, const Size(360, 360));
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 400);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(await decodePassengerQrImage(bytes!.buffer.asUint8List()), '42');
      } finally {
        image.dispose();
        picture.dispose();
      }
    },
    skip: !AppEnvironment.connected,
  );
}
