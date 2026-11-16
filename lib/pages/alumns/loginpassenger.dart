import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_login_form.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/pages/attorney/loginFather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

import 'indexpassenger.dart';

class LoginPassenger extends StatelessWidget {
  const LoginPassenger({super.key});

  @override
  Widget build(BuildContext context) => PiloLoginForm(
    role: PiloLoginRole.passenger,
    onOpenAttorney: () => Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginFather()),
    ),
    authenticate: (rut, password) async {
      final provider = CoordinatorProviders();
      try {
        final login = await provider.validateLoginUserPassenger(rut, password);
        if (login == null || login.isActive != true) {
          throw const FormatException(
            'El acceso del alumno no está disponible.',
          );
        }
        await LabSession.savePassenger(login, 'passenger');
        return (
          destination: TravelPassengerDashboard(login: login),
          temporaryPassword: false,
        );
      } finally {
        provider.dispose();
      }
    },
  );
}
