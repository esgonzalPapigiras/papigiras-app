import 'package:flutter/foundation.dart';

abstract final class LabMode {
  static bool _fixturesForTests = false;
  static bool get fixturesForTests => _fixturesForTests;
  @visibleForTesting
  static void useFixturesForTests(bool enabled) => _fixturesForTests = enabled;
}
