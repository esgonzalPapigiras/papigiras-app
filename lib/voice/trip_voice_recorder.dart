import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'local_voice_recorder.dart';
import 'trip_voice_player.dart';
import 'voice_note_draft.dart';
import 'voice_recorder_port.dart';

enum _RecordingPhase { idle, permission, starting, recording, stopping }

class TripVoiceRecorder extends StatefulWidget {
  const TripVoiceRecorder({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onRecordingChanged,
    this.enabled = true,
    this.compact = false,
    this.recorder,
    this.previewBuilder,
  });
  final VoiceNoteDraft? value;
  final ValueChanged<VoiceNoteDraft?> onChanged;
  final ValueChanged<bool> onRecordingChanged;
  final bool enabled;
  final bool compact;
  final VoiceRecorderPort? recorder;
  final Widget Function(VoiceNoteDraft)? previewBuilder;
  @override
  State<TripVoiceRecorder> createState() => _TripVoiceRecorderState();
}

class _TripVoiceRecorderState extends State<TripVoiceRecorder>
    with WidgetsBindingObserver {
  late final VoiceRecorderPort _recorder =
      widget.recorder ?? LocalVoiceRecorder();
  _RecordingPhase _phase = _RecordingPhase.idle;
  Timer? _timer;
  int _seconds = 0;
  int _generation = 0;
  String? _error;
  bool get _working => _phase != _RecordingPhase.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A system permission dialog can make the app inactive before recording.
    if (state != AppLifecycleState.resumed &&
        (_phase == _RecordingPhase.starting ||
            _phase == _RecordingPhase.recording)) {
      unawaited(
        _abort(
          'La grabación se detuvo al salir de la app. Puedes volver a grabarla.',
        ),
      );
    }
  }

  bool get _foreground {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  Future<void> _start() async {
    if (_working || !widget.enabled || widget.value != null) return;
    final generation = ++_generation;
    setState(() {
      _phase = _RecordingPhase.permission;
      _error = null;
      _seconds = 0;
    });
    widget.onRecordingChanged(true);
    try {
      final allowed = await _recorder.requestPermission();
      if (!mounted || generation != _generation) return;
      if (!allowed) {
        _finishIdle(
          'Permite el acceso al micrófono en Ajustes para grabar una nota de voz.',
        );
        return;
      }
      if (!_foreground || ModalRoute.of(context)?.isCurrent == false) {
        _finishIdle('Vuelve a tocar Grabar cuando estés en esta pantalla.');
        return;
      }
      setState(() => _phase = _RecordingPhase.starting);
      await _recorder.start(
        onLimitReached: () => unawaited(_stop()),
        onInterrupted: () => unawaited(
          _abort('La grabación se interrumpió. Vuelve a intentarlo.'),
        ),
      );
      if (!mounted || generation != _generation || !_foreground) {
        await _recorder.cancel();
        return;
      }
      if (_phase != _RecordingPhase.starting) return;
      setState(() => _phase = _RecordingPhase.recording);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _phase != _RecordingPhase.recording) {
          timer.cancel();
          return;
        }
        setState(() => _seconds = timer.tick.clamp(0, 60));
        if (timer.tick >= 60) unawaited(_stop());
      });
    } catch (_) {
      await _recorder.cancel();
      if (mounted && generation == _generation) {
        _finishIdle(
          'No pudimos iniciar la grabación. Revisa el micrófono y vuelve a intentarlo.',
        );
      }
    }
  }

  Future<void> _stop() async {
    if (_phase != _RecordingPhase.recording &&
        _phase != _RecordingPhase.starting)
      return;
    final generation = _generation;
    _timer?.cancel();
    setState(() => _phase = _RecordingPhase.stopping);
    try {
      final draft = await _recorder.stop();
      if (!mounted || generation != _generation) {
        if (draft != null) await _recorder.discard(draft);
        return;
      }
      if (draft == null) {
        _finishIdle('No se guardó la grabación. Vuelve a intentarlo.');
      } else {
        widget.onChanged(draft);
        _finishIdle(null);
      }
    } catch (_) {
      await _recorder.cancel();
      if (mounted && generation == _generation)
        _finishIdle('No pudimos guardar la nota. Vuelve a grabarla.');
    }
  }

  Future<void> _abort(String message) async {
    if (!_working || _phase == _RecordingPhase.stopping) return;
    ++_generation;
    _timer?.cancel();
    setState(() => _phase = _RecordingPhase.stopping);
    await _recorder.cancel();
    if (mounted) _finishIdle(message);
  }

  void _finishIdle(String? error) {
    setState(() {
      _phase = _RecordingPhase.idle;
      _error = error;
    });
    widget.onRecordingChanged(false);
  }

  Future<void> _discard() async {
    final value = widget.value;
    if (value == null || !widget.enabled || _working) return;
    widget.onChanged(null);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await _recorder.discard(value);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'No pudimos borrar el archivo temporal.');
    }
  }

  @override
  void dispose() {
    ++_generation;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_recorder.cancel());
    if (widget.recorder == null) unawaited(_recorder.dispose());
    // The composing screen owns value and deletes it only after upload/discard.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final recording = _phase == _RecordingPhase.recording;
    final compactIdle = widget.compact && value == null && !_working;
    final ink = widget.compact ? PiloFamilyTheme.ink : tripInk;
    final accent = widget.compact ? PiloFamilyTheme.accentText : tripTeal;
    final secondary = widget.compact ? PiloFamilyTheme.secondary : tripMuted;
    return Container(
      key: const ValueKey('hito-voice-recorder'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.compact ? PiloFamilyTheme.soft : tripPaper,
        border: widget.compact ? null : Border.all(color: tripLine),
        borderRadius: BorderRadius.circular(widget.compact ? 24 : 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compactIdle)
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 260 ||
                    MediaQuery.textScalerOf(context).scale(15) > 21;
                final heading = Row(
                  children: [
                    Icon(Icons.mic_none_rounded, color: accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Nota de voz',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                          Text(
                            'Hasta 1 min',
                            style: TextStyle(color: secondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final button = TextButton(
                  key: const ValueKey('voice-record'),
                  onPressed: widget.enabled ? _start : null,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    minimumSize: const Size(76, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: PiloFamilyTheme.paper,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Grabar'),
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: button),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 8),
                    button,
                  ],
                );
              },
            )
          else
            Row(
              children: [
                Icon(Icons.mic_none_rounded, color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nota de voz',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                ),
                if (value == null && !_working)
                  Text(
                    'Hasta 1 min',
                    style: TextStyle(color: secondary, fontSize: 12),
                  ),
                if (value != null)
                  IconButton(
                    key: const ValueKey('voice-discard'),
                    tooltip: 'Eliminar nota de voz',
                    onPressed: widget.enabled ? _discard : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
          if (value != null)
            widget.previewBuilder?.call(value) ??
                TripVoicePlayer(
                  loadFile: () async => File(value.file.path),
                  duration: value.duration,
                  deleteAfterUse: false,
                )
          else if (_working) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: false,
                    child: Text(
                      recording
                          ? '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}'
                          : _phase == _RecordingPhase.stopping
                          ? 'Guardando nota…'
                          : 'Preparando micrófono…',
                      style: TextStyle(
                        fontSize: 18,
                        color: ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                if (recording)
                  FilledButton.icon(
                    key: const ValueKey('voice-stop'),
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Detener'),
                  )
                else
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (recording) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _seconds / 60, color: accent),
            ],
          ] else if (!compactIdle)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('voice-record'),
                onPressed: widget.enabled ? _start : null,
                icon: const Icon(Icons.fiber_manual_record, size: 14),
                label: const Text('Grabar nota'),
                style: TextButton.styleFrom(
                  foregroundColor: tripTeal,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFF9D2525),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
