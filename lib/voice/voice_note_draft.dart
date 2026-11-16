import 'dart:typed_data';

import 'package:papigiras_app/lab/media.dart';

/// A recording owned by the composing screen, never a remote URL.
class VoiceNoteDraft {
  const VoiceNoteDraft({
    required this.file,
    required this.duration,
    required this.byteLength,
  });
  final XFile file;
  final Duration duration;
  final int byteLength;
}

/// Bounded PCM16 buffer. Canonical WAV output contains no device metadata.
class VoicePcmBuffer {
  static const sampleRate = 16000;
  static const bytesPerSecond = sampleRate * 2;
  static const maxSeconds = 60;
  static const maxPcmBytes = bytesPerSecond * maxSeconds;
  static const maxWavBytes = maxPcmBytes + 44;
  final BytesBuilder _bytes = BytesBuilder(copy: true);
  int _length = 0;
  int get length => _length;
  bool get isFull => _length == maxPcmBytes;

  void add(Uint8List chunk) {
    final remaining = maxPcmBytes - _length;
    if (remaining == 0) return;
    final count = chunk.length < remaining ? chunk.length : remaining;
    _bytes.add(Uint8List.sublistView(chunk, 0, count));
    _length += count;
  }

  void clear() {
    _bytes.clear();
    _length = 0;
  }

  VoiceWav finish() {
    final captured = _bytes.takeBytes();
    _length = 0;
    // PCM16 samples occupy exactly two bytes. Drop an incomplete final sample.
    final count = captured.length - captured.length % 2;
    if (count < bytesPerSecond ~/ 1000) {
      throw const FormatException(
        'La grabación fue muy corta. Inténtalo de nuevo.',
      );
    }
    final wav = Uint8List(44 + count);
    final header = ByteData.sublistView(wav);
    wav.setRange(0, 4, 'RIFF'.codeUnits);
    header.setUint32(4, count + 36, Endian.little);
    wav.setRange(8, 12, 'WAVE'.codeUnits);
    wav.setRange(12, 16, 'fmt '.codeUnits);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // Linear PCM.
    header.setUint16(22, 1, Endian.little); // Mono.
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, bytesPerSecond, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    wav.setRange(36, 40, 'data'.codeUnits);
    header.setUint32(40, count, Endian.little);
    wav.setRange(44, wav.length, captured);
    return VoiceWav(
      bytes: wav,
      duration: Duration(
        microseconds: count * Duration.microsecondsPerSecond ~/ bytesPerSecond,
      ),
    );
  }
}

class VoiceWav {
  const VoiceWav({required this.bytes, required this.duration});
  final Uint8List bytes;
  final Duration duration;
}
