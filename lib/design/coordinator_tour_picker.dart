import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'pilo_family_theme.dart';

/// PG-021. Presentation only: the caller owns loading, permissions and selection.
class CoordinatorTourPicker extends StatelessWidget {
  const CoordinatorTourPicker({
    super.key,
    required this.snapshot,
    required this.loadingTourId,
    required this.onSelect,
    required this.onRetry,
    this.onBack,
  });

  final AsyncSnapshot<List<CoordinatorTour>> snapshot;
  final int? loadingTourId;
  final ValueChanged<CoordinatorTour> onSelect;
  final VoidCallback onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final parent = Theme.of(context);
    final colors = _PickerColors(parent.brightness == Brightness.dark);
    final pilo = PiloFamilyTheme.theme(parent);
    final text = pilo.textTheme.apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
    );
    return Theme(
      data: pilo.copyWith(
        textTheme: text,
        colorScheme: pilo.colorScheme.copyWith(
          primary: colors.accent,
          surface: colors.background,
          onSurface: colors.ink,
        ),
      ),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: CustomScrollView(
                key: const PageStorageKey('coordinator-tour-list'),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (onBack != null) ...[
                            IconButton(
                              tooltip: 'Volver',
                              style: IconButton.styleFrom(
                                backgroundColor: colors.surface,
                                foregroundColor: colors.ink,
                              ),
                              onPressed: onBack,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Semantics(
                            header: true,
                            child: Text(
                              'Selecciona una gira',
                              style: PiloFamilyTheme.display(
                                50,
                                color: colors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ..._content(context, colors, text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    _PickerColors colors,
    TextTheme text,
  ) {
    final waiting = snapshot.connectionState == ConnectionState.waiting;
    final tours = snapshot.data ?? const <CoordinatorTour>[];
    if (waiting || snapshot.hasError || tours.isEmpty) {
      final message = waiting
          ? 'Cargando tus giras…'
          : snapshot.hasError
          ? 'No pudimos cargar tus giras.'
          : 'No tienes giras asignadas.';
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (waiting) _progress(context, colors.accent),
                if (waiting) const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(fontSize: 17),
                  ),
                ),
                if (!waiting) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.accent,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      snapshot.hasError ? 'Reintentar' : 'Actualizar',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        sliver: SliverList.builder(
          itemCount: tours.length,
          itemBuilder: (context, index) {
            final tour = tours[index];
            final loading = loadingTourId == tour.tourId;
            final enabled = loadingTourId == null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MergeSemantics(
                child: Semantics(
                  key: ValueKey('tour-choice-${tour.tourId}'),
                  button: true,
                  enabled: enabled,
                  child: Material(
                    color: loading
                        ? colors.accent.withValues(alpha: .08)
                        : colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(
                        color: MediaQuery.highContrastOf(context)
                            ? colors.secondary
                            : colors.line,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: enabled ? () => onSelect(tour) : null,
                      focusColor: colors.accent.withValues(alpha: .18),
                      hoverColor: colors.accent.withValues(alpha: .06),
                      highlightColor: colors.accent.withValues(alpha: .10),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tour.clientName,
                                    style: text.titleMedium?.copyWith(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                                  if (tour.course.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      tour.course,
                                      style: text.bodyLarge?.copyWith(
                                        fontSize: 17,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Text(
                                    formatCoordinatorTourDates(
                                      tour.startDate,
                                      tour.endDate,
                                    ),
                                    style: text.bodyMedium?.copyWith(
                                      fontSize: 15,
                                      color: colors.secondary,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Código ${tour.tourCode}',
                                    style: text.bodySmall?.copyWith(
                                      fontSize: 13,
                                      color: colors.secondary,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (loading) ...[
                                    const SizedBox(height: 10),
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        'Abriendo gira…',
                                        style: text.bodyMedium?.copyWith(
                                          fontSize: 15,
                                          color: colors.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ExcludeSemantics(
                              child: loading
                                  ? _progress(context, colors.accent)
                                  : CircleAvatar(
                                      radius: 19,
                                      backgroundColor: colors.background,
                                      foregroundColor: colors.ink,
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _progress(BuildContext context, Color color) => SizedBox.square(
    dimension: 22,
    child: MediaQuery.disableAnimationsOf(context)
        ? Icon(Icons.hourglass_top, color: color, size: 22)
        : CircularProgressIndicator.adaptive(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(color),
          ),
  );
}

/// Localized presentation only. Never changes the received dates or their order.
String formatCoordinatorTourDates(String start, String end) {
  DateTime? parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final date = DateTime.tryParse(value);
    return date != null && date.toIso8601String().startsWith(value)
        ? date
        : null;
  }

  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sept',
    'oct',
    'nov',
    'dic',
  ];
  final from = parse(start), to = parse(end);
  String full(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
  if (from != null && to != null) {
    if (from == to) return full(from);
    if (from.year != to.year) return '${full(from)} – ${full(to)}';
    if (from.month == to.month) return '${from.day}–${full(to)}';
    return '${from.day} ${months[from.month - 1]} – ${full(to)}';
  }
  if (start.isEmpty && end.isEmpty) return 'Fechas no disponibles';
  final left = from == null ? start : full(from);
  final right = to == null ? end : full(to);
  if (start.isEmpty) return 'Hasta $right';
  if (end.isEmpty) return 'Desde $left';
  return '$left – $right';
}

class _PickerColors {
  const _PickerColors(this.dark);
  final bool dark;
  Color get background =>
      dark ? const Color(0xFF111C1A) : PiloFamilyTheme.paper;
  Color get surface => dark ? const Color(0xFF1B2B27) : PiloFamilyTheme.soft;
  Color get ink => dark ? const Color(0xFFF0F6F3) : PiloFamilyTheme.ink;
  Color get secondary =>
      dark ? const Color(0xFFB5C7C0) : PiloFamilyTheme.secondary;
  Color get accent =>
      dark ? const Color(0xFF75D4C3) : PiloFamilyTheme.accentText;
  Color get line => dark ? const Color(0xFF3E534C) : PiloFamilyTheme.soft;
}
