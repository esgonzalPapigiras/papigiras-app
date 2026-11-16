import 'package:papigiras_app/lab/session.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/synthetic_location.dart';
import 'package:papigiras_app/main.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/location_callback.dart';

Future<void> coordinatorSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('userRole', 'coordinator');
  await prefs.setString('token', 'Bearer fictional-lab-token');
  await prefs.setInt('selectedTourId', 1);
}

class _DeferredRestoreLocation extends LabSyntheticLocation {
  final restoring = Completer<void>();
  final continueRestore = Completer<void>();
  @override
  Future<void> restore() async {
    if (!restoring.isCompleted) restoring.complete();
    await continueRestore.future;
    await super.restore();
  }
}

void main() {
  tearDown(() {
    locationClientForTests?.close();
    locationClientForTests = null;
  });

  test(
    'cold start restores a persisted valid session and rejects an expired one',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('labSessionRevision', LabSession.revision);
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', 'father');
      await prefs.setString('token', 'Bearer fictional-lab-token');
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      );
      await prefs.setString(
        'loginData',
        jsonEncode(LabFixtures.passenger.toJson()),
      );
      expect(await determineLabStartScreen(), isA<TravelFatherDashboard>());
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      );
      expect(await determineLabStartScreen(), isA<WelcomeScreen>());
      expect(prefs.getString('token'), isNull);
    },
  );

  test(
    'synthetic route selection and pause survive a new source instance',
    () async {
      final source = LabSyntheticLocation();
      await source.select(3);
      await source.setPaused(true);
      final restarted = LabSyntheticLocation();
      await restarted.restore();
      expect(restarted.index, 3);
      expect(restarted.paused, isTrue);
      await restarted.advance();
      expect(restarted.index, 3);
      await restarted.setPaused(false);
      await restarted.advance();
      expect(restarted.index, 4);
      source.dispose();
      restarted.dispose();
    },
  );

  test(
    'offline points persist and retry with original timestamps and tour context',
    () async {
      await coordinatorSession();
      final requests = <Uri>[];
      var online = false;
      locationClientForTests = LabApiClient(
        transport: MockClient((request) async {
          requests.add(request.url);
          return http.Response('', online ? 200 : 503);
        }),
      );
      await sendCoordinatorLocation(latitude: -33.4460, longitude: -70.6530);
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(pendingLocationsKey)!;
      expect(pending.length, 1);
      final stored = jsonDecode(pending.single);
      online = true;
      await sendCoordinatorLocation(latitude: -33.4440, longitude: -70.6510);
      expect(prefs.getStringList(pendingLocationsKey), isEmpty);
      expect(requests[1].queryParameters['recordedAt'], stored['recordedAt']);
      expect(requests[1].queryParameters['tourId'], '1');
      expect(requests.last.queryParameters['latitud'], '-33.444');
      expect(
        requests.every((u) => u.host == '127.0.0.1' && u.port == 8084),
        isTrue,
      );
    },
  );

  test('non-coordinator sessions never send positions', () async {
    var calls = 0;
    locationClientForTests = LabApiClient(
      transport: MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    await (await SharedPreferences.getInstance()).setString(
      'userRole',
      'father',
    );
    await sendCoordinatorLocation(latitude: -33.4460, longitude: -70.6530);
    expect(calls, 0);
  });

  test(
    'synthetic tracking advances, queues and resumes without claiming native background GPS',
    () async {
      await coordinatorSession();
      var calls = 0;
      locationClientForTests = LabApiClient(
        transport: MockClient((_) async {
          calls++;
          return http.Response('', 200);
        }),
      );
      final source = LabSyntheticLocation();
      final service = LocationService(
        source: source,
        heartbeatInterval: const Duration(hours: 1),
      );
      await service.initializeForCoordinatorSession();
      expect(calls, 0);
      expect(service.isTracking, isFalse);
      await service.setSharingEnabled(true);
      expect(calls, 1);
      await service.advanceSyntheticRoute();
      expect(source.index, 1);
      expect(calls, 2);
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(source.index, 1);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(calls, 3);
      expect(service.backgroundTrackingEnabled, isFalse);
      await service.stopTracking();
      service.dispose();
      source.dispose();
    },
  );

  test(
    'new coordinator session defaults off and off survives recreation and resume',
    () async {
      await coordinatorSession();
      var calls = 0;
      locationClientForTests = LabApiClient(
        transport: MockClient((_) async {
          calls++;
          return http.Response('', 200);
        }),
      );
      final source = LabSyntheticLocation();
      final service = LocationService(source: source);
      await service.initializeForCoordinatorSession();
      expect(service.isTracking, isFalse);
      await service.advanceSyntheticRoute();
      expect(source.index, 0);
      expect(calls, 0);
      await service.setSharingEnabled(true);
      expect(calls, 1);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          LocationService.sharingPreferenceKey,
        ),
        isTrue,
      );
      service.dispose();
      final restored = LocationService(source: source);
      await restored.initializeForCoordinatorSession();
      expect(restored.isTracking, isTrue);
      expect(calls, 2);
      await restored.setSharingEnabled(false);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          LocationService.sharingPreferenceKey,
        ),
        isFalse,
      );
      restored.didChangeAppLifecycleState(AppLifecycleState.paused);
      restored.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await restored.advanceSyntheticRoute();
      expect(calls, 2);
      expect(source.index, 0);
      restored.dispose();
      final returned = LocationService(source: source);
      await returned.initializeForCoordinatorSession();
      expect(returned.isTracking, isFalse);
      expect(calls, 2);
      returned.dispose();
      source.dispose();
    },
  );

  test(
    'off persists immediately during an in-flight queue flush and preserves unsent points',
    () async {
      await coordinatorSession();
      final prefs = await SharedPreferences.getInstance();
      final points = [
        for (var i = 0; i < 2; i++)
          jsonEncode({
            'latitude': -33.44 - i / 1000,
            'longitude': -70.65,
            'tourId': 1,
            'recordedAt': '2026-11-05T10:0$i:00.000Z',
          }),
      ];
      await prefs.setStringList(pendingLocationsKey, points);
      final started = Completer<void>();
      final response = Completer<http.Response>();
      var calls = 0;
      locationClientForTests = LabApiClient(
        transport: MockClient((_) async {
          calls++;
          if (calls == 1) {
            started.complete();
            return response.future;
          }
          return http.Response('', 200);
        }),
      );
      final source = LabSyntheticLocation();
      final service = LocationService(source: source);
      final enabling = service.setSharingEnabled(true);
      final repeatedEnable = service.setSharingEnabled(true);
      expect(identical(enabling, repeatedEnable), isTrue);
      expect(service.isChangingMode, isTrue);
      await started.future;
      expect(
        service.isChangingMode,
        isFalse,
      ); // OFF stays available during HTTP.
      await service.setSharingEnabled(false);
      expect(service.isTracking, isFalse);
      expect(service.isChangingMode, isFalse);
      expect(prefs.getBool(LocationService.sharingPreferenceKey), isFalse);
      expect(calls, 1);
      response.complete(http.Response('', 200));
      await enabling;
      expect(calls, 1);
      expect(prefs.getStringList(pendingLocationsKey), [points[1]]);
      await service.setSharingEnabled(true);
      expect(
        calls,
        3,
      ); // Remaining old point, then the newly requested current point.
      expect(prefs.getStringList(pendingLocationsKey), isEmpty);
      await service.stopTracking();
      service.dispose();
      source.dispose();
    },
  );

  test(
    'background suspension revokes an ongoing flush without changing the sharing choice',
    () async {
      await coordinatorSession();
      final prefs = await SharedPreferences.getInstance();
      final point = jsonEncode({
        'latitude': -33.44,
        'longitude': -70.65,
        'tourId': 1,
        'recordedAt': '2026-11-05T10:00:00.000Z',
      });
      await prefs.setStringList(pendingLocationsKey, [point, point]);
      final started = Completer<void>();
      final response = Completer<http.Response>();
      var calls = 0;
      locationClientForTests = LabApiClient(
        transport: MockClient((_) async {
          calls++;
          if (calls == 1) {
            started.complete();
            return response.future;
          }
          return http.Response('', 200);
        }),
      );
      final source = LabSyntheticLocation();
      final service = LocationService(source: source);
      final enabling = service.setSharingEnabled(true);
      await started.future;
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      response.complete(http.Response('', 200));
      await enabling;
      expect(calls, 1);
      expect(service.isTracking, isTrue);
      expect(prefs.getBool(LocationService.sharingPreferenceKey), isTrue);
      expect(prefs.getStringList(pendingLocationsKey), [point]);
      await service.advanceSyntheticRoute();
      expect(source.index, 0);
      await service.stopTracking();
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      service.dispose();
      source.dispose();
    },
  );

  test(
    'session clear revokes old sends even when the next session reuses the token',
    () async {
      await coordinatorSession();
      final prefs = await SharedPreferences.getInstance();
      final started = Completer<void>();
      final response = Completer<http.Response>();
      var calls = 0;
      locationClientForTests = LabApiClient(
        transport: MockClient((_) async {
          calls++;
          started.complete();
          return response.future;
        }),
      );
      final source = LabSyntheticLocation();
      final service = LocationService(source: source);
      final enabling = service.setSharingEnabled(true);
      await started.future;
      await LabSession.clear(prefs);
      await prefs.setString('userRole', 'coordinator');
      await prefs.setString('token', 'Bearer fictional-lab-token');
      response.complete(http.Response('', 503));
      await enabling;
      expect(prefs.getBool(LocationService.sharingPreferenceKey), isNull);
      expect(prefs.getStringList(pendingLocationsKey), isNull);
      await service.advanceSyntheticRoute();
      await service.initializeForCoordinatorSession();
      expect(service.isTracking, isFalse);
      expect(calls, 1);
      service.dispose();
      final newSession = LocationService(source: source);
      await coordinatorSession();
      await newSession.initializeForCoordinatorSession();
      expect(newSession.isTracking, isFalse);
      expect(calls, 1);
      newSession.dispose();
      source.dispose();
    },
  );

  test(
    'a route advance revoked during its asynchronous restore does not move the point',
    () async {
      final source = LabSyntheticLocation();
      var permitted = true;
      final advancing = source.advance(shouldAdvance: () => permitted);
      permitted = false;
      await advancing;
      expect(source.index, 0);
      source.dispose();
    },
  );
  test(
    'foreground heartbeat stops advancing and sending when sharing is off',
    () async {
      await coordinatorSession();
      var calls = 0;
      locationClientForTests = LabApiClient(
        transport: MockClient((_) async {
          calls++;
          return http.Response('', 200);
        }),
      );
      final source = LabSyntheticLocation();
      final service = LocationService(
        source: source,
        heartbeatInterval: const Duration(milliseconds: 10),
      );
      await service.initializeForCoordinatorSession();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(calls, 0);
      expect(source.index, 0);
      await service.setSharingEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(calls, greaterThanOrEqualTo(2));
      await service.stopTracking();
      final stoppedCalls = calls;
      final stoppedIndex = source.index;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(calls, stoppedCalls);
      expect(source.index, stoppedIndex);
      service.dispose();
      source.dispose();
    },
  );
  test(
    'logout during route initialization cannot restore sharing into the next session',
    () async {
      await coordinatorSession();
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      locationClientForTests = LabApiClient(
        transport: MockClient((_) async {
          calls++;
          return http.Response('', 200);
        }),
      );
      final source = _DeferredRestoreLocation();
      final service = LocationService(source: source);
      final enabling = service.setSharingEnabled(true);
      await source.restoring.future;
      await LabSession.clear(prefs);
      await prefs.setString('userRole', 'coordinator');
      await prefs.setString('token', 'Bearer fictional-lab-token');
      source.continueRestore.complete();
      await enabling;
      expect(prefs.getBool(LocationService.sharingPreferenceKey), isNull);
      expect(service.isTracking, isFalse);
      await service.initializeForCoordinatorSession();
      expect(service.isTracking, isFalse);
      expect(calls, 0);
      service.dispose();
      source.dispose();
    },
  );
}
