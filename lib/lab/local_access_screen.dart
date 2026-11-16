import 'package:flutter/material.dart';
import 'local_access.dart';
import 'local_access_panel.dart';
import 'role_destination.dart';

/// Route wrapper preserves the existing role-only constructor used by the UI.
class LocalAccessScreen extends StatelessWidget {
  const LocalAccessScreen({super.key, required this.role, this.client});
  final String role;
  @visibleForTesting
  final LocalAccessClient? client;
  @override
  Widget build(BuildContext context) => LocalAccessPanel(
    role: role,
    client: client,
    destination: localRoleDestination,
  );
}
