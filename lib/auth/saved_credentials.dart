import 'package:flutter/services.dart';

/// Only native device-protected storage; never preferences, logs or the API.
abstract final class SavedCredentials {
  static const _channel = MethodChannel('com.papigiras.lab/credentials');
  static const _roles = {'attorney', 'passenger', 'coordinator'};

  static void _check(String role) {
    if (!_roles.contains(role)) throw ArgumentError.value(role, 'role');
  }

  static Future<Map<String, String>?> read(String role) async {
    _check(role);
    final saved = await _channel.invokeMapMethod<String, String>('read', {
      'role': role,
    });
    if (saved == null ||
        (saved['rut'] ?? '').isEmpty ||
        (saved['password'] ?? '').isEmpty)
      return null;
    return saved;
  }

  static Future<void> save(String role, String rut, String password) async {
    _check(role);
    await _channel.invokeMethod<void>('save', {
      'role': role,
      'rut': rut,
      'password': password,
    });
  }

  static Future<void> delete(String role) async {
    _check(role);
    await _channel.invokeMethod<void>('delete', {'role': role});
  }

  static String _identity(String rut) =>
      rut.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();

  /// A password change never opts a user into remembering their credentials,
  /// nor overwrites a different student's credential saved for another role.
  static Future<void> updatePasswordForIdentity({
    required List<String> roles,
    required String rut,
    required String password,
  }) async {
    for (final role in roles) {
      final saved = await read(role);
      if (saved != null && _identity(saved['rut']!) == _identity(rut)) {
        await save(role, saved['rut']!, password);
      }
    }
  }
}
