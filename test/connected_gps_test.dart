import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/runtime/api_destination.dart';
import 'package:papigiras_app/tracking/native_gps_driver.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/location_callback.dart';

class Gps implements NativeGpsDriver {
  Completer<void>? permission;
  Completer<(double, double)>? reading;
  int starts = 0, stops = 0;
  bool Function()? current;
  @override
  bool get backgroundEnabled => true;
  @override
  String? get warning => null;
  @override
  Future<void> start({
    required String session,
    required bool Function() isCurrent,
    required void Function(double, double) onPosition,
    required void Function(String) onError,
  }) async {
    starts++;
    current = isCurrent;
    await permission?.future;
  }

  @override
  Future<(double, double)> currentPosition() async =>
      reading == null ? (-36.8, -73.0) : await reading!.future;
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  void dispose() {}
}

void main() {
  group(
    'connected native GPS',
    () {
      late SharedPreferences prefs;
      late Gps gps;
      late LocationService service;
      late List<http.Request> requests;
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
        await prefs.setString('userRole', 'coordinator');
        await prefs.setString('token', 'Bearer test-only');
        await prefs.setBool('isLoggedIn', true);
        await prefs.setInt('selectedTourId', 10);
        await prefs.setInt(nativeTrackingTourKey, 10);
        requests = [];
        locationClientForTests = LabApiClient(
          transport: MockClient((request) async {
            requests.add(request);
            return http.Response('{}', 200);
          }),
        );
        gps = Gps();
        service = LocationService(nativeDriver: gps);
      });
      tearDown(() {
        service.dispose();
        locationClientForTests?.close();
        locationClientForTests = null;
      });

      test(
        'starts only after opt-in and reports real coordinates to the selected tour',
        () async {
          await service.initializeForCoordinatorSession();
          expect(gps.starts, 0);
          expect(requests, isEmpty);
          await service.setSharingEnabled(true);
          expect(gps.starts, 1);
          expect(requests, hasLength(2));
          expect(jsonDecode(requests.first.body)['enabled'], isTrue);
          expect(requests.last.url.queryParameters['latitud'], '-36.8');
          expect(requests.last.url.queryParameters['longitud'], '-73.0');
          expect(requests.last.url.queryParameters['tourId'], '10');
          expect(
            requests.last.url.queryParameters['trackingSession'],
            prefs.getString(nativeTrackingSessionKey),
          );
          expect(service.confirmedPosition!.latitude, -36.8);
          expect(service.backgroundTrackingEnabled, isTrue);
        },
      );

      test(
        'OFF revokes pending permission and background session without waiting',
        () async {
          gps.permission = Completer<void>();
          final starting = service.setSharingEnabled(true);
          await Future<void>.delayed(Duration.zero);
          await service.setSharingEnabled(false);
          expect(prefs.getString(nativeTrackingSessionKey), isNull);
          expect(service.isTracking, isFalse);
          gps.permission!.complete();
          await starting;
          expect(requests, hasLength(1));
          expect(jsonDecode(requests.single.body)['enabled'], isFalse);
          expect(gps.current!(), isFalse);
        },
      );

      test('tour changes invalidate a GPS reading already in flight', () async {
        gps.reading = Completer<(double, double)>();
        final starting = service.setSharingEnabled(true);
        await Future<void>.delayed(Duration.zero);
        await prefs.setInt('selectedTourId', 11);
        gps.reading!.complete((-36.8, -73.0));
        await starting;
        expect(requests, isEmpty);
        expect(service.confirmedPosition, isNull);
      });

      test(
        'OFF during delayed ON acknowledgement never sends the captured position',
        () async {
          final registering = Completer<http.Response>();
          locationClientForTests!.close();
          locationClientForTests = LabApiClient(
            transport: MockClient((request) async {
              requests.add(request);
              if (request.url.path.endsWith('location-sharing') &&
                  jsonDecode(request.body)['enabled'] == true)
                return registering.future;
              return http.Response('{}', 200);
            }),
          );
          final starting = service.setSharingEnabled(true);
          while (requests.isEmpty) {
            await Future<void>.delayed(Duration.zero);
          }
          final session = jsonDecode(requests.single.body)['session'];
          await service.setSharingEnabled(false);
          expect(service.isTracking, isFalse);
          expect(prefs.getString(nativeTrackingSessionKey), isNull);
          expect(jsonDecode(requests.last.body), {
            'tourId': 10,
            'session': session,
            'enabled': false,
          });
          registering.complete(http.Response('{}', 200));
          await starting;
          expect(
            requests.where(
              (request) =>
                  request.url.path.endsWith('add-position-coordinator'),
            ),
            isEmpty,
          );
          expect(service.confirmedPosition, isNull);
        },
      );

      test(
        'unconfirmed OFF reports local stop and retries the captured old tour on resume',
        () async {
          var online = true;
          locationClientForTests!.close();
          locationClientForTests = LabApiClient(
            transport: MockClient((request) async {
              requests.add(request);
              return http.Response('{}', online ? 200 : 503);
            }),
          );
          await service.setSharingEnabled(true);
          final session = prefs.getString(nativeTrackingSessionKey);
          online = false;
          await service.setSharingEnabled(false);
          expect(service.isTracking, isFalse);
          expect(service.lastError, contains('No pudimos confirmar'));
          expect(gps.stops, greaterThan(0));
          await prefs.setInt('selectedTourId', 11);
          await prefs.setString('token', 'Bearer another-login');
          online = true;
          service.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(jsonDecode(requests.last.body), {
            'tourId': 10,
            'session': session,
            'enabled': false,
          });
          expect(requests.last.headers['authorization'], 'Bearer test-only');
          expect(prefs.getString('token'), 'Bearer another-login');
          expect(service.lastError, isNull);
        },
      );

      test(
        'logout revokes local identity before sending the captured OFF',
        () async {
          await service.setSharingEnabled(true);
          final session = prefs.getString(nativeTrackingSessionKey);
          locationClientForTests!.close();
          locationClientForTests = LabApiClient(
            transport: MockClient((request) async {
              requests.add(request);
              expect(prefs.getString('token'), isNull);
              expect(prefs.getString(nativeTrackingSessionKey), isNull);
              return http.Response('{}', 200);
            }),
          );
          await LabSession.clear(prefs);
          expect(jsonDecode(requests.last.body), {
            'tourId': 10,
            'session': session,
            'enabled': false,
          });
          expect(requests.last.headers['authorization'], 'Bearer test-only');
        },
      );

      test(
        'background callbacks reject a revoked or replaced session',
        () async {
          await prefs.setBool(LocationService.sharingPreferenceKey, true);
          await prefs.setString(nativeTrackingSessionKey, 'new-session');
          await sendCoordinatorLocation(
            latitude: -36.8,
            longitude: -73,
            expectedTrackingSession: 'old-session',
          );
          expect(requests, isEmpty);
          await LabSession.clear(prefs);
          await sendCoordinatorLocation(
            latitude: -36.8,
            longitude: -73,
            expectedTrackingSession: 'new-session',
          );
          expect(
            requests.where(
              (request) =>
                  request.url.path.endsWith('add-position-coordinator'),
            ),
            isEmpty,
          );
          expect(jsonDecode(requests.single.body)['session'], 'new-session');
        },
      );

      test(
        'background callback cannot use an old nonce for a newly selected tour',
        () async {
          await prefs.setBool(LocationService.sharingPreferenceKey, true);
          await prefs.setString(
            nativeTrackingSessionKey,
            'session_aaaaaaaaaaaa',
          );
          await prefs.setInt('selectedTourId', 11);
          await sendCoordinatorLocation(
            latitude: -36.8,
            longitude: -73,
            expectedTrackingSession: 'session_aaaaaaaaaaaa',
            queue: LocationQueue.background,
          );
          expect(requests, isEmpty);
        },
      );

      test(
        'permission failure stays visible after successful remote cleanup',
        () async {
          gps.permission = Completer<void>();
          final starting = service.setSharingEnabled(true);
          await Future<void>.delayed(Duration.zero);
          gps.permission!.completeError(
            StateError('Permiso de ubicación denegado.'),
          );
          await starting;
          expect(service.isTracking, isFalse);
          expect(service.lastError, contains('Permiso de ubicación denegado'));
          expect(jsonDecode(requests.single.body)['enabled'], isFalse);
        },
      );

      test(
        'background and foreground retries retain separate queues and capture times',
        () async {
          await prefs.setBool(LocationService.sharingPreferenceKey, true);
          await prefs.setString(nativeTrackingSessionKey, 'session');
          var online = false;
          locationClientForTests!.close();
          locationClientForTests = LabApiClient(
            transport: MockClient((request) async {
              requests.add(request);
              return http.Response('{}', online ? 200 : 503);
            }),
          );
          final captured = DateTime.utc(2026, 11, 20, 10);
          await sendCoordinatorLocation(
            latitude: -36.8,
            longitude: -73,
            expectedTrackingSession: 'session',
            recordedAt: captured,
          );
          await sendCoordinatorLocation(
            latitude: -36.9,
            longitude: -73.1,
            expectedTrackingSession: 'session',
            queue: LocationQueue.background,
            recordedAt: captured.add(const Duration(minutes: 1)),
          );
          expect(prefs.getStringList(pendingLocationsKey), hasLength(1));
          expect(
            prefs.getStringList(pendingBackgroundLocationsKey),
            hasLength(1),
          );
          online = true;
          requests.clear();
          await sendCoordinatorLocation(
            latitude: -37,
            longitude: -73.2,
            expectedTrackingSession: 'session',
            queue: LocationQueue.background,
          );
          final positions = requests
              .where(
                (request) =>
                    request.url.path.endsWith('add-position-coordinator'),
              )
              .toList();
          expect(positions, hasLength(2));
          expect(
            positions.first.url.queryParameters['recordedAt'],
            captured.add(const Duration(minutes: 1)).toIso8601String(),
          );
          expect(prefs.getStringList(pendingBackgroundLocationsKey), isEmpty);
          expect(prefs.getStringList(pendingLocationsKey), hasLength(1));
          await LabSession.clear(prefs);
          expect(prefs.getStringList(pendingLocationsKey), isNull);
          expect(prefs.getStringList(pendingBackgroundLocationsKey), isNull);
        },
      );
    },
    skip: !AppEnvironment.connected
        ? 'Requires connected-mode build configuration'
        : false,
  );
}
