import 'package:papigiras_app/design/special_diet_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/design/apple_design_trial.dart';
import 'package:papigiras_app/design/coordinator_home_style.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';

/// PG-023: read-only counts supplied for the coordinator's assigned tour.
class SpecialDietsSummary extends StatelessWidget {
  const SpecialDietsSummary({super.key, required this.counts, this.onOpen});
  final Map<String, int>? counts;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final pilo = PiloFamilyTheme.isActive(context);
    final total = counts?.values.fold<int>(0, (sum, count) => sum + count);
    final active = pilo ? PiloFamilyTheme.ink : AppleTrialColors.accent;
    final inactive = pilo
        ? PiloFamilyTheme.secondary
        : AppleTrialColors.secondary;
    return Tooltip(
      message: total == null
          ? 'Conteo de dietas no disponible'
          : 'Ver pasajeros con dietas especiales',
      child: Semantics(
        button: true,
        enabled: total != null && onOpen != null,
        child: InkWell(
          key: const ValueKey('home-special-diets'),
          onTap: total == null ? null : onOpen,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const SpecialDietIcon(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dietas especiales',
                      style: CoordinatorHomeStyle.rowLabel(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    total?.toString() ?? '—',
                    key: const ValueKey('home-special-diets-total'),
                    semanticsLabel: total == null
                        ? 'Cantidad no disponible'
                        : '$total pasajeros',
                    style: CoordinatorHomeStyle.statistic(context),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    pilo
                        ? Icons.arrow_forward_rounded
                        : CupertinoIcons.chevron_right,
                    size: pilo ? 20 : 16,
                    color: total == null ? inactive : active,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
