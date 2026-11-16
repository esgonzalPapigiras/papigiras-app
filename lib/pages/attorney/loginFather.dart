import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_login_form.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/fcm_utils.dart';

import 'fatherWelcome.dart';

class LoginFather extends StatelessWidget {
  const LoginFather({super.key});

  @override
  Widget build(BuildContext context) => PiloLoginForm(
    role: PiloLoginRole.attorney,
    authenticate: (rut, password) async {
      final provider = CoordinatorProviders();
      try {
        final login = await provider.validateLoginUserFather(rut, password);
        if (login == null || login.isActive != true) {
          throw const FormatException(
            'El acceso del apoderado no está disponible.',
          );
        }
        await LabSession.savePassenger(login, 'attorney');
        try {
          await FcmUtils.startForFather(
            login.passengerIdentificacion.toString(),
          ).timeout(const Duration(seconds: 15));
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La sesión se inició, pero no pudimos activar las notificaciones.',
                ),
              ),
            );
          }
        }
        return (
          destination: WelcomeFatherScreen(login: login),
          temporaryPassword: false,
        );
      } finally {
        provider.dispose();
      }
    },
  );
}
