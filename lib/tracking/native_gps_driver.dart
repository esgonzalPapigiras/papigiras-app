import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';
import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/location_dto.dart';
import 'package:background_locator_2/settings/android_settings.dart';
import 'package:background_locator_2/settings/ios_settings.dart';
import 'package:background_locator_2/settings/locator_settings.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart' as permissions;
import '../lab/preferences.dart';
import '../runtime/api_destination.dart';
import '../utils/location_callback.dart';

String? _backgroundSession;

@pragma('vm:entry-point')
void initializeNativeTracking(Map<String, dynamic> data) {
  _backgroundSession = data['session'] as String?;
}

@pragma('vm:entry-point')
void nativeLocationCallback(LocationDto location) async {
  if (!AppEnvironment.connected || _backgroundSession == null) return;
  final expected = _backgroundSession!;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  if (prefs.getString(nativeTrackingSessionKey) != expected ||
      prefs.getString(pendingNativeClaimKey) == expected ||
      prefs.getBool('coordinatorLocationSharingEnabled') != true)
    return;
  Future<void> stopRejected() async {
    await prefs.reload();
    if (_backgroundSession != expected ||
        prefs.getString(nativeTrackingSessionKey) != expected ||
        rejectedLocationSession(prefs, expected) == null)
      return;
    try {
      await BackgroundLocator.unRegisterLocationUpdate();
    } catch (_) {
      // Some suspended engines cannot stop the native plugin until resume.
      // The nonce marker still prevents every further report.
    }
  }

  if (rejectedLocationSession(prefs, expected) != null) {
    await stopRejected();
    return;
  }
  try {
    await sendCoordinatorLocation(
      latitude: location.latitude,
      longitude: location.longitude,
      expectedTrackingSession: expected,
      queue: LocationQueue.background,
      recordedAt: location.time.isFinite && location.time > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              location.time.round(),
              isUtc: true,
            )
          : null,
    );
  } on LocationSendRejected {
    await stopRejected();
  }
}

abstract interface class NativeGpsDriver {
  bool get backgroundEnabled;
  String? get warning;
  Future<void> start({
    required String session,
    required bool Function() isCurrent,
    required void Function(double latitude, double longitude) onPosition,
    required void Function(String message) onError,
  });
  Future<(double, double)> currentPosition();
  Future<void> stop();
  void dispose();
}

/// Keeps the official native plugin, navigation accuracy, Android foreground
/// service and iOS background indicator, behind Pilo's explicit sharing switch.
class DeviceGpsDriver with WidgetsBindingObserver implements NativeGpsDriver {
  DeviceGpsDriver() {
    WidgetsBinding.instance.addObserver(this);
  }
  int _revision = 0;
  bool _background = false, _disposed = false;
  bool _askedForBackground = false;
  String? _warning;
  StreamSubscription<geo.Position>? _foreground;
  Timer? _health;
  Future<void> _nativeChanges = Future<void>.value();
  Future<void> Function()? _restart;
  void Function(String)? _onError;
  bool _checking = false;
  @override
  bool get backgroundEnabled => _background;
  @override
  String? get warning => _warning;

  Future<void> _serialize(Future<void> Function() action) {
    final operation = _nativeChanges.then((_) => action());
    _nativeChanges = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<void> start({
    required String session,
    required bool Function() isCurrent,
    required void Function(double, double) onPosition,
    required void Function(String) onError,
  }) async {
    final revision = ++_revision;
    bool current() => !_disposed && revision == _revision && isCurrent();
    _warning = null;
    _onError = onError;
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      throw StateError('Los servicios de ubicación están desactivados.');
    }
    if (!current()) return;
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied && current()) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (!current()) return;
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      throw StateError(
        'Habilita el permiso de ubicación en Configuración para compartir tu posición.',
      );
    }
    // Android can continue a user-started location foreground service with
    // precise while-in-use permission. iOS uses its existing Always flow.
    if (!Platform.isAndroid &&
        permission != geo.LocationPermission.always &&
        !_askedForBackground) {
      _askedForBackground = true;
      await permissions.Permission.locationAlways.request();
      if (!current()) return;
      permission = await geo.Geolocator.checkPermission();
    }
    if (!current()) return;
    final androidWhileVisible =
        Platform.isAndroid &&
        permission == geo.LocationPermission.whileInUse &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final background =
        permission == geo.LocationPermission.always || androidWhileVisible;
    _health?.cancel();
    await _foreground?.cancel();
    _foreground = null;
    _background = false;
    try {
      await _serialize(() async {
        if (!current()) return;
        await BackgroundLocator.initialize();
        if (!current()) return;
        if (await BackgroundLocator.isServiceRunning()) {
          await BackgroundLocator.unRegisterLocationUpdate();
        }
        if (!current()) return;
        if (background) {
          await BackgroundLocator.registerLocationUpdate(
            nativeLocationCallback,
            initCallback: initializeNativeTracking,
            initDataCallback: {'session': session},
            iosSettings: const IOSSettings(
              accuracy: LocationAccuracy.NAVIGATION,
              distanceFilter: 5,
              showsBackgroundLocationIndicator: true,
            ),
            androidSettings: const AndroidSettings(
              client: LocationClient.android,
              accuracy: LocationAccuracy.NAVIGATION,
              interval: 5,
              distanceFilter: 0,
              androidNotificationSettings: AndroidNotificationSettings(
                notificationChannelName: 'Location tracking',
                notificationTitle: 'Ubicación de la gira activa',
                notificationMsg: 'Compartiendo el recorrido con los apoderados',
                notificationBigMsg:
                    'Papigiras comparte el recorrido con los apoderados, incluso con la app cerrada.',
                notificationIcon: 'launcher_icon',
              ),
            ),
          );
          if (!current()) {
            await BackgroundLocator.unRegisterLocationUpdate();
            return;
          }
          _background = await BackgroundLocator.isServiceRunning();
        } else {
          _background = false;
        }
      });
    } catch (_) {
      if (!current()) return;
      _background = false;
      _warning = Platform.isAndroid
          ? 'Se comparte solo con la app abierta. Revisa que la ubicación precisa esté activa y vuelve a activar el envío desde la gira.'
          : 'No se pudo iniciar la ubicación en segundo plano. Se comparte mientras la app está abierta.';
      // A failed native registration must not leave a half-started service
      // competing with the foreground fallback.
      await _serialize(() async {
        if (!current()) return;
        try {
          await BackgroundLocator.unRegisterLocationUpdate();
        } catch (_) {}
      });
    }
    if (!current()) return;
    if (!_background) {
      _warning ??=
          'Se comparte solo mientras la app está abierta. Permite ubicación Siempre para compartir con el teléfono bloqueado.';
      _foreground =
          geo.Geolocator.getPositionStream(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
            ),
          ).listen(
            (position) {
              if (current() &&
                  (WidgetsBinding.instance.lifecycleState == null ||
                      WidgetsBinding.instance.lifecycleState ==
                          AppLifecycleState.resumed)) {
                onPosition(position.latitude, position.longitude);
              }
            },
            onError: (Object _) {
              if (current()) onError('No se pudo obtener la ubicación.');
            },
          );
    }
    _restart = () async {
      if (!current()) return;
      if (Platform.isAndroid && _background) {
        final running = await BackgroundLocator.isServiceRunning();
        if (!current() || running) return;
      }
      await start(
        session: session,
        isCurrent: isCurrent,
        onPosition: onPosition,
        onError: onError,
      );
    };
    _health = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!current() ||
          !_background ||
          _checking ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
        return;
      _checking = true;
      try {
        if (!await BackgroundLocator.isServiceRunning() && current())
          await _restart?.call();
      } catch (_) {
        if (current())
          onError('No se pudo reactivar la ubicación en segundo plano.');
      } finally {
        _checking = false;
      }
    });
  }

  @override
  Future<(double, double)> currentPosition() async {
    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return (position.latitude, position.longitude);
  }

  @override
  Future<void> stop() async {
    ++_revision;
    _background = false;
    _restart = null;
    _onError = null;
    _health?.cancel();
    await _foreground?.cancel();
    _foreground = null;
    await _serialize(() async {
      if (await BackgroundLocator.isServiceRunning())
        await BackgroundLocator.unRegisterLocationUpdate();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final restart = _restart;
      if (restart != null) {
        final revision = _revision;
        unawaited(
          restart().catchError((Object _) {
            if (!_disposed && _revision == revision + 1) {
              _onError?.call(
                'No se pudo reactivar la ubicación. Revisa los permisos.',
              );
            }
          }),
        );
      }
    } else {
      unawaited(_foreground?.cancel());
      _foreground = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(stop().catchError((Object _) {}));
  }
}
