import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/runtime/api_destination.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/location_callback.dart';
import 'connected_gps_test.dart' show Gps;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group(
    'connected GPS recovery',
    () {
      late SharedPreferences prefs;
      late Gps gps;
      late LocationService service;
      late List<http.Request> requests;
      const nonce = 'session_recovery_aaaa';
      Future<void> login(int id, String token) async {
        await prefs.setString('userRole', 'coordinator');
        await prefs.setString('token', token);
        await prefs.setString(
          'coordinatorData',
          jsonEncode({'coordinatorId': id}),
        );
        await prefs.setInt('selectedTourId', 10);
        await prefs.setInt(nativeTrackingTourKey, 10);
      }

      void transport(Future<http.Response> Function(http.Request) respond) {
        locationClientForTests?.close();
        locationClientForTests = LabApiClient(
          transport: MockClient((request) {
            requests.add(request);
            return respond(request);
          }),
        );
      }

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
        await login(7, 'Bearer old-test-credential');
        requests = [];
        transport((_) async => http.Response('', 204));
        gps = Gps();
        service = LocationService(nativeDriver: gps);
      });
      tearDown(() {
        service.dispose();
        locationClientForTests?.close();
        locationClientForTests = null;
      });

      test(
        'failed OFF survives restart and logout without credentials and only its owner can retry',
        () async {
          await prefs.setString(nativeTrackingSessionKey, nonce);
          final target = captureRemoteLocationStop(prefs)!;
          transport((_) async => http.Response('', 503));
          expect(await stopRemoteLocationSharing(target), isFalse);
          final encoded = prefs.getString(target.storageKey)!;
          expect(encoded, isNot(contains('old-test-credential')));
          expect(jsonDecode(encoded), {
            'origin': AppEnvironment.apiUrl,
            'ownerId': 7,
            'tourId': 10,
            'session': nonce,
          });
          await clearPreferencesPreservingLocationStops(prefs);
          final disk = {
            for (final key in prefs.getKeys()) key: prefs.get(key)!,
          };
          SharedPreferences.setMockInitialValues(disk);
          prefs = await SharedPreferences.getInstance();
          requests.clear();
          transport((_) async => http.Response('', 204));
          await login(8, 'Bearer other-account');
          expect(await retryPendingLocationStops(prefs), isTrue);
          expect(requests, isEmpty);
          expect(prefs.containsKey(target.storageKey), isTrue);
          await login(7, 'Bearer renewed-test-credential');
          expect(await retryPendingLocationStops(prefs), isTrue);
          expect(
            requests.single.headers['authorization'],
            'Bearer renewed-test-credential',
          );
          expect(jsonDecode(requests.single.body), {
            'tourId': 10,
            'session': nonce,
            'enabled': false,
          });
          expect(prefs.containsKey(target.storageKey), isFalse);
        },
      );

      test('startup retries durable OFF without enabling native GPS', () async {
        await prefs.setString(nativeTrackingSessionKey, nonce);
        final target = captureRemoteLocationStop(prefs)!;
        await rememberRemoteLocationStop(target);
        await prefs.remove(nativeTrackingSessionKey);
        await prefs.setBool(LocationService.sharingPreferenceKey, false);
        await service.initializeForCoordinatorSession();
        await pumpEventQueue();
        expect(gps.starts, 0);
        expect(service.isTracking, isFalse);
        expect(prefs.containsKey(target.storageKey), isFalse);
        expect(
          requests.every(
            (request) => jsonDecode(request.body)['enabled'] == false,
          ),
          isTrue,
        );
      });

      test('another API origin recovery record is never transmitted', () async {
        final data = {
          'origin': 'https://other.example.test',
          'ownerId': 7,
          'tourId': 10,
          'session': nonce,
        };
        await prefs.setString(
          '${pendingLocationStopPrefix}other',
          jsonEncode(data),
        );
        await retryPendingLocationStops(prefs);
        expect(requests, isEmpty);
      });

      test(
        'write-ahead OFF intent prevents restart from restoring an old ON preference',
        () async {
          await prefs.setString(nativeTrackingSessionKey, nonce);
          await prefs.setBool(LocationService.sharingPreferenceKey, true);
          await rememberRemoteLocationStop(captureRemoteLocationStop(prefs)!);
          await service.initializeForCoordinatorSession();
          await pumpEventQueue();
          expect(gps.starts, 0);
          expect(service.isTracking, isFalse);
          expect(prefs.getBool(LocationService.sharingPreferenceKey), isFalse);
          expect(
            requests.every(
              (request) => jsonDecode(request.body)['enabled'] == false,
            ),
            isTrue,
          );
        },
      );

      test(
        'permanent ON rejection stops locally and does not become a retry queue',
        () async {
          transport(
            (request) async => http.Response(
              '',
              jsonDecode(request.body)['enabled'] == true ? 409 : 204,
            ),
          );
          await service.setSharingEnabled(true);
          expect(service.isTracking, isFalse);
          expect(gps.stops, greaterThan(0));
          expect(service.lastError, contains('sesión de ubicación terminó'));
          expect(prefs.getString(nativeTrackingSessionKey), isNull);
          expect(prefs.getStringList(pendingLocationsKey) ?? [], isEmpty);
          final count = requests.length;
          await service.advanceSyntheticRoute();
          expect(requests, hasLength(count));
          expect(
            requests.where(
              (request) =>
                  request.url.path.endsWith('add-position-coordinator'),
            ),
            isEmpty,
          );
        },
      );

      test(
        'background rejection blocks repeated reports and is reconciled on startup',
        () async {
          await prefs.setBool(LocationService.sharingPreferenceKey, true);
          await prefs.setString(nativeTrackingSessionKey, nonce);
          transport(
            (request) async => http.Response(
              '',
              jsonDecode(request.body)['enabled'] == true ? 403 : 204,
            ),
          );
          await expectLater(
            sendCoordinatorLocation(
              latitude: -33.5,
              longitude: -70.6,
              expectedTrackingSession: nonce,
              queue: LocationQueue.background,
            ),
            throwsA(isA<LocationSendRejected>()),
          );
          final count = requests.length;
          await sendCoordinatorLocation(
            latitude: -33.5,
            longitude: -70.6,
            expectedTrackingSession: nonce,
            queue: LocationQueue.background,
          );
          expect(requests, hasLength(count));
          await service.initializeForCoordinatorSession();
          expect(gps.starts, 0);
          expect(gps.stops, greaterThan(0));
          expect(service.isTracking, isFalse);
          expect(service.lastError, contains('Ya no tienes permiso'));
        },
      );

      test(
        'late rejected old registration cannot stop a newly enabled session',
        () async {
          final oldResponse = Completer<http.Response>();
          String? oldSession;
          transport((request) async {
            if (request.url.path.endsWith('location-sharing')) {
              final body = jsonDecode(request.body);
              if (body['enabled'] == true && oldSession == null) {
                oldSession = body['session'];
                return oldResponse.future;
              }
            }
            return http.Response('', 204);
          });
          final oldStart = service.setSharingEnabled(true);
          await pumpEventQueue();
          expect(oldSession, isNotNull);
          await service.setSharingEnabled(false);
          final newStart = service.setSharingEnabled(true);
          await pumpEventQueue();
          final current = prefs.getString(nativeTrackingSessionKey);
          expect(current, isNot(oldSession));
          oldResponse.complete(http.Response('', 409));
          await Future.wait([oldStart, newStart]);
          expect(service.isTracking, isTrue);
          expect(service.confirmedPosition, isNotNull);
          expect(rejectedLocationSession(prefs, current), isNull);
        },
      );

      test(
        'logout preserves failed OFF metadata after clearing the signed identity',
        () async {
          await service.setSharingEnabled(true);
          transport((_) async => http.Response('', 503));
          await LabSession.clear(prefs);
          await clearPreferencesPreservingLocationStops(prefs);
          expect(prefs.getString('token'), isNull);
          final pending = prefs.getKeys().where(
            (key) => key.startsWith(pendingLocationStopPrefix),
          );
          expect(pending, hasLength(1));
          expect(
            prefs.getString(pending.single),
            isNot(contains('old-test-credential')),
          );
        },
      );
    },
    skip: !AppEnvironment.connected
        ? 'Requires connected-mode build configuration'
        : false,
  );
}
