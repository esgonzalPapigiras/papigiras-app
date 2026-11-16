import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../design/apple_design_trial.dart';
import '../design/pilo_family_theme.dart';
import '../utils/page_navigation.dart';

enum FamilySection { home, crew, documents, diary, map, gallery }

/// PG-037: one navigation bar outside the section navigators. Each section is
/// created on first visit and retains its routes, scroll and unsaved form state.
class FamilyNavigation extends StatefulWidget {
  const FamilyNavigation({
    super.key,
    required this.builders,
    this.onMapRequested,
    this.onMapOpened,
    this.pilo = false,
    this.immersiveMap = false,
    this.coordinatorTools = false,
  });
  final Map<FamilySection, WidgetBuilder> builders;
  final ValueChanged<int>? onMapRequested;
  final VoidCallback? onMapOpened;
  final bool pilo;
  final bool immersiveMap;

  /// Coordinator home exposes its map preview, leaving a dock slot for files.
  /// Opt-in keeps the family's existing four destinations unchanged.
  final bool coordinatorTools;
  @override
  State<FamilyNavigation> createState() => FamilyNavigationState();
}

class FamilyNavigationScope extends InheritedWidget {
  const FamilyNavigationScope({
    super.key,
    required this.navigation,
    required this.selected,
    required this.builders,
    required super.child,
  });
  final FamilyNavigationState navigation;
  final FamilySection selected;
  final Map<FamilySection, WidgetBuilder> builders;
  static FamilyNavigationState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FamilyNavigationScope>()
      ?.navigation;
  @override
  bool updateShouldNotify(FamilyNavigationScope oldWidget) =>
      oldWidget.selected != selected ||
      oldWidget.navigation != navigation ||
      !identical(oldWidget.builders, builders);
}

/// The section Navigator retains this root and its page state. Read the current
/// factory through the scope instead of freezing the first factory in a route.
class _SectionRoot extends StatelessWidget {
  const _SectionRoot({required this.section});

  final FamilySection section;

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<FamilyNavigationScope>()!;
    return scope.builders[section]!(context);
  }
}

class FamilyNavigationState extends State<FamilyNavigation> {
  FamilySection _selected = FamilySection.home;
  FamilySection _mapReturn = FamilySection.home;
  FamilySection get selected => _selected;
  final _visited = <FamilySection>{FamilySection.home};
  final _keys = {
    for (final section in FamilySection.values)
      section: GlobalKey<NavigatorState>(),
  };
  late final _observers = {
    for (final section in FamilySection.values)
      section: _SectionObserver(() => _navigationChanged(section)),
  };
  final _handlesPop = <FamilySection, bool>{};
  bool _backInProgress = false;

  // This is deliberately outside all section navigators: signing out must
  // dispose the entire journey, including every cached page and media player.
  NavigatorState get sessionNavigator => Navigator.of(context);

  void select(FamilySection section) => _select(section);

  void _select(FamilySection section, {int? hitoId}) {
    if (_observers[_selected]!.hasPopup || section == _selected) return;
    final current = _observers[_selected]!.current;
    if (current?.willHandlePopInternally ?? false) {
      _keys[_selected]!.currentState?.pop();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      if (section == FamilySection.map) _mapReturn = _selected;
      _selected = section;
      _visited.add(section);
    });
    if (section == FamilySection.map && hitoId == null) {
      widget.onMapOpened?.call();
    }
  }

  void openMap(int hitoId) {
    _select(FamilySection.map, hitoId: hitoId);
    widget.onMapRequested?.call(hitoId);
  }

  Future<void> back() async {
    if (_backInProgress) return;
    _backInProgress = true;
    final origin = _selected;
    try {
      // maybePop respects PopScope (medical edits) and local history (drawer).
      final handled = await _keys[origin]!.currentState?.maybePop() ?? false;
      if (mounted && !handled && _selected == origin) {
        select(
          widget.immersiveMap && origin == FamilySection.map
              ? _mapReturn
              : FamilySection.home,
        );
      }
    } finally {
      _backInProgress = false;
    }
  }

  void _navigationChanged(FamilySection section) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && section == _selected) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => AppleDesignTrialScope(
    child: Builder(
      builder: (context) => widget.pilo
          ? Theme(
              data: PiloFamilyTheme.theme(Theme.of(context)),
              child: _journey(),
            )
          : _journey(),
    ),
  );

  Widget _journey() => FamilyNavigationScope(
    navigation: this,
    selected: _selected,
    builders: widget.builders,
    child: PopScope<Object?>(
      canPop:
          _selected == FamilySection.home && !(_handlesPop[_selected] ?? false),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _selected.index,
          children: [
            for (final section in FamilySection.values)
              if (!_visited.contains(section))
                const SizedBox.shrink()
              else
                TickerMode(
                  enabled: section == _selected,
                  child: ExcludeFocus(
                    excluding: section != _selected,
                    child: NotificationListener<NavigationNotification>(
                      onNotification: (notification) {
                        final changed =
                            _handlesPop[section] != notification.canHandlePop;
                        _handlesPop[section] = notification.canHandlePop;
                        if (changed) _navigationChanged(section);
                        return true;
                      },
                      child: Navigator(
                        key: _keys[section],
                        observers: [_observers[section]!],
                        onGenerateRoute: (_) =>
                            buildPapiRoute(_SectionRoot(section: section)),
                      ),
                    ),
                  ),
                ),
          ],
        ),
        bottomNavigationBar:
            widget.immersiveMap && _selected == FamilySection.map
            ? null
            : FamilyNavigationBar(
                pilo: widget.pilo,
                coordinatorTools: widget.coordinatorTools,
                selected: _selected,
                onSelected: _observers[_selected]!.hasPopup ? null : select,
              ),
      ),
    ),
  );
}

class _SectionObserver extends NavigatorObserver {
  _SectionObserver(this.changed);
  final VoidCallback changed;
  final _routes = <Route<dynamic>>[];
  Route<dynamic>? get current => _routes.isEmpty ? null : _routes.last;
  bool get hasPopup => _routes.isNotEmpty && _routes.last is PopupRoute;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    changed();
  }
}

class FamilyNavigationBar extends StatelessWidget {
  const FamilyNavigationBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.pilo = false,
    this.coordinatorTools = false,
  });
  final FamilySection selected;
  final ValueChanged<FamilySection>? onSelected;
  final bool pilo;
  final bool coordinatorTools;
  static const items = [
    (
      FamilySection.crew,
      'Tripulación',
      CupertinoIcons.bus,
      Icons.directions_bus_outlined,
    ),
    (
      FamilySection.documents,
      'Documentos',
      CupertinoIcons.folder,
      Icons.folder_outlined,
    ),
    (
      FamilySection.diary,
      'Bitácora',
      CupertinoIcons.book,
      Icons.menu_book_outlined,
    ),
    (FamilySection.map, 'Mapa', CupertinoIcons.map, Icons.map_outlined),
    (
      FamilySection.gallery,
      'Galería',
      CupertinoIcons.photo_on_rectangle,
      Icons.photo_library_outlined,
    ),
  ];

  static const _piloItems = [
    (FamilySection.home, 'Inicio', Icons.home_rounded),
    (FamilySection.diary, 'Bitácora', Icons.auto_stories_rounded),
    (FamilySection.map, 'Mapa', Icons.map_rounded),
    (FamilySection.gallery, 'Galería', Icons.photo_library_rounded),
  ];

  static const _coordinatorPiloItems = [
    (FamilySection.home, 'Inicio', Icons.home_rounded),
    (FamilySection.diary, 'Bitácora', Icons.auto_stories_rounded),
    (FamilySection.gallery, 'Galería', Icons.photo_library_rounded),
    (FamilySection.documents, 'Documentos', Icons.folder_open_rounded),
  ];

  Widget _piloBar(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 500;
    final dockItems = coordinatorTools ? _coordinatorPiloItems : _piloItems;
    final visibleSelection = dockItems.any((item) => item.$1 == selected)
        ? selected
        : FamilySection.home;
    return Material(
      key: const ValueKey('family-navigation-bar'),
      color: PiloFamilyTheme.paper,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: LayoutBuilder(
            builder: (context, bounds) {
              const gap = 7.0;
              final diameter = ((bounds.maxWidth - 3 * gap) / 4).clamp(
                44.0,
                compact ? 52.0 : 92.0,
              );
              final showLabels =
                  !compact &&
                  MediaQuery.textScalerOf(context).scale(11) < diameter * .19;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (index, item) in dockItems.indexed) ...[
                    if (index > 0) const SizedBox(width: gap),
                    Semantics(
                      label: item.$2,
                      button: true,
                      enabled: onSelected != null,
                      selected: item.$1 == visibleSelection,
                      onTap: onSelected == null
                          ? null
                          : () => onSelected!(item.$1),
                      child: Tooltip(
                        message: item.$2,
                        excludeFromSemantics: true,
                        child: ExcludeSemantics(
                          child: SizedBox.square(
                            dimension: diameter,
                            child: TextButton(
                              key: ValueKey('family-tab-${item.$1.name}'),
                              onPressed: onSelected == null
                                  ? null
                                  : () => onSelected!(item.$1),
                              style: TextButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                                backgroundColor: item.$1 == visibleSelection
                                    ? PiloFamilyTheme.mint
                                    : PiloFamilyTheme.dockIdle,
                                foregroundColor: PiloFamilyTheme.ink,
                                disabledBackgroundColor: PiloFamilyTheme.soft,
                                disabledForegroundColor:
                                    PiloFamilyTheme.secondary,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(item.$3, size: 23),
                                  if (showLabels) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        height: 1.15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pilo) return _piloBar(context);
    final platform = Theme.of(context).platform;
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final largeText = MediaQuery.textScalerOf(context).scale(11) > 17;
    return Material(
      key: const ValueKey('family-navigation-bar'),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1, thickness: .5, color: Color(0xFFE3E7E6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
              child: Row(
                children: [
                  for (final item in items)
                    Expanded(
                      child: Semantics(
                        label: item.$2,
                        button: true,
                        selected: selected == item.$1,
                        enabled: onSelected != null,
                        onTap: onSelected == null
                            ? null
                            : () => onSelected!(item.$1),
                        child: Tooltip(
                          message: item.$2,
                          excludeFromSemantics: true,
                          child: ExcludeSemantics(
                            child: TextButton(
                              key: ValueKey('family-tab-${item.$1.name}'),
                              onPressed: onSelected == null
                                  ? null
                                  : () => onSelected!(item.$1),
                              style: TextButton.styleFrom(
                                foregroundColor: AppleTrialColors.accent,
                                disabledForegroundColor:
                                    AppleTrialColors.secondary,
                                minimumSize: const Size(48, 58),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                  vertical: 7,
                                ),
                                backgroundColor: selected == item.$1
                                    ? const Color(0xFFE7F3EF)
                                    : Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(apple ? item.$3 : item.$4, size: 24),
                                  if (!largeText) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      item.$2,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.2,
                                        letterSpacing: -.2,
                                        fontWeight: selected == item.$1
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: AppleTrialColors.ink,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
