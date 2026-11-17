import 'package:flutter/material.dart';

/// Visual tokens adapted from the Pilo review branch.
///
/// This file intentionally contains no networking, session, notification, or
/// platform behavior so it can be adopted by the production application
/// without changing its integrations.
abstract final class PapigirasColors {
  static const canvas = Color(0xFFF8F6EE);
  static const surface = Color(0xFFFFFDF7);
  static const ink = Color(0xFF17332F);
  static const mint = Color(0xFF51C7B5);
  static const onMint = Color(0xFF0B3631);
  static const teal = Color(0xFF1D8378);
  static const muted = Color(0xFF566F69);
  static const line = Color(0xFFDBE8E3);
  static const soft = Color(0xFFE9F5F1);
  static const danger = Color(0xFFB42318);
}

ThemeData buildPapigirasTheme() {
  const scheme = ColorScheme.light(
    primary: PapigirasColors.teal,
    onPrimary: Colors.white,
    primaryContainer: PapigirasColors.mint,
    onPrimaryContainer: PapigirasColors.onMint,
    secondary: PapigirasColors.teal,
    onSecondary: Colors.white,
    secondaryContainer: PapigirasColors.soft,
    onSecondaryContainer: PapigirasColors.ink,
    surface: PapigirasColors.surface,
    onSurface: PapigirasColors.ink,
    onSurfaceVariant: PapigirasColors.muted,
    outline: PapigirasColors.muted,
    outlineVariant: PapigirasColors.line,
    error: PapigirasColors.danger,
    onError: Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final textTheme = base.textTheme
      .apply(
        bodyColor: PapigirasColors.ink,
        displayColor: PapigirasColors.ink,
      )
      .copyWith(
        displaySmall: const TextStyle(
          fontSize: 48,
          height: 1.02,
          fontWeight: FontWeight.w500,
          letterSpacing: -1.8,
          color: PapigirasColors.ink,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
          color: PapigirasColors.ink,
        ),
        titleLarge: const TextStyle(
          fontSize: 21,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: PapigirasColors.ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: PapigirasColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontSize: 17,
          height: 1.4,
          color: PapigirasColors.ink,
        ),
        bodyMedium: const TextStyle(
          fontSize: 15,
          height: 1.4,
          color: PapigirasColors.ink,
        ),
        bodySmall: const TextStyle(
          fontSize: 13,
          height: 1.35,
          color: PapigirasColors.muted,
        ),
        labelLarge: const TextStyle(
          fontSize: 16,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      );
  final roundedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  return base.copyWith(
    scaffoldBackgroundColor: PapigirasColors.canvas,
    canvasColor: PapigirasColors.canvas,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: PapigirasColors.canvas,
      foregroundColor: PapigirasColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PapigirasColors.mint,
        foregroundColor: PapigirasColors.onMint,
        disabledBackgroundColor: PapigirasColors.line,
        disabledForegroundColor: PapigirasColors.muted,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: roundedShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PapigirasColors.mint,
        foregroundColor: PapigirasColors.onMint,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: roundedShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PapigirasColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PapigirasColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PapigirasColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PapigirasColors.teal, width: 2),
      ),
      labelStyle: const TextStyle(color: PapigirasColors.muted),
      hintStyle: const TextStyle(color: PapigirasColors.muted),
    ),
    cardTheme: CardThemeData(
      color: PapigirasColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: roundedShape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PapigirasColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: const DividerThemeData(
      color: PapigirasColors.line,
      thickness: 1,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: PapigirasColors.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PapigirasColors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PapigirasColors.teal,
    ),
  );
}
