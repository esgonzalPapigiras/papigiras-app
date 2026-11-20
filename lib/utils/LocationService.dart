import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/lab/synthetic_location.dart';
import 'package:papigiras_app/utils/location_callback.dart';
import '../runtime/api_destination.dart';
import '../tracking/native_gps_driver.dart';

/// Explicit opt-in to native GPS in connected builds. The reference LAB keeps
/// its separate foreground-only synthetic source for deterministic tests.
class LocationService extends ChangeNotifier with WidgetsBindingObserver {
  static const _remoteStopWarning =
      'GPS apagado en este teléfono. No pudimos confirmar el apagado en el servidor; la última ubicación dejará de mostrarse activa al vencer su vigencia.';
  static const sharingPreferenceKey = 'coordinatorLocationSharingEnabled';
  bool _isTracking = false;
  bool _initialized = false;
  bool _isChangingMode = false;
  bool _disposed = false;
  bool _foregroundActive = true;
  bool _advancing = false;
  bool? _requestedMode;
  int _modeRevision = 0;
  int _sendRevision = 0;
  Future<void> _modeChain = Future<void>.value();
  Future<void>? _modeFuture;
  SharedPreferences? _preferences;
  String? _sessionToken;
  int? _sessionGeneration;
  Timer? _foregroundHeartbeatTimer;
  String? _lastError;
  int _pendingCount = 0;
  DateTime? _lastAttempt;
  CoordinatorLocationReceipt? _confirmedPosition;
  int? _confirmedModeRevision;
  final LabSyntheticLocation source;
  final Duration heartbeatInterval;
  NativeGpsDriver? _native;
  String? _nativeSession;
  int? _nativeTourId;
  RemoteLocationStop? _pendingRemoteStop;

  LocationService({
    LabSyntheticLocation? source,
    this.heartbeatInterval = const Duration(minutes: 1),
    NativeGpsDriver? nativeDriver,
  }) : source = source ?? LabSyntheticLocation.instance {
    final binding = WidgetsBinding.instance;
    _foregroundActive =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
    if (AppEnvironment.connected) _native = nativeDriver ?? DeviceGpsDriver();
  }

  bool get isTracking => _isTracking;
  bool get backgroundTrackingEnabled => _native?.backgroundEnabled ?? false;
  bool get initialized => _initialized;
  bool get isChangingMode => _isChangingMode;
  String? get lastError => _lastError;
  int get pendingCount => _pendingCount;
  DateTime? get lastAttempt => _lastAttempt;

  /// A local view may react to our own switch, but must not override another
  /// tour, role or login.
  int? get activeTourId =>
      _initialized &&
          !_disposed &&
          _sessionGeneration == LabSession.generation &&
          _preferences?.getString('token') == _sessionToken &&
          (_native == null ||
              _preferences?.getInt('selectedTourId') == _nativeTourId) &&
          _preferences?.getString('userRole') == 'coordinator'
      ? _preferences?.getInt('selectedTourId')
      : null;

  CoordinatorLocationReceipt? get confirmedPosition =>
      _isTracking &&
          _confirmedModeRevision == _modeRevision &&
          _confirmedPosition?.tourId == activeTourId
      ? _confirmedPosition
      : null;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  bool _currentMode(int revision) => !_disposed && revision == _modeRevision;

  bool _canSend(int revision) =>
      !_disposed &&
      _isTracking &&
      _foregroundActive &&
      revision == _sendRevision &&
      _sessionToken != null &&
      _sessionGeneration == LabSession.generation &&
      _preferences?.getString('token') == _sessionToken &&
      (_native == null ||
          _preferences?.getInt('selectedTourId') == _nativeTourId) &&
      _preferences?.getString('userRole') == 'coordinator' &&
      _preferences?.getBool(sharingPreferenceKey) == true;

  void _cancelHeartbeat() {
    _foregroundHeartbeatTimer?.cancel();
    _foregroundHeartbeatTimer = null;
  }

  Future<void> initializeForCoordinatorSession() async {
    if (_disposed) return;
    final prefs = await SharedPreferences.getInstance();
    if (_native != null) await prefs.reload();
    if (_disposed) return;
    if (_isChangingMode) {
      await _modeFuture;
      return;
    }
    final captured = captureRemoteLocationStop(prefs);
    final pendingStop =
        captured != null && prefs.containsKey(captured.storageKey);
    final enabled =
        !pendingStop && (prefs.getBool(sharingPreferenceKey) ?? false);
    final rejection = rejectedLocationSession(
      prefs,
      prefs.getString(nativeTrackingSessionKey),
    );
    if (_native != null && rejection != null) {
      await _stopRejectedSession(rejection);
      return;
    }
    if (_native != null) unawaited(_flushRemoteStop());
    if (_initialized &&
        _sessionGeneration == LabSession.generation &&
        _sessionToken == prefs.getString('token') &&
        (_native == null || _nativeTourId == prefs.getInt('selectedTourId')) &&
        prefs.getString('userRole') == 'coordinator' &&
        _isTracking == enabled)
      return;
    await _changeMode(enabled);
  }

  Future<void> setSharingEnabled(bool enabled) {
    if (_disposed) return Future<void>.value();
    if (_isChangingMode && _requestedMode == enabled) {
      return _modeFuture ?? Future<void>.value();
    }
    if (!_isChangingMode &&
        _initialized &&
        _sessionGeneration == LabSession.generation &&
        _isTracking == enabled &&
        (enabled || _pendingRemoteStop == null) &&
        _preferences?.getString('token') == _sessionToken &&
        _preferences?.getString('userRole') == 'coordinator') {
      return Future<void>.value();
    }
    return _changeMode(enabled);
  }

  Future<void> _changeMode(bool enabled) {
    final revision = ++_modeRevision;
    final sessionGeneration = LabSession.generation;
    ++_sendRevision;
    _requestedMode = enabled;
    _isChangingMode = true;
    _lastError = null;
    // Stop synchronously; an HTTP request already accepted cannot be recalled.
    if (!enabled) {
      _isTracking = false;
      _nativeSession = null;
      _cancelHeartbeat();
    }
    final setup = _modeChain.then(
      (_) => _applyMode(enabled, revision, sessionGeneration),
    );
    // Serialize preference writes, not HTTP. OFF can persist while an earlier
    // ON request is still in flight, and its revoked callback stops queue flush.
    _modeChain = setup.catchError((Object _) {});
    final operation = () async {
      try {
        await setup;
        if (_currentMode(revision)) {
          // The choice is saved. Keep the control available while the network
          // request is pending so the user can still turn sharing off.
          _isChangingMode = false;
          _requestedMode = null;
          _changed();
        }
        if (_currentMode(revision) && enabled && _isTracking) {
          if (_native != null) {
            final session = _nativeSession!;
            await _native!.start(
              session: session,
              isCurrent: () =>
                  _currentMode(revision) &&
                  _isTracking &&
                  _nativeSession == session &&
                  _preferences?.getInt('selectedTourId') == _nativeTourId &&
                  _sessionGeneration == LabSession.generation,
              onPosition: (lat, lon) =>
                  unawaited(_sendNativePosition(lat, lon)),
              onError: (message) {
                if (_currentMode(revision)) {
                  _lastError = message;
                  _changed();
                }
              },
            );
            if (!_currentMode(revision)) return;
            await _preferences?.setBool(
              'backgroundTrackingEnabled',
              backgroundTrackingEnabled,
            );
            _lastError = _native!.warning;
          }
          await sendSyntheticPositionNow();
        } else if (_currentMode(revision) && !enabled && _native != null) {
          await _native!.stop();
          await _flushRemoteStop();
        }
      } catch (error) {
        if (_currentMode(revision)) {
          _isTracking = false;
          _cancelHeartbeat();
          _lastError = _native == null
              ? 'No se pudo cambiar el envío de ubicación del LAB. Inténtalo nuevamente.'
              : error is StateError
              ? error.message.toString()
              : 'No se pudo activar la ubicación. Revisa los permisos e inténtalo nuevamente.';
          if (_native != null) {
            final stop = _preferences == null
                ? null
                : captureRemoteLocationStop(_preferences!);
            _nativeSession = null;
            await _preferences?.setBool(sharingPreferenceKey, false);
            await _preferences?.remove(nativeTrackingSessionKey);
            await _native!.stop();
            if (stop != null) {
              _pendingRemoteStop = stop;
              await _flushRemoteStop();
            }
          }
        }
      } finally {
        if (_currentMode(revision)) {
          _isChangingMode = false;
          _requestedMode = null;
          _changed();
        }
      }
    }();
    _modeFuture = operation;
    _changed();
    return operation;
  }

  Future<void> _applyMode(
    bool enabled,
    int revision,
    int sessionGeneration,
  ) async {
    if (!_currentMode(revision)) return;
    final prefs = await SharedPreferences.getInstance();
    if (!_currentMode(revision)) return;
    _preferences = prefs;
    final token = prefs.getString('token');
    if (sessionGeneration != LabSession.generation ||
        prefs.getString('userRole') != 'coordinator' ||
        token == null ||
        token.isEmpty) {
      _isTracking = false;
      _initialized = false;
      _sessionToken = null;
      _cancelHeartbeat();
      if (enabled)
        _lastError =
            'Inicia sesión como coordinador para compartir tu ubicación.';
      return;
    }
    if (_native == null) await source.restore();
    if (!_currentMode(revision)) return;
    // A logout/new role during restore must not recreate its cleared choice.
    if (sessionGeneration != LabSession.generation ||
        prefs.getString('token') != token ||
        prefs.getString('userRole') != 'coordinator') {
      _isTracking = false;
      _initialized = false;
      _cancelHeartbeat();
      return;
    }
    await prefs.setBool(sharingPreferenceKey, enabled);
    if (_native != null) {
      final previous = captureRemoteLocationStop(prefs);
      if (previous != null) {
        await rememberRemoteLocationStop(previous);
        _pendingRemoteStop = previous;
        // A delayed OFF is bound to the old nonce and cannot stop a newer ON.
        if (enabled) unawaited(_flushRemoteStop());
      }
      if (enabled) {
        _nativeTourId = prefs.getInt('selectedTourId');
        if (_nativeTourId == null)
          throw StateError('Selecciona una gira antes de compartir ubicación.');
        _nativeSession =
            '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
        await prefs.setString(nativeTrackingSessionKey, _nativeSession!);
        await prefs.setInt(nativeTrackingTourKey, _nativeTourId!);
      } else {
        await prefs.remove(nativeTrackingSessionKey);
        await prefs.remove(nativeTrackingTourKey);
      }
    }
    await prefs.setBool('backgroundTrackingEnabled', false);
    if (!_currentMode(revision)) return;
    if (sessionGeneration != LabSession.generation ||
        prefs.getString('token') != token ||
        prefs.getString('userRole') != 'coordinator') {
      _isTracking = false;
      _initialized = false;
      _cancelHeartbeat();
      return;
    }
    _sessionToken = token;
    _sessionGeneration = sessionGeneration;
    _initialized = true;
    _isTracking = enabled;
    _pendingCount = _queuedCount(prefs);
    if (enabled) {
      _startForegroundHeartbeat();
    } else {
      _cancelHeartbeat();
    }
    _changed();
  }

  Future<void> startTracking() => setSharingEnabled(true);
  Future<void> enableForegroundOnlyTracking() => setSharingEnabled(true);
  Future<void> stopTracking() => setSharingEnabled(false);

  Future<void> _flushRemoteStop() async {
    final target = _pendingRemoteStop;
    final confirmed = target == null || await stopRemoteLocationSharing(target);
    if (_disposed || !identical(target, _pendingRemoteStop)) return;
    if (confirmed) _pendingRemoteStop = null;
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    final recovered = confirmed && await retryPendingLocationStops(prefs);
    if (_disposed) return;
    if (recovered && _pendingRemoteStop == null) {
      if (_lastError == _remoteStopWarning) _lastError = null;
    } else if (!_isTracking) {
      _lastError ??= _remoteStopWarning;
    }
    _changed();
  }

  int _queuedCount(SharedPreferences? prefs) =>
      (prefs?.getStringList(pendingLocationsKey)?.length ?? 0) +
      (AppEnvironment.connected
          ? prefs?.getStringList(pendingBackgroundLocationsKey)?.length ?? 0
          : 0);

  void _startForegroundHeartbeat() {
    _cancelHeartbeat();
    if (!_canSend(_sendRevision)) return;
    _foregroundHeartbeatTimer = Timer.periodic(
      heartbeatInterval,
      (_) => unawaited(advanceSyntheticRoute()),
    );
  }

  Future<void> advanceSyntheticRoute() async {
    final revision = _sendRevision;
    if (!_canSend(revision) || _advancing) return;
    _advancing = true;
    try {
      if (_native != null) {
        await sendSyntheticPositionNow();
        return;
      }
      await source.advance(shouldAdvance: () => _canSend(revision));
      if (_canSend(revision)) await sendSyntheticPositionNow();
    } finally {
      _advancing = false;
    }
  }

  Future<void> selectSyntheticPoint(int index) async {
    if (_native != null)
      return; // LAB controls must never change real coordinates.
    // Explicit LAB preview selection remains available while sharing is off.
    await source.select(index);
    await sendSyntheticPositionNow();
  }

  Future<void> sendSyntheticPositionNow() async {
    final revision = _sendRevision;
    if (!_canSend(revision)) return;
    if (_native != null) {
      try {
        final point = await _native!.currentPosition();
        if (_canSend(revision)) await _sendNativePosition(point.$1, point.$2);
      } catch (_) {
        if (_canSend(revision)) {
          _lastError = 'No se pudo obtener la ubicación actual.';
          _changed();
        }
      }
      return;
    }
    try {
      final point = source.current;
      final receipt = await sendCoordinatorLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        canSend: () => _canSend(revision),
      );
      if (_disposed ||
          _sessionGeneration != LabSession.generation ||
          _preferences?.getString('token') != _sessionToken)
        return;
      _pendingCount =
          _preferences?.getStringList(pendingLocationsKey)?.length ?? 0;
      if (!_canSend(revision)) {
        _changed();
        return;
      }
      _lastAttempt = DateTime.now();
      if (receipt != null && receipt.tourId == activeTourId) {
        _confirmedPosition = receipt;
        _confirmedModeRevision = _modeRevision;
      }
      _lastError = _pendingCount > 0
          ? 'Servidor LAB sin conexión: $_pendingCount posiciones ficticias pendientes de reintento.'
          : null;
    } catch (_) {
      if (!_canSend(revision)) return;
      _lastError =
          'No se pudo registrar la posición ficticia. Inténtalo nuevamente.';
    }
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foregroundActive = state == AppLifecycleState.resumed;
    if (_foregroundActive && _native != null) unawaited(_flushRemoteStop());
    if (!_foregroundActive) {
      ++_sendRevision;
      _cancelHeartbeat();
      return;
    }
    if (_native != null && _initialized && !_disposed) {
      unawaited(_resumeNativeSharing());
      return;
    }
    if (!_initialized || !_isTracking || _disposed) return;
    _startForegroundHeartbeat();
    unawaited(sendSyntheticPositionNow());
  }

  Future<void> _sendNativePosition(double latitude, double longitude) async {
    final revision = _sendRevision;
    final session = _nativeSession;
    if (!_canSend(revision) || session == null) return;
    CoordinatorLocationReceipt? receipt;
    try {
      receipt = await sendCoordinatorLocation(
        latitude: latitude,
        longitude: longitude,
        expectedTrackingSession: session,
        canSend: () => _canSend(revision) && _nativeSession == session,
      );
    } on LocationSendRejected catch (error) {
      if (_nativeSession == session &&
          _sessionGeneration == LabSession.generation &&
          _preferences?.getString('token') == _sessionToken) {
        await _stopRejectedSession(error);
      }
      return;
    }
    if (!_canSend(revision) || _nativeSession != session) return;
    _lastAttempt = DateTime.now();
    _pendingCount = _queuedCount(_preferences);
    if (receipt != null && receipt.tourId == activeTourId) {
      _confirmedPosition = receipt;
      _confirmedModeRevision = _modeRevision;
    }
    _lastError = _pendingCount > 0
        ? 'Sin conexión: $_pendingCount posiciones pendientes de envío.'
        : _native?.warning;
    _changed();
  }

  Future<void> _stopRejectedSession(LocationSendRejected rejection) async {
    final stopping = _changeMode(false);
    final revision = _modeRevision;
    await stopping;
    if (_currentMode(revision)) {
      _lastError = rejection.message;
      _changed();
    }
  }

  Future<void> _resumeNativeSharing() async {
    final prefs = _preferences;
    if (prefs == null) return;
    await prefs.reload();
    if (_disposed ||
        _sessionGeneration != LabSession.generation ||
        prefs.getString('token') != _sessionToken)
      return;
    final rejection = rejectedLocationSession(prefs, _nativeSession);
    if (rejection != null) {
      await _stopRejectedSession(rejection);
      return;
    }
    if (!_isTracking) return;
    _startForegroundHeartbeat();
    await sendSyntheticPositionNow();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_modeRevision;
    ++_sendRevision;
    _isTracking = false;
    WidgetsBinding.instance.removeObserver(this);
    _cancelHeartbeat();
    _native?.dispose();
    super.dispose();
  }
}
