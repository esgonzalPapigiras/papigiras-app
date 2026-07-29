import 'dart:async';

import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/settings/android_settings.dart';
import 'package:background_locator_2/settings/ios_settings.dart';
import 'package:background_locator_2/settings/locator_settings.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:papigiras_app/utils/location_callback.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService extends ChangeNotifier with WidgetsBindingObserver {
  static const _backgroundTrackingPreference = 'backgroundTrackingEnabled';

  bool _isTracking = false;
  bool _backgroundTrackingEnabled = false;
  bool _initialized = false;
  bool _isChangingMode = false;
  StreamSubscription<geo.Position>? _foregroundPositionSubscription;
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
    _backgroundTrackingEnabled =
        prefs.getBool(_backgroundTrackingPreference) ?? false;
    _isTracking = true;
    _initialized = true;
    notifyListeners();

    try {
      if (_backgroundTrackingEnabled) {
        final activated = await _activateBackgroundTracking();
        if (!activated) {
          _backgroundTrackingEnabled = false;
          await prefs.setBool(_backgroundTrackingPreference, false);
          await _activateForegroundTracking();
        }
      } else {
        await _activateForegroundTracking();
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

      if (!activated) {
        await _activateForegroundTracking();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundTrackingPreference, false);

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
    if (!await _ensureLocationPermission()) {
      return false;
    }

    await _stopForegroundTracking();

    if (await BackgroundLocator.isServiceRunning()) {
      return true;
    }

    await BackgroundLocator.registerLocationUpdate(
      locationCallback,
      iosSettings: const IOSSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        distanceFilter: 100,
      ),
      androidSettings: const AndroidSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        interval: 60,
        distanceFilter: 100,
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
      distanceFilter: 100,
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
    return true;
  }

  Future<bool> _ensureLocationPermission() async {
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

    _lastError = null;
    return true;
  }

  Future<void> _stopForegroundTracking() async {
    await _foregroundPositionSubscription?.cancel();
    _foregroundPositionSubscription = null;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_isChangingMode ||
        !_initialized ||
        !_isTracking ||
        _backgroundTrackingEnabled) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      await _stopForegroundTracking();
    }

    if (state == AppLifecycleState.resumed &&
        _foregroundPositionSubscription == null) {
      await _activateForegroundTracking();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopForegroundTracking());
    super.dispose();
  }
}
