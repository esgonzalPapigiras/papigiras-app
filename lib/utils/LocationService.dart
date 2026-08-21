import 'dart:async';

import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/settings/android_settings.dart';
import 'package:background_locator_2/settings/ios_settings.dart';
import 'package:background_locator_2/settings/locator_settings.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:papigiras_app/utils/location_callback.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:shared_preferences/shared_preferences.dart';

class LocationService extends ChangeNotifier with WidgetsBindingObserver {
  static const _backgroundTrackingPreference = 'backgroundTrackingEnabled';
  static const _trackingModeConfiguredPreference =
      'coordinatorTrackingModeConfiguredV2';

  bool _isTracking = false;
  bool _backgroundTrackingEnabled = false;
  bool _initialized = false;
  bool _isChangingMode = false;
  StreamSubscription<geo.Position>? _foregroundPositionSubscription;
  Timer? _foregroundHeartbeatTimer;
  String? _lastError;

  bool get isTracking => _isTracking;
  bool get backgroundTrackingEnabled => _backgroundTrackingEnabled;
  bool get initialized => _initialized;
  bool get isChangingMode => _isChangingMode;
  String? get lastError => _lastError;

  LocationService() {
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> initializeForCoordinatorSession() async {
    if (_initialized || _isChangingMode) return;

    _isChangingMode = true;
    final prefs = await SharedPreferences.getInstance();
    final modeAlreadyConfigured =
        prefs.getBool(_trackingModeConfiguredPreference) ?? false;
    _backgroundTrackingEnabled = modeAlreadyConfigured
        ? prefs.getBool(_backgroundTrackingPreference) ?? true
        : true;
    await prefs.setBool(_trackingModeConfiguredPreference, true);
    await prefs.setBool(
        _backgroundTrackingPreference, _backgroundTrackingEnabled);
    _isTracking = true;
    _initialized = true;
    notifyListeners();

    try {
      if (_backgroundTrackingEnabled) {
        final activated = await _activateBackgroundTracking();
        if (!activated) {
          final backgroundError = _lastError;
          _backgroundTrackingEnabled = false;
          await prefs.setBool(_backgroundTrackingPreference, false);
          await _activateForegroundTracking();
          _lastError = backgroundError;
        }
      } else {
        await _activateForegroundTracking();
      }
    } catch (error) {
      _backgroundTrackingEnabled = false;
      await prefs.setBool(_backgroundTrackingPreference, false);
      _setModeError(error);
      final backgroundError = _lastError;
      try {
        await _activateForegroundTracking();
        _lastError = backgroundError;
      } catch (foregroundError) {
        _setModeError(foregroundError);
      }
    } finally {
      _isChangingMode = false;
      notifyListeners();
    }
  }

  Future<void> startTracking() async {
    if (_isChangingMode) return;
    _isChangingMode = true;
    final prefs = await SharedPreferences.getInstance();

    _isTracking = true;
    _backgroundTrackingEnabled = true;
    _initialized = true;
    _lastError = null;
    notifyListeners();

    try {
      final activated = await _activateBackgroundTracking();
      _backgroundTrackingEnabled = activated;
      await prefs.setBool(_backgroundTrackingPreference, activated);
      await prefs.setBool(_trackingModeConfiguredPreference, true);

      if (!activated) {
        final backgroundError = _lastError;
        await _activateForegroundTracking();
        _lastError = backgroundError;
      }
    } catch (error) {
      _backgroundTrackingEnabled = false;
      await prefs.setBool(_backgroundTrackingPreference, false);
      _setModeError(error);
    } finally {
      _isChangingMode = false;
      notifyListeners();
    }
  }

  Future<void> enableForegroundOnlyTracking() async {
    if (_isChangingMode) return;
    _isChangingMode = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundTrackingPreference, false);
    await prefs.setBool(_trackingModeConfiguredPreference, true);

    _isTracking = true;
    _backgroundTrackingEnabled = false;
    _initialized = true;
    _lastError = null;
    notifyListeners();

    try {
      await _activateForegroundTracking();
    } catch (error) {
      _setModeError(error);
    } finally {
      _isChangingMode = false;
      notifyListeners();
    }
  }

  /// Stops both modes. Coordinators should call this only when logging out.
  Future<void> stopTracking() async {
    if (_isChangingMode) return;
    _isChangingMode = true;
    _isTracking = false;
    _backgroundTrackingEnabled = false;
    _initialized = false;
    _lastError = null;
    notifyListeners();

    try {
      await _stopForegroundTracking();
      await _stopBackgroundTracking();
    } catch (error) {
      _setModeError(error);
    } finally {
      _isChangingMode = false;
      notifyListeners();
    }
  }

  Future<bool> _activateBackgroundTracking() async {
    if (!await _ensureLocationPermission(requireAlways: true)) {
      return false;
    }

    await _stopForegroundTracking();
    _startForegroundHeartbeat();

    if (await BackgroundLocator.isServiceRunning()) {
      await _sendCurrentPositionOnce();
      return true;
    }

    await BackgroundLocator.registerLocationUpdate(
      locationCallback,
      iosSettings: const IOSSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        distanceFilter: 25,
        showsBackgroundLocationIndicator: true,
      ),
      androidSettings: const AndroidSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        interval: 60,
        distanceFilter: 25,
        androidNotificationSettings: AndroidNotificationSettings(
          notificationChannelName: 'Location tracking',
          notificationTitle: 'Papigiras tracking activo',
          notificationMsg: 'Compartiendo ubicación en tiempo real',
          notificationBigMsg:
              'La app está enviando tu ubicación para el coordinador.',
          notificationIcon: '',
        ),
      ),
    );
    await _sendCurrentPositionOnce();
    return true;
  }

  Future<bool> _activateForegroundTracking() async {
    await _stopBackgroundTracking();
    await _stopForegroundTracking();

    if (!await _ensureLocationPermission()) {
      notifyListeners();
      return false;
    }

    const settings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.bestForNavigation,
      distanceFilter: 25,
    );
    _foregroundPositionSubscription =
        geo.Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        unawaited(
          sendCoordinatorLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        );
      },
      onError: (Object error) {
        _lastError = 'No se pudo obtener la ubicación: $error';
        debugPrint(_lastError);
        notifyListeners();
      },
    );
    _startForegroundHeartbeat();
    await _sendCurrentPositionOnce();
    return true;
  }

  Future<bool> _ensureLocationPermission({bool requireAlways = false}) async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      _lastError = 'Los servicios de ubicación están desactivados.';
      debugPrint(_lastError);
      return false;
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      _lastError = permission == geo.LocationPermission.deniedForever
          ? 'El permiso de ubicación está bloqueado. Habilítalo en Configuración.'
          : 'Se necesita permiso de ubicación para compartir la posición.';
      debugPrint(_lastError);
      return false;
    }

    if (requireAlways && permission != geo.LocationPermission.always) {
      final alwaysStatus =
          await permissions.Permission.locationAlways.request();
      permission = await geo.Geolocator.checkPermission();
      if (!alwaysStatus.isGranted ||
          permission != geo.LocationPermission.always) {
        _lastError =
            'Para compartir la ubicación con el teléfono bloqueado debes permitir acceso "Siempre" en Configuración. Se usará solo mientras la app esté abierta.';
        debugPrint(_lastError);
        return false;
      }
    }

    _lastError = null;
    return true;
  }

  Future<void> _stopForegroundTracking() async {
    await _foregroundPositionSubscription?.cancel();
    _foregroundPositionSubscription = null;
    _stopForegroundHeartbeat();
  }

  Future<void> _stopBackgroundTracking() async {
    if (await BackgroundLocator.isServiceRunning()) {
      await BackgroundLocator.unRegisterLocationUpdate();
    }
  }

  void _setModeError(Object error) {
    _lastError = 'No se pudo cambiar el modo de ubicación: $error';
    debugPrint(_lastError);
  }

  void _startForegroundHeartbeat() {
    _stopForegroundHeartbeat();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _foregroundHeartbeatTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_sendCurrentPositionOnce()),
    );
  }

  void _stopForegroundHeartbeat() {
    _foregroundHeartbeatTimer?.cancel();
    _foregroundHeartbeatTimer = null;
  }

  Future<void> _sendCurrentPositionOnce() async {
    if (!_isTracking) return;
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
        ),
      );
      await sendCoordinatorLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error) {
      _lastError = 'No se pudo obtener la ubicación actual: $error';
      debugPrint(_lastError);
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_isChangingMode || !_initialized || !_isTracking) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _stopForegroundHeartbeat();
      await _stopForegroundTracking();
    }

    if (state == AppLifecycleState.resumed) {
      if (_backgroundTrackingEnabled) {
        _startForegroundHeartbeat();
        await _sendCurrentPositionOnce();
      } else if (_foregroundPositionSubscription == null) {
        await _activateForegroundTracking();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopForegroundHeartbeat();
    unawaited(_stopForegroundTracking());
    super.dispose();
  }
}
