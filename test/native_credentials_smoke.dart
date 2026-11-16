// Native QA entrypoint. Install ONLY on a freshly created disposable simulator.
// No API, login, location or real profile is used. Never use in the active Pilo.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lib/auth/saved_credentials.dart';

const _enabled = bool.fromEnvironment('CREDENTIALS_NATIVE_QA');
const _roles = ['attorney', 'passenger', 'coordinator'];
const _rut = '99000011-5';
const _password = 'Ficticia-Solo-QA';
final _status = ValueNotifier<String>('Validando almacenamiento local…');
final _checks = <String>[];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: _status,
              builder: (_, value, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(value, textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _verify();
}

void _expect(bool condition, String check) {
  if (!condition) throw StateError(check);
  _checks.add(check);
}

Future<void> _expectSaved(String role, String password) async {
  final saved = await SavedCredentials.read(role);
  _expect(
    saved?['rut'] == _rut && saved?['password'] == password,
    '$role: secure read matches synthetic fixture',
  );
}

Future<void> _writeReport(int phase, String result) async {
  await File(
    '${Directory.systemTemp.path}/credentials-native-qa.json',
  ).writeAsString(
    jsonEncode({
      'phase': phase,
      'result': result,
      'checks': _checks,
      'utc': DateTime.now().toUtc().toIso8601String(),
      'usesRealApi': false,
      'usesSyntheticCredentialsOnly': true,
    }),
    flush: true,
  );
  _status.value = result;
}

Future<void> _verify() async {
  if (!_enabled || !Platform.isIOS) {
    _status.value = 'QA disabled; storage untouched.';
    return;
  }
  final report = File(
    '${Directory.systemTemp.path}/credentials-native-qa.json',
  );
  var phase = 0;
  try {
    if (await report.exists()) {
      final previous = jsonDecode(await report.readAsString());
      phase = previous['phase'] as int;
      if (previous['result'].toString().contains('FAILED')) {
        _status.value = 'Previous QA failed; storage untouched.';
        return;
      }
    }
    if (phase == 0) {
      // Refuse to mutate any previously populated credential namespace.
      for (final role in _roles) {
        _expect(
          await SavedCredentials.read(role) == null,
          '$role: initially empty on disposable simulator',
        );
      }
      for (final role in _roles) {
        await SavedCredentials.save(role, _rut, '$_password-$role');
        await _expectSaved(role, '$_password-$role');
      }
      await SavedCredentials.delete('passenger');
      _expect(
        await SavedCredentials.read('passenger') == null,
        'passenger: deletion removes only the requested role',
      );
      await _expectSaved('attorney', '$_password-attorney');
      await _expectSaved('coordinator', '$_password-coordinator');
      await SavedCredentials.save('passenger', _rut, '$_password-passenger');
      await _expectSaved('passenger', '$_password-passenger');
      await _writeReport(1, 'PILO_CREDENTIALS_PHASE1_OK');
      return;
    }

    if (phase == 1) {
      // The runner terminates and relaunches the process between phases.
      for (final role in _roles) {
        await _expectSaved(role, '$_password-$role');
      }
      _checks.add('all three roles survived complete process termination');
      await SavedCredentials.updatePasswordForIdentity(
        roles: const ['attorney'],
        rut: '99.000.011-5',
        password: '$_password-updated',
      );
      await _expectSaved('attorney', '$_password-updated');
      await _expectSaved('passenger', '$_password-passenger');
      await _expectSaved('coordinator', '$_password-coordinator');
      for (final role in _roles) {
        await SavedCredentials.delete(role);
        _expect(
          await SavedCredentials.read(role) == null,
          '$role: synthetic credential removed',
        );
      }
      await _writeReport(2, 'PILO_CREDENTIALS_PHASE2_OK');
      return;
    }
    for (final role in _roles) {
      _expect(
        await SavedCredentials.read(role) == null,
        '$role: deletion persisted after another process restart',
      );
    }
    await _writeReport(3, 'PILO_CREDENTIALS_PHASE3_OK');
  } catch (error) {
    // Never print credential values, raw exception messages or native payloads.
    final code = error is PlatformException ? error.code : error.runtimeType;
    _checks.add('error type/code: $code');
    await _writeReport(phase, 'PILO_CREDENTIALS_FAILED');
  }
}
