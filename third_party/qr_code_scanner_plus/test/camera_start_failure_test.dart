import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final channels = <MethodChannel>[];
  final errors = <String>[];
  var starts = 0;
  var failDimensions = false;
  Future<Object?> Function()? start;

  setUp(() {
    errors.clear();
    starts = 0;
    failDimensions = false;
    start = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['id'];
          final channel = MethodChannel(
            'net.touchcapture.qr.flutterqrplus/qrview_$id',
          );
          channels.add(channel);
          binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
            method,
          ) async {
            if (method.method == 'setDimensions' && failDimensions) {
              throw PlatformException(code: 'dimensions-unavailable');
            }
            if (method.method == 'startScan') {
              starts++;
              return start?.call();
            }
            return null;
          });
        }
        return null;
      },
    );
  });

  tearDown(() {
    for (final channel in channels) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
  });

  Widget reader(GlobalKey key, {double width = 300}) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: width,
        height: 400,
        child: QRView(
          key: key,
          onQRViewCreated: (_) {},
          onCameraError: errors.add,
          formatsAllowed: const [BarcodeFormat.qrcode],
        ),
      ),
    ),
  );

  Future<void> finishStartup(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  void scenario(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  scenario('serializable native failure reaches callback without throwing', (
    tester,
  ) async {
    start = () async => throw PlatformException(
      code: 'unknown-error',
      message: 'Unable to start scanning',
      details: 'No camera available',
    );
    await tester.pumpWidget(reader(GlobalKey()));
    await finishStartup(tester);
    expect(starts, 1);
    expect(errors, ['Camera is not available.']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  scenario('successful startup does not report an error', (tester) async {
    await tester.pumpWidget(reader(GlobalKey()));
    await finishStartup(tester);
    expect(starts, 1);
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  scenario('permission denial is recoverable', (tester) async {
    start = () async => throw PlatformException(code: 'camera-permission-denied');
    await tester.pumpWidget(reader(GlobalKey()));
    await finishStartup(tester);
    expect(errors, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  scenario('late startup error does not notify a disposed reader', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    start = () => pending.future;
    await tester.pumpWidget(reader(GlobalKey()));
    await finishStartup(tester);
    expect(starts, 1);
    await tester.pumpWidget(const SizedBox());
    pending.completeError(PlatformException(code: 'unknown-error'));
    await tester.pump();
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  scenario('closing before layout delay never starts the camera', (
    tester,
  ) async {
    await tester.pumpWidget(reader(GlobalKey()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 350));
    expect(starts, 0);
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  scenario('resize failures are reported once instead of escaping async', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(reader(key));
    await finishStartup(tester);
    failDimensions = true;
    await tester.pumpWidget(reader(key, width: 250));
    await finishStartup(tester);
    await tester.pumpWidget(reader(key, width: 200));
    await finishStartup(tester);
    expect(errors, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
