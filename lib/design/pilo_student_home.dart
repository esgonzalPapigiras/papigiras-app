import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pilo_family_theme.dart';

enum PiloStudentMedicalStatus { loading, ready, missing, failed }

/// Student pass and immediate access to read-only emergency information.
/// Owns no navigation, credentials, medical writes, or network requests.
class PiloStudentHome extends StatelessWidget {
  const PiloStudentHome({
    super.key,
    required this.name,
    required this.rut,
    required this.avatar,
    required this.qr,
    required this.onMenu,
    required this.onMedical,
    required this.onRetry,
    required this.medicalStatus,
  });

  final String name;
  final String rut;
  final Widget avatar;
  final Widget qr;
  final VoidCallback onMenu;
  final VoidCallback onMedical;
  final VoidCallback onRetry;
  final PiloStudentMedicalStatus medicalStatus;

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Builder(
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('student-home-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  const SizedBox(height: 24),
                  _pass(context),
                  const SizedBox(height: 16),
                  _medical(context),
                  if (medicalStatus != PiloStudentMedicalStatus.ready) ...[
                    const SizedBox(height: 12),
                    _medicalNotice(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header(BuildContext context) {
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Alumno', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        Semantics(
          header: true,
          child: Text(
            name.isEmpty ? 'Mi perfil' : name,
            style: PiloFamilyTheme.display(32),
          ),
        ),
        if (rut.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('RUT $rut', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
    final menu = IconButton(
      key: const ValueKey('student-menu'),
      tooltip: 'Abrir menú del alumno',
      onPressed: onMenu,
      style: IconButton.styleFrom(
        backgroundColor: PiloFamilyTheme.soft,
        minimumSize: const Size.square(48),
      ),
      icon: const Icon(Icons.menu_rounded, size: 26),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(17) > 25.5;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox.square(dimension: 64, child: avatar),
                  const Spacer(),
                  menu,
                ],
              ),
              const SizedBox(height: 16),
              identity,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(dimension: 64, child: avatar),
            const SizedBox(width: 14),
            Expanded(child: identity),
            const SizedBox(width: 8),
            menu,
          ],
        );
      },
    );
  }

  Widget _pass(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: PiloFamilyTheme.ink,
      borderRadius: BorderRadius.circular(PiloFamilyTheme.cardRadius),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Mi pase',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: PiloFamilyTheme.paper,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.qr_code_rounded, color: PiloFamilyTheme.mint),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(218.0, constraints.maxWidth);
              return Center(
                child: Semantics(
                  image: true,
                  label: 'Código QR de identificación del alumno',
                  child: Container(
                    key: const ValueKey('student-qr-surface'),
                    width: size,
                    height: size,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PiloFamilyTheme.paper,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ExcludeSemantics(child: qr),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Muéstralo al coordinador',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: PiloFamilyTheme.onDark),
          ),
        ],
      ),
    ),
  );

  Widget _medical(BuildContext context) {
    final available = medicalStatus == PiloStudentMedicalStatus.ready;
    return FilledButton(
      key: const ValueKey('student-medical-open'),
      style: FilledButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(88),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        backgroundColor: PiloFamilyTheme.mint,
        foregroundColor: PiloFamilyTheme.ink,
        disabledBackgroundColor: PiloFamilyTheme.soft,
        disabledForegroundColor: PiloFamilyTheme.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: available ? onMedical : null,
      child: Row(
        children: [
          const Icon(Icons.medical_information_outlined, size: 29),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ficha médica',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Sólo lectura',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: available
                        ? PiloFamilyTheme.ink
                        : PiloFamilyTheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 25),
        ],
      ),
    );
  }

  Widget _medicalNotice() {
    switch (medicalStatus) {
      case PiloStudentMedicalStatus.loading:
        return const _Notice(
          title: 'Consultando tu ficha médica…',
          loading: true,
        );
      case PiloStudentMedicalStatus.missing:
        return _Notice(
          title: 'Ficha aún no cargada',
          subtitle: 'Tu apoderado puede completarla desde su perfil.',
          action: 'Actualizar',
          onAction: onRetry,
        );
      case PiloStudentMedicalStatus.failed:
        return _Notice(
          title: 'No pudimos cargar la ficha',
          subtitle: 'Vuelve a intentarlo para abrirla.',
          action: 'Reintentar',
          onAction: onRetry,
        );
      case PiloStudentMedicalStatus.ready:
        return const SizedBox.shrink();
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.title,
    this.subtitle,
    this.loading = false,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final bool loading;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (loading) ...[
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: PiloFamilyTheme.accentText,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(action!),
            ),
          ],
        ],
      ),
    ),
  );
}
