import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/utils/passenger_roster_data.dart';

/// Presentation-only summary of the assigned tour's existing response.
/// Diets are a subset of passengers, never an extra category in the total.
class PiloCoordinatorSummary extends StatelessWidget {
  const PiloCoordinatorSummary({
    super.key,
    this.detail,
    this.loading = false,
    this.hasError = false,
    this.onOpenDiets,
    this.onRetry,
    this.onOpenPassengers,
  });

  final CoordinatorTourDetail? detail;
  final bool loading;
  final bool hasError;
  final VoidCallback? onOpenDiets;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenPassengers;

  @override
  Widget build(BuildContext context) {
    final counts = detail?.passengerCountsBySex;
    // Older responses default a missing breakdown to {} in the DTO. An empty
    // breakdown cannot establish a zero; explicit zero-valued groups can.
    final available =
        !loading &&
        !hasError &&
        counts != null &&
        counts.isNotEmpty &&
        counts.values.every((value) => value >= 0);
    final total = available
        ? counts.values.fold<int>(0, (sum, value) => sum + value)
        : null;
    final students = available
        ? counts.entries
              .where(
                (entry) =>
                    const {'M', 'F'}.contains(entry.key.trim().toUpperCase()),
              )
              .fold<int>(0, (sum, entry) => sum + entry.value)
        : null;
    final companions = available
        ? rosterCompanionCount(counts, male: true) +
              rosterCompanionCount(counts, male: false)
        : null;
    final unclassified = total == null ? 0 : total - students! - companions!;
    final dietCounts = !loading && !hasError ? detail?.specialDietCounts : null;
    final diets =
        dietCounts != null && dietCounts.values.every((value) => value >= 0)
        ? dietCounts.values.fold<int>(0, (sum, value) => sum + value)
        : null;
    final heading = loading
        ? 'Cargando pasajeros…'
        : hasError
        ? 'Resumen no disponible'
        : total == null
        ? 'Pasajeros · Sin recuento disponible'
        : '$total ${total == 1 ? 'pasajero' : 'pasajeros'} en esta gira';

    return Material(
      color: PiloFamilyTheme.ink,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          13,
          20,
          onOpenPassengers == null ? 15 : 5,
        ),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final scale = MediaQuery.textScalerOf(context);
            final stacked =
                bounds.maxWidth < 240 ||
                scale.scale(12) > 18 ||
                (bounds.maxWidth < 290 && (students ?? 0) >= 1000);
            final values = [
              _stat(
                value: students,
                label: 'Alumnos',
                valueKey: const ValueKey('coordinator-student-total'),
                horizontal: stacked,
              ),
              _stat(
                value: companions,
                label: 'Acompañantes',
                valueKey: const ValueKey('coordinator-companion-total'),
                horizontal: stacked,
              ),
              Tooltip(
                message: diets == null
                    ? 'Conteo de dietas no disponible'
                    : 'Ver pasajeros con dietas especiales',
                child: Semantics(
                  button: true,
                  enabled: onOpenDiets != null,
                  child: InkWell(
                    key: const ValueKey('home-special-diets'),
                    onTap: onOpenDiets,
                    borderRadius: BorderRadius.circular(12),
                    child: _stat(
                      value: diets,
                      label: 'Con dieta especial',
                      valueKey: const ValueKey('home-special-diets-total'),
                      accent: true,
                      horizontal: stacked,
                      showArrow: onOpenDiets != null,
                    ),
                  ),
                ),
              ),
            ];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        heading,
                        key: const ValueKey('coordinator-passenger-total'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.3,
                          color: PiloFamilyTheme.paper,
                        ),
                      ),
                    ),
                    if (hasError && onRetry != null)
                      IconButton(
                        key: const ValueKey('coordinator-summary-retry'),
                        onPressed: onRetry,
                        tooltip: 'Reintentar recuento',
                        color: PiloFamilyTheme.mint,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                if (stacked)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < values.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            color: Color(0xFF414743),
                            height: 17,
                            thickness: 1,
                          ),
                        values[i],
                      ],
                    ],
                  )
                else
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 8, child: values[0]),
                        _divider(),
                        Expanded(flex: 12, child: values[1]),
                        _divider(),
                        Expanded(flex: 11, child: values[2]),
                      ],
                    ),
                  ),
                if (unclassified > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '$unclassified sin clasificar',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: PiloFamilyTheme.onDark,
                    ),
                  ),
                ],
                if (loading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: PiloFamilyTheme.mint,
                    backgroundColor: Color(0xFF414743),
                    semanticsLabel: 'Cargando resumen de pasajeros',
                  ),
                ],
                if (onOpenPassengers != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFF414743)),
                  InkWell(
                    key: const ValueKey('home-passenger-list'),
                    onTap: onOpenPassengers,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.medical_information_outlined,
                            size: 19,
                            color: PiloFamilyTheme.mint,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Nómina y fichas médicas',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                                color: PiloFamilyTheme.paper,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: PiloFamilyTheme.paper,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 12),
    child: VerticalDivider(color: Color(0xFF414743), width: 1, thickness: 1),
  );

  Widget _stat({
    required int? value,
    required String label,
    required Key valueKey,
    required bool horizontal,
    bool accent = false,
    bool showArrow = false,
  }) {
    final number = Text(
      value?.toString() ?? '—',
      key: valueKey,
      semanticsLabel: value == null ? 'Cantidad no disponible' : '$value',
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -.9,
        height: 1,
        color: accent ? PiloFamilyTheme.mint : PiloFamilyTheme.paper,
      ),
    );
    final caption = Text(
      label,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        height: 1.3,
        color: Color(0xFFE1E5E2),
      ),
    );
    const arrow = Icon(
      Icons.chevron_right_rounded,
      size: 14,
      color: PiloFamilyTheme.onDark,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: horizontal
          ? Wrap(
              spacing: 14,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                number,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: caption),
                    if (showArrow) ...[const SizedBox(width: 3), arrow],
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                number,
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(child: caption),
                    if (showArrow) ...[const SizedBox(width: 3), arrow],
                  ],
                ),
              ],
            ),
    );
  }
}
