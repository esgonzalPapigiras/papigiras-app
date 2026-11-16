import 'package:flutter/material.dart';

abstract final class PiloFamilyTheme {
  static const mint = Color(0xFF51C7B5);
  static const ink = Color(0xFF111312);
  static const paper = Color(0xFFFFFFFF);
  static const mapBackground = Color(0xFFF1F2F1);
  static const soft = Color(0xFFEFF1F0);
  static const dockIdle = Color(0xFFECEDEC);
  static const secondary = Color(0xFF515958);
  static const onDark = Color(0xFFBDC7C3);
  static const accentText = Color(0xFF166357);
  static const connectorLine = Color(0xFFB9BEBC);
  static const connectorPast = Color(0xFF858C89);
  static const hairline = Color(0xFFD9DDDB);
  static const cardRadius = 40.0;

  static bool isActive(BuildContext context) =>
      Theme.of(context).extension<_PiloFamilyMarker>() != null;

  static TextStyle display(double size, {Color color = ink}) => TextStyle(
    fontFamily: 'Manjari',
    fontSize: size,
    fontWeight: FontWeight.w400,
    letterSpacing: -size * .04,
    height: 1.02,
    color: color,
  );

  static ThemeData theme(ThemeData base) {
    final text = base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: ink,
      displayColor: ink,
    );
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      extensions: [...base.extensions.values, const _PiloFamilyMarker()],
      colorScheme: base.colorScheme.copyWith(
        primary: accentText,
        onPrimary: paper,
        secondary: mint,
        onSecondary: ink,
        surface: paper,
        onSurface: ink,
        onSurfaceVariant: secondary,
        outlineVariant: soft,
      ),
      textTheme: text.copyWith(
        displaySmall: display(50),
        headlineSmall: display(34),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -.45,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -.22,
        ),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 1.3),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.35),
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 13,
          color: secondary,
          height: 1.32,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: soft,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: mint,
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: ink,
        ),
      ),
    );
  }
}

class _PiloFamilyMarker extends ThemeExtension<_PiloFamilyMarker> {
  const _PiloFamilyMarker();

  @override
  _PiloFamilyMarker copyWith() => this;

  @override
  _PiloFamilyMarker lerp(
    covariant ThemeExtension<_PiloFamilyMarker>? other,
    double t,
  ) => this;
}

/// Family section header. Keep it in the body to allow its title to grow
/// with system text size.
class PiloSectionBar extends StatelessWidget implements PreferredSizeWidget {
  const PiloSectionBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backTooltip = 'Volver',
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 12),
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final String backTooltip;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;
  final bool compact;

  @override
  Size get preferredSize =>
      Size.fromHeight((subtitle == null ? 128 : 156) - (compact ? 28 : 0));

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null || actions.isNotEmpty) ...[
            Row(
              children: [
                if (onBack != null)
                  IconButton(
                    tooltip: backTooltip,
                    style: IconButton.styleFrom(
                      backgroundColor: PiloFamilyTheme.soft,
                      minimumSize: Size.square(compact ? 48 : 54),
                    ),
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 24),
                  ),
                const Spacer(),
                ...actions,
              ],
            ),
            SizedBox(height: compact ? 8 : 16),
          ],
          Semantics(
            header: true,
            child: Text(
              title,
              style: PiloFamilyTheme.display(compact ? 36 : 50),
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PiloFamilyTheme.secondary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
