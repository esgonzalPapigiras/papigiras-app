import 'dart:io';

import '../lib/runtime/api_destination.dart';

void main() {
  try {
    ApiDestination(Platform.environment['PAPIGIRAS_API_URL'] ?? '');
  } on FormatException {
    stderr.writeln('Set PAPIGIRAS_API_URL to one HTTPS origin.');
    exitCode = 1;
    return;
  }

  final value = Platform.environment['CI_BUILD_NUMBER'] ?? '';
  final build = int.tryParse(value);
  // This iOS train already has a manually uploaded 1.1.3 (1).
  // Keep Apple's counter unmodified and reject a collision before archiving.
  if (!RegExp(r'^[1-9][0-9]*$').hasMatch(value) ||
      build == null ||
      build <= 1 ||
      build > 2100000000) {
    stderr.writeln(
      'CI_BUILD_NUMBER must be an integer from 2 through 2100000000; '
      'App Store Connect already has build 1 for iOS 1.1.3.',
    );
    exitCode = 1;
  }
}
