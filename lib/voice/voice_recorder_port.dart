import 'package:flutter/foundation.dart';
import 'voice_note_draft.dart';

/// All native actions are initiated by the recording control, never on build.
abstract interface class VoiceRecorderPort {
  Future<bool> requestPermission();
  Future<void> start({
    required VoidCallback onLimitReached,
    required VoidCallback onInterrupted,
  });
  Future<VoiceNoteDraft?> stop();
  Future<void> cancel();
  Future<void> discard(VoiceNoteDraft draft);
  Future<void> dispose();
}
