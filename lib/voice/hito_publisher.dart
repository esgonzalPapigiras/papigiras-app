import 'package:papigiras_app/lab/api_http.dart';
import 'package:flutter/foundation.dart';
import 'package:papigiras_app/dto/requestHito.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'hito_publish_progress.dart';
import 'voice_note_draft.dart';
export 'hito_publish_progress.dart';

/// One submission owns one created hito. Retrying voice never recreates it.
class HitoPublisher extends ChangeNotifier {
  HitoPublisher(this.provider);
  final CoordinatorProviders provider;
  bool busy = false;
  bool photosOutcomeUnknown = false;
  bool creationOutcomeUnknown = false;
  bool get requiresReview => photosOutcomeUnknown || creationOutcomeUnknown;
  int? createdHitoId;
  bool _photosComplete = false;
  bool _voiceComplete = false;
  bool completed = false;
  bool _disposed = false;
  HitoPublishProgress progress = const HitoPublishProgress('Preparando hito…');
  void _progress(HitoPublishProgress value) {
    progress = value;
    if (!_disposed) notifyListeners();
  }

  Future<void> publish({
    required RequestHito hito,
    required List<XFile> photos,
    VoiceNoteDraft? voice,
  }) async {
    if (busy || completed) return;
    if (requiresReview)
      throw StateError('Revisa las fotos del hito guardado en la bitácora.');
    if (voice != null &&
        (voice.duration <= Duration.zero ||
            voice.duration > const Duration(seconds: 60) ||
            voice.byteLength > 2097152)) {
      throw ArgumentError('La nota de voz debe durar hasta 60 segundos.');
    }
    busy = true;
    try {
      if (createdHitoId == null) {
        _progress(const HitoPublishProgress('Guardando hito…'));
        try {
          final saved = await provider.addHito(hito);
          if (saved.binnacleDetailId <= 0)
            throw StateError('No se confirmó el hito.');
          createdHitoId = saved.binnacleDetailId;
        } catch (error) {
          // A lost response is not proof that creation failed. Never resend it
          // automatically without a server-side idempotency contract.
          creationOutcomeUnknown =
              error is! LabApiException ||
              error.statusCode < 400 ||
              error.statusCode >= 500 ||
              error.statusCode == 408;
          rethrow;
        }
      }
      if (!_photosComplete && photos.isNotEmpty) {
        var sending = false;
        try {
          await provider.addHitoFoto(
            createdHitoId!,
            hito.idTour.toString(),
            photos,
            onProgress: (value) {
              if (value.fraction != null) sending = true;
              _progress(value);
            },
          );
          _photosComplete = true;
        } catch (error) {
          // An explicit authorization rejection occurs before photo handling.
          // Preserve the known hito ID and permit a later authenticated retry.
          final rejectedAuth =
              error is LabApiException &&
              (error.statusCode == 401 || error.statusCode == 403);
          photosOutcomeUnknown = sending && !rejectedAuth;
          rethrow;
        }
      } else {
        _photosComplete = true;
      }
      if (voice != null && !_voiceComplete) {
        await provider.addHitoVoice(
          createdHitoId!,
          hito.idTour,
          voice,
          onProgress: _progress,
        );
        _voiceComplete = true;
      }
      completed = true;
      _progress(const HitoPublishProgress('Hito publicado', fraction: 1));
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
