import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';

/// Native playback is deliberately limited to files supplied by the guarded
/// API downloader or the current recording. No URL is passed to the plugin.
abstract class VoicePlaybackPort {
  Stream<Duration> get position;
  Stream<bool> get playing;
  Future<void> play(File file);
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class LocalVoicePlayback implements VoicePlaybackPort {
  final AudioPlayer _player = AudioPlayer();
  @override
  Stream<Duration> get position => _player.onPositionChanged;
  @override
  Stream<bool> get playing =>
      _player.onPlayerStateChanged.map((state) => state == PlayerState.playing);
  @override
  Future<void> play(File file) => _player.play(DeviceFileSource(file.path));
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> dispose() => _player.dispose();
}

class TripVoicePlayer extends StatefulWidget {
  const TripVoicePlayer({
    super.key,
    required this.loadFile,
    required this.duration,
    this.deleteAfterUse = true,
    this.playerFactory,
  });
  final Future<File> Function() loadFile;
  final Duration duration;
  final bool deleteAfterUse;
  final VoicePlaybackPort Function()? playerFactory;
  @override
  State<TripVoicePlayer> createState() => _TripVoicePlayerState();
}

class _TripVoicePlayerState extends State<TripVoicePlayer>
    with WidgetsBindingObserver {
  static _TripVoicePlayerState? _active;
  VoicePlaybackPort? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  File? _file;
  Duration _position = Duration.zero;
  bool _playing = false, _loading = false, _error = false, _visible = true;
  int _generation = 0;
  Future<void>? _pausing;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (!visible && _visible) unawaited(_stop());
    _visible = visible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_stop());
      if (mounted) setState(() {});
    }
  }

  Future<void> _stop() {
    ++_generation;
    _loading = false;
    _playing = false;
    return _pausing ??= _pauseSafely().whenComplete(() => _pausing = null);
  }

  Future<void> _releasePlayer() async {
    final player = _player;
    _player = null;
    final positionSub = _positionSub;
    final playingSub = _playingSub;
    _positionSub = null;
    _playingSub = null;
    // Start native release immediately; event-channel cancellation may itself
    // wait for platform work and must not postpone stopping the sound.
    final pending = <Future<void>>[
      if (positionSub != null) positionSub.cancel(),
      if (playingSub != null) playingSub.cancel(),
      if (player != null) player.dispose(),
    ];
    try {
      await Future.wait(pending);
    } catch (_) {
      // Platform cleanup must not turn a navigation action into an exception.
    }
  }

  Future<void> _pauseSafely() async {
    final player = _player;
    if (player == null) return;
    try {
      await player.pause();
    } catch (_) {
      // A failed pause cannot leave a hidden or superseded player active.
      if (identical(player, _player)) await _releasePlayer();
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _remove(File? file, bool remove) async {
    if (!remove || file == null) return;
    try {
      // Only the downloader's own temporary directory is removed recursively.
      if (file.parent.path
          .split(Platform.pathSeparator)
          .last
          .startsWith('papigiras-voice-')) {
        if (await file.parent.exists())
          await file.parent.delete(recursive: true);
      } else if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      /* Temporary cleanup must not crash navigation. */
    }
  }

  Future<void> _toggle() async {
    if (_loading || _pausing != null) return;
    if (_playing) {
      await _stop();
      if (mounted) setState(() {});
      return;
    }
    final previous = _active;
    _active = this;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = false;
    });
    File? loaded;
    try {
      if (previous != null && previous != this) {
        await previous._stop();
        if (previous.mounted) previous.setState(() {});
      }
      if (!mounted || generation != _generation || !_visible) return;
      loaded = _file ?? await widget.loadFile();
      if (!mounted || generation != _generation || !_visible) {
        if (loaded != _file) await _remove(loaded, widget.deleteAfterUse);
        return;
      }
      _file = loaded;
      if (_player == null) {
        _player = widget.playerFactory?.call() ?? LocalVoicePlayback();
        _positionSub = _player!.position.listen(
          (value) {
            if (mounted) setState(() => _position = value);
          },
          onError: (Object _) {
            if (mounted) setState(() => _error = true);
          },
        );
        _playingSub = _player!.playing.listen(
          (value) {
            if (mounted)
              setState(() {
                _playing = value && _active == this && _visible;
                if (!value && _position >= widget.duration)
                  _position = Duration.zero;
              });
          },
          onError: (Object _) {
            if (mounted) setState(() => _error = true);
          },
        );
      }
      await _player!.play(loaded);
      if (_position > Duration.zero && _position < widget.duration)
        await _player!.seek(_position);
      if (!mounted || generation != _generation || !_visible) {
        await _player?.pause();
        return;
      }
      setState(() => _playing = true);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _error = true);
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  static String _time(Duration value) =>
      '${value.inSeconds ~/ 60}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final duration = widget.duration.inMilliseconds.clamp(1, 60000);
    return Semantics(
      container: true,
      label: 'Nota de voz, ${widget.duration.inSeconds} segundos',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F5F4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('voice-play'),
              tooltip: _error
                  ? 'Reintentar nota de voz'
                  : _playing
                  ? 'Pausar nota de voz'
                  : 'Escuchar nota de voz',
              onPressed: _loading ? null : _toggle,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: tripTeal,
                    ),
            ),
            Expanded(
              child: _error
                  ? const Text(
                      'No pudimos reproducirla. Reintenta.',
                      style: TextStyle(fontSize: 12, color: tripInk),
                    )
                  : SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                      ),
                      child: Slider(
                        label: 'Posición de la nota de voz',
                        min: 0,
                        max: duration.toDouble(),
                        value: _position.inMilliseconds
                            .clamp(0, duration)
                            .toDouble(),
                        activeColor: tripTeal,
                        onChanged: _file == null || _player == null || _loading
                            ? null
                            : (value) {
                                final target = Duration(
                                  milliseconds: value.round(),
                                );
                                setState(() => _position = target);
                                unawaited(
                                  _player!
                                      .seek(target)
                                      .catchError((Object _) {}),
                                );
                              },
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                _time(
                  _playing || _position > Duration.zero
                      ? _position
                      : widget.duration,
                ),
                style: const TextStyle(fontSize: 12, color: tripInk),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final stopped = _stop();
    if (_active == this) _active = null;
    final file = _file;
    final remove = widget.deleteAfterUse;
    unawaited(() async {
      await stopped;
      await _releasePlayer();
      await _remove(file, remove);
    }());
    super.dispose();
  }
}
