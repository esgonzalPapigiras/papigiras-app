import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../design/apple_design_trial.dart';
import '../design/pilo_family_theme.dart';

/// Shared presentation only. Visibility and file operations stay in each role.
class DocumentsPageHeader extends StatelessWidget {
  const DocumentsPageHeader({super.key, this.onRefresh, this.onAdd});
  final VoidCallback? onRefresh;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Semantics(
            header: true,
            child: Text(
              'Documentos',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
      ),
      IconButton(
        key: const ValueKey('documents-refresh'),
        tooltip: 'Actualizar documentos',
        onPressed: onRefresh,
        icon: const Icon(CupertinoIcons.arrow_clockwise),
        color: AppleTrialColors.accent,
      ),
      if (onAdd != null)
        IconButton.filled(
          key: const ValueKey('documents-add'),
          tooltip: 'Agregar documento',
          onPressed: onAdd,
          style: IconButton.styleFrom(
            backgroundColor: AppleTrialColors.accent,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(CupertinoIcons.plus),
        ),
    ],
  );
}

class DocumentSectionHeading extends StatelessWidget {
  const DocumentSectionHeading(this.title, {super.key, this.private = false});
  final String title;
  final bool private;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (private)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 6),
                  child: Icon(
                    CupertinoIcons.lock,
                    size: 15,
                    color: AppleTrialColors.secondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Solo coordinación y administración',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class DocumentListMessage extends StatelessWidget {
  const DocumentListMessage({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.large = false,
  });
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final bool large;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      vertical: large ? 48 : 16,
      horizontal: large ? 12 : 0,
    ),
    child: Column(
      crossAxisAlignment: large
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (large) ...[
          Icon(
            onRetry == null
                ? CupertinoIcons.folder
                : CupertinoIcons.exclamationmark_circle,
            color: AppleTrialColors.secondary,
            size: 38,
          ),
          const SizedBox(height: 16),
        ],
        Text(
          title,
          textAlign: large ? TextAlign.center : TextAlign.start,
          style: large
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.bodyMedium,
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: large ? TextAlign.center : TextAlign.start,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppleTrialColors.secondary),
          ),
        ],
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(CupertinoIcons.arrow_clockwise, size: 18),
            label: const Text('Reintentar'),
          ),
      ],
    ),
  );
}

class PapiDocumentTile extends StatelessWidget {
  const PapiDocumentTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = CupertinoIcons.doc_text,
    this.busy = false,
    this.onView,
    this.onSave,
    this.pilo = false,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool busy;
  final bool pilo;
  final VoidCallback? onView, onSave;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final actionColor = pilo ? PiloFamilyTheme.ink : AppleTrialColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: pilo ? PiloFamilyTheme.soft : AppleTrialColors.background,
        borderRadius: BorderRadius.circular(pilo ? 28 : 18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(17) > 23;
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Preparando documento',
                          ),
                        ),
                      ),
                    )
                  else ...[
                    if (onView != null)
                      IconButton(
                        tooltip: 'Ver documento',
                        onPressed: onView,
                        icon: Icon(
                          pilo ? Icons.north_east_rounded : CupertinoIcons.eye,
                          size: 23,
                        ),
                        color: actionColor,
                        style: pilo
                            ? IconButton.styleFrom(
                                backgroundColor: PiloFamilyTheme.paper,
                                minimumSize: const Size(48, 48),
                              )
                            : null,
                      ),
                    if (pilo && onView != null) const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Guardar documento',
                      color: actionColor,
                      onPressed: onSave,
                      icon: const Icon(
                        CupertinoIcons.arrow_down_to_line,
                        size: 23,
                      ),
                      style: pilo
                          ? IconButton.styleFrom(
                              backgroundColor: PiloFamilyTheme.paper,
                              minimumSize: const Size(48, 48),
                            )
                          : null,
                    ),
                  ],
                ],
              );
              if (pilo) {
                // Give the complete filename its own row without competing
                // with the action buttons for space.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: text.bodyMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.22,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            icon,
                            size: 20,
                            color: PiloFamilyTheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(subtitle ?? '', style: text.bodySmall),
                        ),
                        const SizedBox(width: 4),
                        actions,
                      ],
                    ),
                  ],
                );
              }
              final fileIcon = ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1EFEB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 26, color: actionColor),
                ),
              );
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  if (subtitle?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(subtitle!, style: text.bodySmall),
                    ),
                ],
              );
              final identity = Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  fileIcon,
                  const SizedBox(width: 12),
                  Expanded(child: titleBlock),
                ],
              );
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 4),
                        Align(alignment: Alignment.centerRight, child: actions),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 4),
                        actions,
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}

String publicDocumentTitle(String type) => type.trim().isEmpty
    ? 'Documento de la gira'
    : switch (type.trim()) {
        'gira' => 'Gira',
        'poliza' => 'Póliza',
        'hotel' => 'Hotel',
        'extra' => 'Documento adicional',
        _ => type.trim(),
      };

/// Only show a format when the existing filename actually supplies it.
String? documentFormatLabel(String? name) {
  final extension = (name ?? '').split('.').last.toLowerCase();
  return switch (extension) {
    'pdf' => 'PDF',
    'doc' || 'docx' => 'Word',
    'xls' || 'xlsx' => 'Excel',
    'jpg' || 'jpeg' || 'png' || 'webp' => 'Imagen',
    _ => null,
  };
}
