import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/voice/voice_note_draft.dart';

void main() {
  test(
    'WAV canónico contiene PCM16 mono16k y duración calculada de las muestras',
    () {
      final pcm = Uint8List.fromList(
        List.generate(32000, (index) => index % 256),
      );
      final buffer = VoicePcmBuffer();
      buffer.add(Uint8List.sublistView(pcm, 0, 17));
      buffer.add(Uint8List.sublistView(pcm, 17));
      final result = buffer.finish();
      final bytes = result.bytes;
      final header = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
      expect(header.getUint32(4, Endian.little), bytes.length - 8);
      expect(header.getUint32(16, Endian.little), 16);
      expect(header.getUint16(20, Endian.little), 1);
      expect(header.getUint16(22, Endian.little), 1);
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint32(28, Endian.little), 32000);
      expect(header.getUint16(32, Endian.little), 2);
      expect(header.getUint16(34, Endian.little), 16);
      expect(header.getUint32(40, Endian.little), 32000);
      expect(bytes.sublist(44), pcm);
      expect(result.duration, const Duration(seconds: 1));
    },
  );

  test(
    'el límite de muestras impide más de60segundos aunque el timer llegue tarde',
    () {
      final buffer = VoicePcmBuffer();
      buffer.add(Uint8List(VoicePcmBuffer.maxPcmBytes - 1));
      expect(buffer.isFull, isFalse);
      buffer.add(Uint8List.fromList([7, 8, 9, 10]));
      buffer.add(Uint8List(32000));
      expect(buffer.isFull, isTrue);
      expect(buffer.length, 1920000);
      final result = buffer.finish();
      expect(result.bytes.length, 1920044);
      expect(result.bytes.last, 7);
      expect(result.duration, const Duration(seconds: 60));
    },
  );

  test(
    'fragmentos impares conservan muestras y sólo descartan el byte final incompleto',
    () {
      final buffer = VoicePcmBuffer();
      buffer.add(Uint8List(31));
      buffer.add(Uint8List.fromList([1, 2]));
      final result = buffer.finish();
      expect(result.bytes.length, 76);
      expect(result.bytes.last, 1);
      expect(result.duration, const Duration(milliseconds: 1));
    },
  );

  test(
    'cancelar limpia datos y una grabación vacía nunca se presenta como nota válida',
    () {
      final buffer = VoicePcmBuffer();
      buffer.add(Uint8List(32000));
      buffer.clear();
      expect(buffer.length, 0);
      expect(() => buffer.finish(), throwsFormatException);
      buffer.add(Uint8List(2));
      expect(() => buffer.finish(), throwsFormatException);
    },
  );

  test(
    'terminar libera el buffer y otra grabación no mezcla muestras anteriores',
    () {
      final buffer = VoicePcmBuffer();
      buffer.add(Uint8List.fromList(List.filled(32000, 9)));
      buffer.finish();
      expect(buffer.length, 0);
      buffer.add(Uint8List(32));
      expect(buffer.finish().bytes.sublist(44), everyElement(0));
    },
  );
}
