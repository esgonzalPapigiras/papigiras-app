import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void captureTest(
  String description,
  Future<void> Function(WidgetTester) callback,
) {
  final platform = Platform.environment['PILO_CAPTURE_PLATFORM'];
  if (platform == 'android' || platform == 'ios') {
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant({
        platform == 'ios' ? TargetPlatform.iOS : TargetPlatform.android,
      }),
    );
  } else {
    testWidgets(description, callback);
  }
}

/// Opt-in capture output for side-by-side reference/candidate renders. Keeps
/// the original fixture paths when no separate evidence directory is supplied.
File visualCaptureFile(String referencePath) {
  final directory = Platform.environment['PILO_CAPTURE_DIR'];
  final path = directory == null || directory.isEmpty
      ? referencePath
      : '$directory/${referencePath.replaceAll('\\', '/').split('/').last}';
  final file = File(path);
  file.parent.createSync(recursive: true);
  return file;
}
