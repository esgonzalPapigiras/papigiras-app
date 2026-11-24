import 'dart:async';
import 'dart:ui';

import 'package:background_locator_2/callback_dispatcher.dart';
import 'package:background_locator_2/keys.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/tracking/native_gps_driver.dart';
import 'package:papigiras_app/utils/location_callback.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Android channel initializes the session and sends a background fix only while sharing',
    () async {
      const session = 'fixture-background-session';
      SharedPreferences.setMockInitialValues({
        'userRole': 'coordinator',
        'token': 'Bearer test-only',
        'selectedTourId': 9,
        nativeTrackingTourKey: 9,
        nativeTrackingSessionKey: session,
        'coordinatorLocationSharingEnabled': true,
      });
      final requests = <http.Request>[];
      final posted = Completer<void>();
      locationClientForTests = LabApiClient(
        transport: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/add-position-coordinator'))
            posted.complete();
          return http.Response('{}', 200);
        }),
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(Keys.BACKGROUND_CHANNEL_ID);
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      callbackDispatcher();
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        channel.setMethodCallHandler(null);
        locationClientForTests?.close();
        locationClientForTests = null;
      });
      Future<void> deliver(String method, Map<String, dynamic> args) async {
        final reply = await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, args)),
          null,
        );
        channel.codec.decodeEnvelope(reply!);
      }

      await deliver(Keys.BCM_INIT, {
        Keys.ARG_INIT_CALLBACK: PluginUtilities.getCallbackHandle(
          initializeNativeTracking,
        )!.toRawHandle(),
        Keys.ARG_INIT_DATA_CALLBACK: {'session': session},
      });
      final event = {
        Keys.ARG_CALLBACK: PluginUtilities.getCallbackHandle(
          nativeLocationCallback,
        )!.toRawHandle(),
        Keys.ARG_LOCATION: {
          Keys.ARG_LATITUDE: -33.0,
          Keys.ARG_LONGITUDE: -70.0,
          Keys.ARG_ACCURACY: 4.0,
          Keys.ARG_ALTITUDE: 0.0,
          Keys.ARG_SPEED: 0.0,
          Keys.ARG_SPEED_ACCURACY: 0.0,
          Keys.ARG_HEADING: 0.0,
          Keys.ARG_TIME: 1700000000000.0,
          Keys.ARG_IS_MOCKED: false,
        },
      };
      await deliver(Keys.BCM_SEND_LOCATION, event);
      await posted.future.timeout(const Duration(seconds: 5));
      expect(requests.last.url.queryParameters['trackingSession'], session);
      expect(
        requests.last.url.queryParameters['recordedAt'],
        '2023-11-14T22:13:20.000Z',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('coordinatorLocationSharingEnabled', false);
      await deliver(Keys.BCM_SEND_LOCATION, event);
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(2));
    },
    skip: const String.fromEnvironment('PAPIGIRAS_API_URL').isEmpty,
  );
}
