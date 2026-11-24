import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../dto/coordinator_session.dart';
import '../dto/TourSales.dart';
import '../dto/responseAttorney.dart';
import 'preferences.dart';
import '../utils/fcm_utils.dart';
import '../runtime/api_destination.dart';
import '../utils/location_callback.dart'
    show
        captureRemoteLocationStop,
        rememberRemoteLocationStop,
        stopRemoteLocationSharing;

abstract final class LabSession {
  static const revision = String.fromEnvironment('PAPIGIRAS_API_URL') != ''
      ? 'connected-v1:' + String.fromEnvironment('PAPIGIRAS_API_URL')
      : String.fromEnvironment('PAPIGIRAS_PREVIEW_HOST') == ''
      ? 'recovered-2026-11-03'
      : 'preview-2026-11-16:' +
            String.fromEnvironment('PAPIGIRAS_PREVIEW_HOST');
  static final expired = ValueNotifier<int>(0);
  static String? expiryMessage;

  /// Credential consumers rebind only after the complete credential is stored.
  static final changed = ValueNotifier<int>(0);
  static int _generation = 0;
  static int get generation => _generation;
  static const keys = [
    'token',
    'tokenExpiry',
    'loginData',
    'coordinatorData',
    'selectedTourId',
    'userRole',
    'userRut',
    'userPassword',
    'coordinatorRut',
    'labSessionRevision',
    'pendingCoordinatorLocations',
    'pendingBackgroundCoordinatorLocations',
    'coordinatorLocationSharingEnabled',
    'nativeTrackingSession',
    'nativeTrackingTour',
    'pendingNativeGpsClaim',
  ];

  static Future<void> clear(
    SharedPreferences prefs, {
    bool notifyChanged = true,
  }) async {
    // Revoke asynchronous work even if a future login receives the same token.
    final clearing = ++_generation;
    final locationStop = captureRemoteLocationStop(prefs);
    // A crash during cleanup must not restore a saved ON choice on next launch.
    await prefs.setBool('coordinatorLocationSharingEnabled', false);
    if (clearing != _generation) return;
    await prefs.setBool('isLoggedIn', false);
    if (locationStop != null) await rememberRemoteLocationStop(locationStop);
    // Revoke the background isolate before any slower native push cleanup.
    if (clearing != _generation) return;
    await prefs.remove('nativeTrackingSession');
    final pushCleanup = FcmUtils.stop();
    for (final key in keys) {
      if (clearing != _generation) break;
      await prefs.remove(key);
    }
    // Local identity is already revoked. A rejected cleanup cannot clear a new login.
    if (locationStop != null) await stopRemoteLocationSharing(locationStop);
    await pushCleanup;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (notifyChanged && clearing == _generation) changed.value++;
  }

  static Future<void> invalidateIfCurrent(
    String? requestToken, {
    bool notify = true,
    String? message,
    int? expectedGeneration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // A background GPS isolate can observe a 401 after the UI has logged in
    // again. Compare with the persisted session, not that isolate's cache.
    if (AppEnvironment.connected) await prefs.reload();
    final token = requestToken ?? '';
    if ((prefs.getString('token') ?? '') != token ||
        (expectedGeneration != null && expectedGeneration != _generation))
      return;
    // Expiry can remove the credential before a protected request returns 401.
    // Revoke that stale signed-in state, but never a signed-out login attempt
    // or a request without a captured generation. New sessions remain guarded
    // by both the credential and generation comparisons above.
    if (token.isEmpty &&
        (expectedGeneration == null || prefs.getBool('isLoggedIn') != true))
      return;
    final revocation = _generation + 1;
    await clear(prefs);
    if (notify && revocation == _generation) {
      expiryMessage = message;
      expired.value++;
    }
  }

  static Future<bool> hasActiveCoordinator(int coordinatorId) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.tryParse(prefs.getString('tokenExpiry') ?? '');
    if (coordinatorId <= 0 ||
        prefs.getBool('isLoggedIn') != true ||
        prefs.getString('userRole') != 'coordinator' ||
        prefs.getString('labSessionRevision') != revision ||
        (prefs.getString('token') ?? '').isEmpty ||
        expiry == null ||
        !expiry.isAfter(DateTime.now()))
      return false;
    try {
      final data = jsonDecode(prefs.getString('coordinatorData') ?? '');
      return data is Map && data['coordinatorId'] == coordinatorId;
    } catch (_) {
      return false;
    }
  }

  /// Caller must validate the new token against the coordinator's assigned tour
  /// before committing. The form retains its original owner and hito state.
  static Future<void> renewCoordinator({
    required CoordinatorLogin login,
    required TourSales expectedTour,
    required int expectedGeneration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (expectedTour.coordinatorId <= 0 ||
        expectedTour.tourSalesId <= 0 ||
        login.coordinatorId != expectedTour.coordinatorId ||
        login.token.isEmpty ||
        login.mustChangePassword ||
        expectedGeneration != _generation ||
        (prefs.getString('userRole') != null &&
            prefs.getString('userRole') != 'coordinator')) {
      throw const FormatException('No se puede renovar esta sesión.');
    }
    final existing = prefs.getString('coordinatorData');
    if (existing != null) {
      final data = jsonDecode(existing);
      if (data is! Map || data['coordinatorId'] != expectedTour.coordinatorId) {
        throw const FormatException('La cuenta activa cambió.');
      }
    }
    // Revoke old asynchronous operations without navigating away from draft.
    final renewal = ++_generation;
    Future<void> write(Future<bool> Function() operation) async {
      if (_generation != renewal)
        throw const FormatException('La sesión cambió.');
      await operation();
      if (_generation != renewal)
        throw const FormatException('La sesión cambió.');
    }

    await write(() => prefs.setString('token', login.token));
    await write(
      () => prefs.setString(
        'tokenExpiry',
        DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
      ),
    );
    await write(
      () => prefs.setString('coordinatorData', jsonEncode(login.toJson())),
    );
    await write(
      () => prefs.setString(
        'loginData',
        jsonEncode({
          ...expectedTour.toJson(),
          'tokenKey': login.token,
          'tourTripulationNameId': '${login.name} ${login.lastname}'.trim(),
          'tourTripulationIdentificationId': login.rut,
        }),
      ),
    );
    await write(() => prefs.setInt('selectedTourId', expectedTour.tourSalesId));
    await write(() => prefs.setString('userRole', 'coordinator'));
    await write(() => prefs.setString('labSessionRevision', revision));
    await write(() => prefs.remove('userPassword'));
    await write(() => prefs.setBool('isLoggedIn', true));
    changed.value++;
  }

  /// Replace a legacy attorney credential without navigating away from photos.
  /// The fresh login must still belong to the exact passenger and tour shown.
  static Future<void> renewAttorney({
    required ResponseAttorney login,
    required int expectedPassengerId,
    required int expectedTourId,
    required int expectedGeneration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('loginData');
    final data = existing == null ? null : jsonDecode(existing);
    if (expectedGeneration != _generation ||
        expectedPassengerId <= 0 ||
        expectedTourId <= 0 ||
        prefs.getString('userRole') != 'father' ||
        prefs.getBool('isLoggedIn') != true ||
        data is! Map ||
        data['passengerId'] != expectedPassengerId ||
        data['tourId'] != expectedTourId ||
        login.passengerId != expectedPassengerId ||
        login.tourId != expectedTourId ||
        login.isActive != true ||
        (login.tokenKey ?? '').trim().isEmpty) {
      throw const FormatException('La cuenta activa cambió.');
    }
    final renewal = ++_generation;
    Future<void> write(Future<bool> Function() operation) async {
      if (_generation != renewal)
        throw const FormatException('La sesión cambió.');
      await operation();
      if (_generation != renewal)
        throw const FormatException('La sesión cambió.');
    }

    await write(() => prefs.setString('token', login.tokenKey!));
    await write(
      () => prefs.setString(
        'tokenExpiry',
        DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
      ),
    );
    await write(() => prefs.setString('loginData', jsonEncode(login.toJson())));
    await write(() => prefs.setString('labSessionRevision', revision));
    await write(() => prefs.remove('userPassword'));
    changed.value++;
  }

  static Future<void> saveCoordinator(CoordinatorLogin login) async {
    if (login.token.isEmpty)
      throw const FormatException('Falta la sesión local.');
    final prefs = await SharedPreferences.getInstance();
    await clear(prefs, notifyChanged: false);
    await _save(prefs, login.token, 'coordinator');
    await prefs.setString('coordinatorData', jsonEncode(login.toJson()));
    changed.value++;
  }

  static Future<void> savePassenger(ResponseAttorney login, String role) async {
    if (!const {'attorney', 'passenger'}.contains(role) ||
        (login.passengerId ?? 0) <= 0 ||
        (login.tourId ?? 0) <= 0 ||
        (login.tokenKey ?? '').isEmpty ||
        login.isActive != true) {
      throw const FormatException(
        'Este perfil no tiene una sesión local disponible.',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await clear(prefs, notifyChanged: false);
    await _save(prefs, login.tokenKey!, role == 'attorney' ? 'father' : role);
    await prefs.setString('loginData', jsonEncode(login.toJson()));
    changed.value++;
  }

  static Future<void> _save(
    SharedPreferences prefs,
    String token,
    String role,
  ) async {
    await prefs.setString('token', token);
    await prefs.setString(
      'tokenExpiry',
      DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
    );
    await prefs.setString('userRole', role);
    await prefs.setString('labSessionRevision', revision);
    await prefs.setBool('isLoggedIn', true);
  }
}
