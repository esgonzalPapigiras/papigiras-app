import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/main.dart';
import 'package:papigiras_app/pages/welcome.dart';

void main() {
  test(
    'cold start rejects a profile cached before the recovered dataset',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', 'father');
      await prefs.setString('token', 'Bearer synthetic-old');
      await prefs.setString(
        'tokenExpiry',
        DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      );
      await prefs.setString(
        'loginData',
        jsonEncode(LabFixtures.passenger.toJson()),
      );
      expect(await determineLabStartScreen(), isA<WelcomeScreen>());
      expect(prefs.getString('loginData'), isNull);
      expect(prefs.getString('token'), isNull);
    },
  );
}
