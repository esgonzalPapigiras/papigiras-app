import 'dart:io';

import '../lib/runtime/api_destination.dart';

void main() {
  try {
    ApiDestination(Platform.environment['PAPIGIRAS_API_URL'] ?? '');
    final value = Platform.environment['PAPIGIRAS_BUILD_NUMBER'] ?? '';
    final build = int.tryParse(value);
    // Official baseline is 1.1.0+16. App Store Connect may already be higher;
    // the operator must choose an unused number above the actual latest build.
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(value) ||
        build == null ||
        build <= 16 ||
        build > 2100000000) {
      throw const FormatException('Invalid candidate build number');
    }
  } catch (_) {
    stderr.writeln(
      'Set PAPIGIRAS_API_URL to one HTTPS origin and '
      'PAPIGIRAS_BUILD_NUMBER to an unused integer greater than 16.',
    );
    exitCode = 1;
  }
}
