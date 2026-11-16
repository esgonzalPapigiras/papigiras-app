import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';

const papiLocale = Locale('es', 'CL');
const papiSupportedLocales = [papiLocale];
const papiLocalizationsDelegates = GlobalMaterialLocalizations.delegates;

/// PapiGiras mobile identity. No assets, fonts or telemetry are fetched at runtime.
abstract final class PapiColors {
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
  static const warning = Color(0xFFFFD25B);
}

ThemeData papiTheme() {
  const scheme = ColorScheme.light(
    primary: PapiColors.teal,
    onPrimary: Colors.white,
    primaryContainer: PapiColors.mint,
    onPrimaryContainer: PapiColors.onMint,
    secondary: PapiColors.teal,
    onSecondary: Colors.white,
    secondaryContainer: PapiColors.soft,
    onSecondaryContainer: PapiColors.ink,
    surface: PapiColors.surface,
    onSurface: PapiColors.ink,
    onSurfaceVariant: PapiColors.muted,
    outline: PapiColors.muted,
    outlineVariant: PapiColors.line,
    error: PapiColors.danger,
    onError: Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = base.textTheme
      .apply(bodyColor: PapiColors.ink, displayColor: PapiColors.ink)
      .copyWith(
        headlineLarge: const TextStyle(
          fontSize: 32,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: PapiColors.ink,
          letterSpacing: -.6,
        ),
        headlineMedium: const TextStyle(
          fontSize: 27,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: PapiColors.ink,
          letterSpacing: -.4,
        ),
        headlineSmall: const TextStyle(
          fontSize: 23,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: PapiColors.ink,
        ),
        titleLarge: const TextStyle(
          fontSize: 21,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: PapiColors.ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: PapiColors.ink,
        ),
        titleSmall: const TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: PapiColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontSize: 17,
          height: 1.5,
          color: PapiColors.ink,
        ),
        bodyMedium: const TextStyle(
          fontSize: 15,
          height: 1.45,
          color: PapiColors.ink,
        ),
        bodySmall: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: PapiColors.muted,
        ),
        labelLarge: const TextStyle(
          fontSize: 16,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  final primaryButton = ElevatedButton.styleFrom(
    backgroundColor: PapiColors.mint,
    foregroundColor: PapiColors.onMint,
    disabledBackgroundColor: PapiColors.line,
    disabledForegroundColor: PapiColors.muted,
    minimumSize: const Size(48, 52),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: shape,
    textStyle: text.labelLarge,
  );
  return base.copyWith(
    scaffoldBackgroundColor: PapiColors.canvas,
    canvasColor: PapiColors.canvas,
    textTheme: text,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: PapiColors.canvas,
      foregroundColor: PapiColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      iconTheme: const IconThemeData(color: PapiColors.ink, size: 24),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
    filledButtonTheme: FilledButtonThemeData(style: primaryButton),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PapiColors.teal,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PapiColors.ink,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: shape,
        side: const BorderSide(color: PapiColors.line),
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: PapiColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PapiColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PapiColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PapiColors.teal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PapiColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PapiColors.danger, width: 2),
      ),
      labelStyle: const TextStyle(color: PapiColors.muted, fontSize: 15),
      hintStyle: const TextStyle(color: PapiColors.muted, fontSize: 15),
      errorMaxLines: 3,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: PapiColors.teal,
      textColor: PapiColors.ink,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      minVerticalPadding: 10,
    ),
    dividerTheme: const DividerThemeData(
      color: PapiColors.line,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: PapiColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PapiColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PapiColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: PapiColors.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PapiColors.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PapiColors.surface,
      indicatorColor: PapiColors.soft,
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium?.copyWith(
          color: PapiColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PapiColors.teal,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: _PapiTransitions(CupertinoPageTransitionsBuilder()),
        TargetPlatform.macOS: _PapiTransitions(
          CupertinoPageTransitionsBuilder(),
        ),
        TargetPlatform.android: _PapiTransitions(ZoomPageTransitionsBuilder()),
        TargetPlatform.linux: _PapiTransitions(
          FadeUpwardsPageTransitionsBuilder(),
        ),
        TargetPlatform.windows: _PapiTransitions(
          FadeUpwardsPageTransitionsBuilder(),
        ),
      },
    ),
  );
}

class _PapiTransitions extends PageTransitionsBuilder {
  const _PapiTransitions(this.delegate);
  final PageTransitionsBuilder delegate;
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : delegate.buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}

class PapiAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PapiAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
  });
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 64,
    automaticallyImplyLeading: showBack,
    leading: showBack && Navigator.canPop(context)
        ? IconButton(
            tooltip: 'Volver',
            icon: const BackButtonIcon(),
            onPressed: () => Navigator.maybePop(context),
          )
        : null,
    title: Semantics(
      header: true,
      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    actions: actions,
  );
}

class PapiSection extends StatelessWidget {
  const PapiSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class PapiEmptyState extends StatelessWidget {
  const PapiEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.onRetry,
  });
  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: PapiColors.teal, size: 32),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: PapiColors.muted),
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ],
    ),
  );
}

class PapiActionRow extends StatelessWidget {
  const PapiActionRow({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.destructive = false,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      icon,
      color: destructive ? PapiColors.danger : PapiColors.teal,
    ),
    title: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: destructive ? PapiColors.danger : PapiColors.ink,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: PapiColors.muted),
          ),
    trailing: onTap == null
        ? null
        : const Icon(Icons.chevron_right, color: PapiColors.muted),
    onTap: onTap,
  );
}

class PapiButton extends StatelessWidget {
  const PapiButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: busy ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: PapiColors.onMint,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 22),
          if (busy || icon != null) const SizedBox(width: 10),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    ),
  );
}

/// Shared layout only: authentication and its validators remain in each screen.
class PapiAccessLayout extends StatelessWidget {
  const PapiAccessLayout({
    super.key,
    required this.title,
    required this.description,
    required this.children,
  });
  final String title;
  final String description;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const PapiAppBar(title: 'PapiGiras'),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/logo-letras-papigiras.png',
                    width: 144,
                    semanticLabel: 'PapiGiras',
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: PapiColors.muted),
                  ),
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
