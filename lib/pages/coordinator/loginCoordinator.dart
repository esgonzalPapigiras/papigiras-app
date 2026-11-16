import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_login_form.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

import 'coordinatorTourSelection.dart';

class LoginCoordinator extends StatelessWidget {
  const LoginCoordinator({super.key});

  @override
  Widget build(BuildContext context) => PiloLoginForm(
    role: PiloLoginRole.coordinator,
    authenticate: (rut, password) async {
      final provider = CoordinatorProviders();
      try {
        final coordinator = await provider.loginCoordinator(rut, password);
        await LabSession.saveCoordinator(coordinator);
        return (
          destination: CoordinatorTourSelectionScreen(coordinator: coordinator),
          temporaryPassword: coordinator.mustChangePassword,
        );
      } finally {
        provider.dispose();
      }
    },
  );
}
