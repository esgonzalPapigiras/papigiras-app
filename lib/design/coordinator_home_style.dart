import 'package:flutter/material.dart';

/// PG-025: visual measurements shared only by the coordinator home summary.
/// Font families come from AppleDesignTrialScope, with system text scaling.
abstract final class CoordinatorHomeStyle {
  static const contentInset = 20.0;
  static const sectionSpacing = 16.0;
  static const panelRadius = 16.0;
  static const leadingSize = 32.0;
  static const panelColor = Color(0xFFF6F7F7);

  static TextStyle identity(BuildContext context) => Theme.of(context)
      .textTheme
      .titleMedium!
      .copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25);

  static TextStyle tripTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -.25,
      );

  static TextStyle statistic(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.15,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle rowLabel(BuildContext context) => Theme.of(context)
      .textTheme
      .bodyMedium!
      .copyWith(fontSize: 15, fontWeight: FontWeight.w500, height: 1.25);

  static TextStyle actionLabel(BuildContext context, {required bool primary}) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: primary ? 17 : 14,
        fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
        height: 1.25,
      );
}
