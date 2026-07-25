import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/settings/locator_settings.dart';
import 'package:papigiras_app/utils/location_callback.dart';
import 'package:background_locator_2/settings/android_settings.dart';
import 'package:background_locator_2/settings/ios_settings.dart';

class LocationService extends ChangeNotifier with WidgetsBindingObserver {
  bool _isTracking = true;
  bool _backgroundTrackingEnabled = true;
  bool _initialized = false;
  var urlDynamic = 'stingray-app-9tqd9-djh6d.ondigitalocean.app';
  bool get isTracking => _isTracking;
  bool get backgroundTrackingEnabled => _backgroundTrackingEnabled;
  bool get initialized => _initialized;

  LocationService() {
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> initializeForCoordinatorSession() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _backgroundTrackingEnabled = prefs.getBool('backgroundTrackingEnabled') ?? true;
    _isTracking = true;
    _initialized = true;
    notifyListeners();
    await _registerLocator();
  }

  Future<void> startTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backgroundTrackingEnabled', true);
    _isTracking = true;
    _backgroundTrackingEnabled = true;
    _initialized = true;
    notifyListeners();
    await _registerLocator();
  }

  Future<void> stopTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backgroundTrackingEnabled', false);
    _isTracking = false;
    _backgroundTrackingEnabled = false;
    _initialized = false;
    notifyListeners();
    await BackgroundLocator.unRegisterLocationUpdate();
  }

  Future<void> enableForegroundOnlyTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backgroundTrackingEnabled', false);
    _isTracking = true;
    _backgroundTrackingEnabled = false;
    _initialized = true;
    notifyListeners();
    await _registerLocator();
  }

  Future<void> _registerLocator() async {
    await BackgroundLocator.registerLocationUpdate(
      locationCallback,
      iosSettings: IOSSettings(accuracy: LocationAccuracy.NAVIGATION, distanceFilter: 100),
      androidSettings: AndroidSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        interval: 60,
        distanceFilter: 100,
        androidNotificationSettings: AndroidNotificationSettings(
          notificationChannelName: 'Location tracking',
          notificationTitle: 'Papigiras tracking activo',
          notificationMsg: 'Compartiendo ubicación en tiempo real',
          notificationBigMsg: 'La app está enviando tu ubicación para el coordinador.',
          notificationIcon: '',
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!_isTracking) return;
    if (_backgroundTrackingEnabled) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      await BackgroundLocator.unRegisterLocationUpdate();
    }
    if (state == AppLifecycleState.resumed) {
      await _registerLocator();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
