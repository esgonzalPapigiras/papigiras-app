import 'package:flutter/material.dart';

/// Only fictional accounts from the isolated LAB database, prefilled into the
/// original editable login forms. This is not an alternative authentication flow.
abstract final class LabDemoCredentials {
  static const coordinatorRut = '990000018';
  static const passengerRut = '990000115';
  static const password = 'PapigirasLAB-2026!';
}

class LabCredentialsHint extends StatelessWidget {
  final bool coordinator;
  const LabCredentialsHint({super.key, this.coordinator = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      'Cuenta ficticia LAB: ${coordinator ? LabDemoCredentials.coordinatorRut : LabDemoCredentials.passengerRut}\nClave: ${LabDemoCredentials.password}',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 11, color: Colors.teal),
    ),
  );
}
