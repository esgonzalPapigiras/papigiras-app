import 'dart:async';
import 'package:flutter/material.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/lab/synthetic_location.dart';
import 'package:papigiras_app/utils/location_callback.dart';

/// Explicit opt-in to a fictional route while the LAB is in the foreground.
/// It never requests GPS or claims native background location.
class LocationService extends ChangeNotifier with WidgetsBindingObserver {
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

  LocationService({
    LabSyntheticLocation? source,
    this.heartbeatInterval = const Duration(minutes: 1),
  }) : source = source ?? LabSyntheticLocation.instance {
    final binding = WidgetsBinding.instance;
    _foregroundActive =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  bool get isTracking => _isTracking;
  bool get backgroundTrackingEnabled => false;
  bool get initialized => _initialized;
  bool get isChangingMode => _isChangingMode;
  String? get lastError => _lastError;
  int get pendingCount => _pendingCount;
  DateTime? get lastAttempt => _lastAttempt;

  /// A local view may react to our own switch, but must not override another
  /// tour, role or login. No device-GPS access is introduced by this signal.
  int? get activeTourId =>
      _initialized &&
          !_disposed &&
          _sessionGeneration == LabSession.generation &&
          _preferences?.getString('token') == _sessionToken &&
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
      _preferences?.getString('userRole') == 'coordinator' &&
      _preferences?.getBool(sharingPreferenceKey) == true;

  void _cancelHeartbeat() {
    _foregroundHeartbeatTimer?.cancel();
    _foregroundHeartbeatTimer = null;
  }

  Future<void> initializeForCoordinatorSession() async {
    if (_disposed) return;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    if (_isChangingMode) {
      await _modeFuture;
      return;
    }
    final enabled = prefs.getBool(sharingPreferenceKey) ?? false;
    if (_initialized &&
        _sessionGeneration == LabSession.generation &&
        _sessionToken == prefs.getString('token') &&
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
          await sendSyntheticPositionNow();
        }
      } catch (_) {
        if (_currentMode(revision)) {
          _isTracking = false;
          _cancelHeartbeat();
          _lastError =
              'No se pudo cambiar el envío de ubicación del LAB. Inténtalo nuevamente.';
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
            'Inicia sesión como coordinador para compartir una ubicación ficticia.';
      return;
    }
    await source.restore();
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
    _pendingCount = prefs.getStringList(pendingLocationsKey)?.length ?? 0;
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
      await source.advance(shouldAdvance: () => _canSend(revision));
      if (_canSend(revision)) await sendSyntheticPositionNow();
    } finally {
      _advancing = false;
    }
  }

  Future<void> selectSyntheticPoint(int index) async {
    // Explicit LAB preview selection remains available while sharing is off.
    await source.select(index);
    await sendSyntheticPositionNow();
  }

  Future<void> sendSyntheticPositionNow() async {
    final revision = _sendRevision;
    if (!_canSend(revision)) return;
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
    if (!_foregroundActive) {
      ++_sendRevision;
      _cancelHeartbeat();
      return;
    }
    if (!_initialized || !_isTracking || _disposed) return;
    _startForegroundHeartbeat();
    unawaited(sendSyntheticPositionNow());
  }

  @override
  void dispose() {
    _disposed = true;
    ++_modeRevision;
    ++_sendRevision;
    _isTracking = false;
    WidgetsBinding.instance.removeObserver(this);
    _cancelHeartbeat();
    super.dispose();
  }
}
