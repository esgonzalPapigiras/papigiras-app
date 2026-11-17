import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';

/// Presentation for the coordinator tour list. Loading and selection remain
/// owned by the production screen and provider.
class CoordinatorTourPicker extends StatelessWidget {
  const CoordinatorTourPicker({
    super.key,
    required this.snapshot,
    required this.loadingTourId,
    required this.onSelect,
    required this.onRetry,
  });

  final AsyncSnapshot<List<CoordinatorTour>> snapshot;
  final int? loadingTourId;
  final ValueChanged<CoordinatorTour> onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PapigirasColors.canvas,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CustomScrollView(
              key: const PageStorageKey('coordinator-tour-list'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/logo-letras-papigiras.png',
                          width: 124,
                          semanticLabel: 'PapiGiras',
                        ),
                        const SizedBox(height: 30),
                        Semantics(
                          header: true,
                          child: Text(
                            'Selecciona una gira',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Elige la gira que quieres gestionar.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: PapigirasColors.muted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                ..._content(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final waiting = snapshot.connectionState == ConnectionState.waiting;
    final tours = snapshot.data ?? const <CoordinatorTour>[];
    if (waiting || snapshot.hasError || tours.isEmpty) {
      final message = waiting
          ? 'Cargando tus giras…'
          : snapshot.hasError
              ? 'No pudimos cargar tus giras.'
              : 'No tienes giras activas asignadas.';
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (waiting) _progress(context),
                if (waiting) const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (!waiting) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label:
                        Text(snapshot.hasError ? 'Reintentar' : 'Actualizar'),
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
                  button: true,
                  enabled: enabled,
                  child: Material(
                    color: loading
                        ? PapigirasColors.mint.withValues(alpha: .14)
                        : PapigirasColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: const BorderSide(color: PapigirasColors.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: enabled ? () => onSelect(tour) : null,
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontSize: 19),
                                  ),
                                  if (tour.course.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      tour.course,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Text(
                                    formatCoordinatorTourDates(
                                      tour.startDate,
                                      tour.endDate,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color: PapigirasColors.muted),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Código ${tour.tourCode}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (loading) ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Abriendo gira…',
                                      style: TextStyle(
                                        color: PapigirasColors.teal,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ExcludeSemantics(
                              child: loading
                                  ? _progress(context)
                                  : const CircleAvatar(
                                      radius: 19,
                                      backgroundColor: PapigirasColors.soft,
                                      foregroundColor: PapigirasColors.ink,
                                      child: Icon(
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

  Widget _progress(BuildContext context) {
    return SizedBox.square(
      dimension: 22,
      child: MediaQuery.disableAnimationsOf(context)
          ? const Icon(
              Icons.hourglass_top,
              color: PapigirasColors.teal,
              size: 22,
            )
          : const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// Formats display text only; received API values are never modified.
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
  final from = parse(start);
  final to = parse(end);
  String full(DateTime date) =>
      '${date.day} ${months[date.month - 1]} ${date.year}';
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
