import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:papigiras_app/lab/media.dart';

import 'voice_note_draft.dart';
import 'voice_recorder_port.dart';

/// Native microphone access is lazy and occurs only after an explicit tap.
/// The pinned iOS plugin converts to the requested PCM format; Android uses
/// an exact PCM AudioRecord configuration and fails if it is unsupported.
class LocalVoiceRecorder implements VoiceRecorderPort {
  AudioRecorder? _native;
  StreamSubscription<Uint8List>? _samples;
  StreamSubscription<RecordState>? _states;
  final VoicePcmBuffer _buffer = VoicePcmBuffer();
  final Set<String> _ownedDirectories = {};
  Future<VoiceNoteDraft?>? _finishing;
  Future<void>? _cancelling;
  bool _disposed = false;
  bool _active = false;
  int _generation = 0;

  AudioRecorder get _recorder => _native ??= AudioRecorder();

  @override
  Future<bool> requestPermission() async {
    if (_disposed) return false;
    return _recorder.hasPermission();
  }

  @override
  Future<void> start({
    required VoidCallback onLimitReached,
    required VoidCallback onInterrupted,
  }) async {
    await _cancelling;
    if (_disposed || _active || _finishing != null) {
      throw StateError('El grabador no está disponible.');
    }
    final generation = ++_generation;
    _buffer.clear();
    var limitReported = false;
    var interruptionReported = false;
    void interrupted() {
      if (_disposed ||
          generation != _generation ||
          !_active ||
          interruptionReported)
        return;
      interruptionReported = true;
      onInterrupted();
    }

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: VoicePcmBuffer.sampleRate,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      if (_disposed || generation != _generation) {
        await _recorder.cancel();
        throw StateError('La grabación fue cancelada.');
      }
      _active = true;
      _states = _recorder.onStateChanged().listen((state) {
        if (state == RecordState.pause || state == RecordState.stop)
          interrupted();
      }, onError: (_) => interrupted());
      _samples = stream.listen(
        (bytes) {
          if (_disposed || generation != _generation) return;
          _buffer.add(bytes);
          if (_buffer.isFull && !limitReported && _active) {
            limitReported = true;
            onLimitReached();
          }
        },
        onError: (_) => interrupted(),
        onDone: interrupted,
      );
    } catch (_) {
      _active = false;
      await _cleanupNative();
      rethrow;
    }
  }

  @override
  Future<VoiceNoteDraft?> stop() async {
    if (_finishing != null) return _finishing;
    if (!_active || _disposed) return null;
    _active = false;
    final generation = _generation;
    final future = _finish(generation);
    _finishing = future;
    try {
      return await future;
    } finally {
      if (identical(_finishing, future)) _finishing = null;
    }
  }

  Future<VoiceNoteDraft?> _finish(int generation) async {
    Directory? directory;
    try {
      await _recorder.stop();
      await _samples?.cancel();
      _samples = null;
      await _states?.cancel();
      _states = null;
      if (_disposed || generation != _generation) {
        _buffer.clear();
        return null;
      }
      final wav = _buffer.finish();
      final cache = await getTemporaryDirectory();
      directory = await cache.createTemp('papigiras-voice-');
      final file = File('${directory.path}/nota.wav');
      await file.writeAsBytes(wav.bytes, flush: true);
      if (_disposed || generation != _generation) {
        await directory.delete(recursive: true);
        return null;
      }
      _ownedDirectories.add(directory.path);
      return VoiceNoteDraft(
        file: XFile(file.path, mimeType: 'audio/wav'),
        duration: wav.duration,
        byteLength: wav.bytes.length,
      );
    } catch (_) {
      if (directory != null && await directory.exists())
        await directory.delete(recursive: true);
      await _cleanupNative();
      rethrow;
    }
  }

  Future<void> _cleanupNative() async {
    await _samples?.cancel();
    await _states?.cancel();
    _samples = null;
    _states = null;
    _buffer.clear();
    try {
      await _native?.cancel();
    } catch (_) {
      /* No raw native error payload. */
    }
  }

  @override
  Future<void> cancel() async {
    if (_cancelling != null) return _cancelling;
    _generation++;
    _active = false;
    final operation = _cancelCurrent();
    _cancelling = operation;
    try {
      await operation;
    } finally {
      if (identical(_cancelling, operation)) _cancelling = null;
    }
  }

  Future<void> _cancelCurrent() async {
    try {
      await _finishing;
    } catch (_) {
      /* Cleanup below. */
    }
    await _cleanupNative();
  }

  @override
  Future<void> discard(VoiceNoteDraft draft) async {
    final directory = File(draft.file.path).parent;
    if (!_ownedDirectories.remove(directory.path)) return;
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
    await _native?.dispose();
    _native = null;
    // Draft ownership belongs to the composing screen until it explicitly
    // discards it. Never remove a file while its caller may still upload it.
  }
}
