import 'package:flutter/material.dart';
import 'pilo_family_theme.dart';

/// Informational reminder only. The caller keeps control of login/navigation;
/// this dialog never changes a credential or stores a password.
Future<void> showPiloPasswordReminder(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierColor: PiloFamilyTheme.ink.withValues(alpha: .34),
    builder: (dialogContext) => Theme(
      // Login callbacks may originate above the Pilo theme in the widget tree.
      data: PiloFamilyTheme.theme(Theme.of(dialogContext)),
      child: Dialog(
        key: const ValueKey('pilo-password-reminder'),
        backgroundColor: PiloFamilyTheme.paper,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: PiloFamilyTheme.soft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.key_outlined,
                      size: 22,
                      color: PiloFamilyTheme.accentText,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text(
                    'Cuida tu cuenta',
                    style: PiloFamilyTheme.display(27),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Estás usando una contraseña temporal. Te recomendamos cambiarla desde tu perfil para proteger tu cuenta.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    height: 1.45,
                    color: PiloFamilyTheme.secondary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('pilo-password-reminder-continue'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Continuar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
