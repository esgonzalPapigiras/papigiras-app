import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// PG-018: temporary visual trial, scoped only to the two reviewed screens.
/// No global theme, navigation, API or persistence changes.
abstract final class AppleTrialColors {
  static const background = Color(0xFFF2F4F3);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF17332F);
  static const secondary = Color(0xFF546760);
  static const accent = Color(0xFF087C70);
  static const line = Color(0xFFDDE4E0);
}

class AppleDesignTrialScope extends StatelessWidget {
  const AppleDesignTrialScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final parent = Theme.of(context);
    final apple =
        parent.platform == TargetPlatform.iOS ||
        parent.platform == TargetPlatform.macOS;
    // Resolve Apple's system type on Apple platforms, without bundling fonts.
    // Android retains Flutter's Roboto. Font scaling is never clamped.
    final family = apple
        ? const CupertinoThemeData().textTheme.textStyle.fontFamily
        : 'Roboto';
    final text = parent.textTheme.apply(
      fontFamily: family,
      bodyColor: AppleTrialColors.ink,
      displayColor: AppleTrialColors.ink,
    );
    final theme = parent.copyWith(
      scaffoldBackgroundColor: AppleTrialColors.background,
      colorScheme: parent.colorScheme.copyWith(
        primary: AppleTrialColors.accent,
        onPrimary: AppleTrialColors.surface,
        surface: AppleTrialColors.surface,
        onSurface: AppleTrialColors.ink,
        onSurfaceVariant: AppleTrialColors.secondary,
        outlineVariant: AppleTrialColors.line,
      ),
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 1.35),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.35),
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 13,
          color: AppleTrialColors.secondary,
          height: 1.3,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: parent.appBarTheme.copyWith(
        backgroundColor: AppleTrialColors.background,
        foregroundColor: AppleTrialColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: text.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: AppleTrialColors.line,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: text.titleMedium?.copyWith(fontSize: 17),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppleTrialColors.accent,
          side: const BorderSide(color: AppleTrialColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: text.titleMedium?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
    return Theme(
      data: theme,
      child: DefaultTextStyle(style: theme.textTheme.bodyMedium!, child: child),
    );
  }
}
