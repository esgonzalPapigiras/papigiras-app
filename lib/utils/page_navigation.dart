import 'package:flutter/material.dart';

/// Page changes are immediate. Animations inside pages and modal controls keep
/// their own behavior; this policy only replaces route transitions.
class PapiInstantPageTransitions extends PageTransitionsBuilder {
  const PapiInstantPageTransitions();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

const papiPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: PapiInstantPageTransitions(),
    TargetPlatform.iOS: PapiInstantPageTransitions(),
    TargetPlatform.macOS: PapiInstantPageTransitions(),
    TargetPlatform.windows: PapiInstantPageTransitions(),
    TargetPlatform.linux: PapiInstantPageTransitions(),
    TargetPlatform.fuchsia: PapiInstantPageTransitions(),
  },
);

/// Existing custom entry points retain their destinations and navigation stack.
Route<T> buildPapiRoute<T>(Widget destination) => PageRouteBuilder<T>(
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
  pageBuilder: (context, animation, secondaryAnimation) => destination,
);
