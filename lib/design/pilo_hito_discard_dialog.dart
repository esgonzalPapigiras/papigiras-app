import 'package:flutter/material.dart';

import 'pilo_family_theme.dart';

/// One draft guard for the sheet and the full-page composer. Cancelling never
/// changes the draft; a partial upload must not be presented as a fresh draft.
class PiloHitoDiscardDialog extends StatelessWidget {
  const PiloHitoDiscardDialog({super.key, this.partial = false});

  final bool partial;

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: AlertDialog(
      key: const ValueKey('hito-discard-dialog'),
      backgroundColor: PiloFamilyTheme.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Text(
        partial ? '¿Salir del hito?' : '¿Descartar este hito?',
        style: PiloFamilyTheme.display(26),
      ),
      content: Text(
        partial
            ? 'El envío no terminó por completo. Revisa la bitácora antes de volver a publicar. Los archivos pendientes de este formulario se descartarán.'
            : 'Se perderán los textos, archivos y la ubicación que elegiste para este hito.',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          height: 1.45,
          color: PiloFamilyTheme.secondary,
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: const ValueKey('hito-discard-keep'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Seguir editando'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('hito-discard-confirm'),
                style: TextButton.styleFrom(
                  backgroundColor: PiloFamilyTheme.soft,
                  foregroundColor: PiloFamilyTheme.ink,
                  minimumSize: const Size(48, 48),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(partial ? 'Salir' : 'Descartar'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
