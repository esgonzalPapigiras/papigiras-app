import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/lab/map_basemap.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'package:papigiras_app/maps/pilo_hito_location_picker.dart';
import 'package:papigiras_app/maps/pilo_map_area_carousel.dart';
import 'package:papigiras_app/maps/trip_hito_sheet.dart';
import 'package:papigiras_app/maps/trip_hito_markers.dart';
import 'package:papigiras_app/maps/trip_bus_controller.dart';
import 'package:papigiras_app/maps/trip_bus_marker.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'trip_map_nearby_navigation.dart';

/// Both sizes share the same controller, event selection and detail requests.
class TripMapView extends StatefulWidget {
  const TripMapView({
    super.key,
    required this.controller,
    this.expanded = false,
    this.preview = false,
    this.onExpand,
    this.initialHitoId,
    this.edgeToEdge = false,
    this.onLocateCoordinator,
    this.emptyMapCenter,
    this.onCreateHitoAt,
    this.onOpenHito,
    this.onPlacingLocationChanged,
    this.bottomAction,
    this.showHitoList = true,
  });
  final TripMapController controller;
  final bool expanded;
  final bool preview;
  final VoidCallback? onExpand;
  final int? initialHitoId;
  final bool edgeToEdge;
  final bool showHitoList;

  /// Optional coordinator capabilities. Family maps never receive them.
  final Future<LatLng> Function()? onLocateCoordinator;
  final LatLng? emptyMapCenter;
  final Future<void> Function(LatLng point)? onCreateHitoAt;
  final ValueChanged<TripMapEntry>? onOpenHito;
  final ValueChanged<bool>? onPlacingLocationChanged;

  /// Optional coordinator action, attached above the map's bottom card.
  final Widget? bottomAction;

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  final _visibilityOwner = Object();
  final _floatingCard = GlobalKey();

  double _coveredMapHeight() {
    final box = _floatingCard.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.height : 0;
  }

  TripMapController get controller => widget.controller;
  bool get expanded => widget.expanded;
  VoidCallback? get onExpand => widget.onExpand;
  TripMapNearbyNavigation _nearby = TripMapNearbyNavigation();
  MapCamera? _pendingCamera;
  List<TripMapEntry> _visibleEntries = const [];
  List<int> _areaHitoIds = const [];
  bool _pendingUserMove = false;
  bool _viewportScheduled = false;
  LatLng? _draftPoint;
  bool _creatingAtPoint = false;

  Widget _bottomAction({bool safeBottom = false}) => SafeArea(
    top: false,
    bottom: safeBottom,
    minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Align(
      alignment: Alignment.center,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: widget.bottomAction!,
      ),
    ),
  );

  Widget _withLoadingAction(Widget status) {
    if (widget.bottomAction == null) return status;
    return Stack(
      fit: StackFit.expand,
      children: [
        status,
        Align(
          alignment: Alignment.bottomCenter,
          child: _bottomAction(safeBottom: true),
        ),
      ],
    );
  }

  void _placePoint(LatLng point) {
    if (_creatingAtPoint ||
        widget.onCreateHitoAt == null ||
        !HitoLocationDraft.isValidPoint(point))
      return;
    final starting = _draftPoint == null;
    setState(() => _draftPoint = point);
    if (starting) widget.onPlacingLocationChanged?.call(true);
  }

  void _discardPoint() {
    if (_creatingAtPoint) return;
    setState(() => _draftPoint = null);
    widget.onPlacingLocationChanged?.call(false);
  }

  Future<void> _usePoint() async {
    final point = _draftPoint;
    final create = widget.onCreateHitoAt;
    if (point == null || create == null || _creatingAtPoint) return;
    setState(() => _creatingAtPoint = true);
    HapticFeedback.lightImpact();
    try {
      await create(point);
    } finally {
      if (mounted) {
        setState(() {
          _creatingAtPoint = false;
          _draftPoint = null;
        });
        widget.onPlacingLocationChanged?.call(false);
      }
    }
  }

  // flutter_map may report layout changes during build. Coalesce them after
  // the frame instead of notifying ancestors while Navigator/layout is busy.
  void _viewportChanged(MapCamera camera, bool userMoved) {
    _pendingCamera = camera;
    _pendingUserMove |= userMoved;
    if (_viewportScheduled) return;
    _viewportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportScheduled = false;
      if (!mounted) return;
      final camera = _pendingCamera;
      final data = controller.data;
      final userMoved = _pendingUserMove;
      _pendingUserMove = false;
      if (camera == null || data == null) return;
      _nearby.sync(data, controller.selectedId);
      final size = camera.nonRotatedSize;
      final visibleHeight =
          size.y - (widget.edgeToEdge ? _coveredMapHeight() : 0);
      _visibleEntries = data.mappedEntries.where((entry) {
        final point = camera.latLngToScreenPoint(entry.position!);
        return point.x >= 0 &&
            point.x <= size.x &&
            point.y >= 0 &&
            point.y <= visibleHeight;
      }).toList();
      if (_nearby.updateViewport(
        visibleIds: _visibleEntries.map((entry) => entry.id),
        center: camera.center,
        userMoved: userMoved,
      ))
        setState(() {});
    });
  }

  void _stepHito({required bool forward}) {
    final id = forward ? _nearby.next() : _nearby.previous();
    if (id != null) controller.select(id);
  }

  void _openAreaCarousel({int? selectedId}) {
    final camera = _pendingCamera;
    if (camera == null) {
      if (selectedId != null) controller.select(selectedId, recenter: false);
      return;
    }
    if (selectedId != null && _areaHitoIds.contains(selectedId)) {
      controller.select(selectedId, recenter: false);
      return;
    }
    final focus = camera.latLngToScreenPoint(camera.center);
    final distances = {
      for (final entry in _visibleEntries)
        entry.id:
            (camera.latLngToScreenPoint(entry.position!) - focus).magnitude,
    };
    final ordered = [..._visibleEntries]
      ..sort((a, b) {
        final distance = distances[a.id]!.compareTo(distances[b.id]!);
        return distance != 0 ? distance : b.ordinal.compareTo(a.ordinal);
      });
    final tapped = selectedId == null
        ? null
        : controller.data?.entryById(selectedId);
    if (tapped != null && !ordered.any((entry) => entry.id == tapped.id)) {
      // An edge marker can be tappable even if its GPS point is offscreen.
      ordered.insert(0, tapped);
    }
    if (ordered.isEmpty) return;
    // Keep the opening area's order while the map moves.
    _areaHitoIds = [for (final entry in ordered) entry.id];
    controller.select(selectedId ?? _areaHitoIds.first, recenter: false);
  }

  void _clearAreaOnSelectionChange() {
    if (!_areaHitoIds.contains(controller.selectedId)) _areaHitoIds = const [];
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(_clearAreaOnSelectionChange);
  }

  bool _visible = false;
  int _visibilityRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    _updateVisibility();
  }

  void _updateVisibility() {
    final revision = ++_visibilityRevision;
    // Visibility may change during Navigator.build; notify after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && revision == _visibilityRevision) {
        controller.setMapVisible(_visibilityOwner, _visible);
      }
    });
  }

  @override
  void didUpdateWidget(covariant TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      final previousController = oldWidget.controller;
      previousController.removeListener(_clearAreaOnSelectionChange);
      controller.addListener(_clearAreaOnSelectionChange);
      _areaHitoIds = const [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previousController.setMapVisible(_visibilityOwner, false);
      });
      _nearby = TripMapNearbyNavigation();
      _pendingCamera = null;
      _visibleEntries = const [];
      _updateVisibility();
    }
  }

  @override
  void dispose() {
    final previousController = controller;
    previousController.removeListener(_clearAreaOnSelectionChange);
    // Disposing an expanded route can happen while the tree is locked. A
    // shared preview is still listening, so release this owner after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previousController.setMapVisible(_visibilityOwner, false);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([controller, controller.bus]),
    builder: (context, _) {
      final data = controller.data;
      final piloMap =
          widget.edgeToEdge ||
          (widget.preview && PiloFamilyTheme.isActive(context));
      final bus = controller.bus;
      final reportedPosition = bus.position;
      final recordedAt = reportedPosition?.recordedAt;
      final busPosition =
          !piloMap ||
              (recordedAt != null && !recordedAt.isAfter(DateTime.now()))
          ? reportedPosition
          : null;
      if (widget.preview) {
        final hasMap =
            data != null &&
            (data.mappedEntries.isNotEmpty || busPosition != null);
        if (!hasMap) {
          return _MapPreviewState(
            loading: data == null && controller.error == null,
            error: controller.error != null,
            onOpen: onExpand,
          );
        }
        return _MapCanvas(
          key: ObjectKey(controller),
          controller: controller,
          data: data,
          busPosition: busPosition,
          piloMap: piloMap,
          onViewportChanged: _viewportChanged,
          expanded: false,
          preview: true,
          onExpand: onExpand,
        );
      }
      if (data == null) {
        return _withLoadingAction(
          SizedBox(
            height: expanded ? null : 260,
            child: Center(
              child: controller.error != null
                  ? _LoadMessage(
                      message: controller.error!,
                      onRetry: controller.refresh,
                      pilo: widget.edgeToEdge,
                    )
                  : const CircularProgressIndicator(color: tripTeal),
            ),
          ),
        );
      }
      if (data.entries.isEmpty &&
          busPosition == null &&
          widget.emptyMapCenter == null) {
        return _withLoadingAction(
          SizedBox(
            height: expanded ? null : 250,
            child: _LoadMessage(
              message:
                  'El viaje comienza aquí. Los hitos aparecerán cuando el coordinador los publique.',
              onRetry: controller.refresh,
              empty: true,
              pilo: widget.edgeToEdge,
            ),
          ),
        );
      }
      _nearby.sync(data, controller.selectedId);
      final header = expanded
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 6, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mapa del viaje',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tripInk,
                      ),
                    ),
                  ),
                  TripMapActions(
                    controller: controller,
                    showHitoList: widget.showHitoList,
                  ),
                ],
              ),
            );
      final notices = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                controller.error!,
                style: TextStyle(color: const Color(0xFF9D5020), fontSize: 12),
              ),
            ),
          if (data.unmappedCount > 0 || data.unknownDateCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Text(
                [
                  if (data.unmappedCount > 0)
                    '${data.unmappedCount} ${data.unmappedCount == 1 ? 'hito sin ubicación' : 'hitos sin ubicación'}: disponible${data.unmappedCount == 1 ? '' : 's'} en ${widget.showHitoList ? 'la lista' : 'la bitácora'}',
                  if (data.unknownDateCount > 0)
                    '${data.unknownDateCount} con fecha sin confirmar',
                ].join(' · '),
                style: TextStyle(
                  fontSize: 12,
                  color: widget.edgeToEdge
                      ? PiloFamilyTheme.secondary
                      : tripMuted,
                ),
              ),
            ),
        ],
      );
      final map = _MapCanvas(
        key: ObjectKey(controller),
        controller: controller,
        data: data,
        busPosition: busPosition,
        piloMap: piloMap,
        onViewportChanged: _viewportChanged,
        expanded: expanded,
        onExpand: onExpand,
        edgeToEdge: widget.edgeToEdge,
        showHitoList: widget.showHitoList,
        coveredHeight: _coveredMapHeight,
        onSelectHito: widget.edgeToEdge
            ? (id) => _openAreaCarousel(selectedId: id)
            : null,
        draftPoint: _draftPoint,
        onPlaceHito: widget.onCreateHitoAt == null ? null : _placePoint,
        onLocateCoordinator: widget.onLocateCoordinator,
        emptyMapCenter: widget.emptyMapCenter,
        initialFocus: widget.initialHitoId == null
            ? null
            : data.entryById(widget.initialHitoId!),
      );
      final selection = controller.selected;
      if (widget.edgeToEdge) {
        final showCard = selection != null && controller.selectionRevision > 0;
        final carouselEntries = !showCard
            ? const <TripMapEntry>[]
            : _areaHitoIds.contains(selection.id)
            ? [
                for (final id in _areaHitoIds)
                  if (data.entryById(id) case final entry?) entry,
              ]
            : [selection];
        final safe = MediaQuery.paddingOf(context);
        return LayoutBuilder(
          builder: (context, bounds) {
            final hasNotices =
                controller.error != null ||
                data.unmappedCount > 0 ||
                data.unknownDateCount > 0;
            return Stack(
              fit: StackFit.expand,
              children: [
                map,
                if (hasNotices)
                  Positioned(
                    top: safe.top + 119,
                    left: safe.left + 12,
                    right: safe.right + 70,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: PiloFamilyTheme.paper,
                          border: Border.all(color: PiloFamilyTheme.hairline),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: bounds.maxHeight * .16,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 7),
                            child: notices,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_draftPoint != null ||
                    showCard ||
                    data.mappedEntries.isNotEmpty ||
                    widget.bottomAction != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: NotificationListener<SizeChangedLayoutNotification>(
                      onNotification: (_) {
                        final camera = _pendingCamera;
                        if (camera != null) _viewportChanged(camera, false);
                        return false;
                      },
                      child: SizeChangedLayoutNotifier(
                        key: _floatingCard,
                        child: _draftPoint != null
                            ? _HitoPlacementCard(
                                busy: _creatingAtPoint,
                                onCancel: _discardPoint,
                                onConfirm: _usePoint,
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (widget.bottomAction != null)
                                    _bottomAction(
                                      safeBottom:
                                          !showCard &&
                                          data.mappedEntries.isEmpty,
                                    ),
                                  if (showCard)
                                    PiloMapAreaCarousel(
                                      controller: controller,
                                      entries: carouselEntries,
                                      selectedId: selection.id,
                                      compactMaxHeight: bounds.maxHeight / 3,
                                      expandedMaxHeight: bounds.maxHeight * .56,
                                      bottomInset: safe.bottom,
                                      onSelected: (id) => controller.select(
                                        id,
                                        recenter: false,
                                      ),
                                      onClose: controller.clearSelection,
                                      onOpenHito: widget.onOpenHito,
                                    )
                                  else if (data.mappedEntries.isNotEmpty)
                                    _MapAreaSummary(
                                      count: _visibleEntries.length,
                                      onOpen: _visibleEntries.isEmpty
                                          ? null
                                          : _openAreaCarousel,
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      }
      final sheetLimit = MediaQuery.sizeOf(context).height / 3;
      final compactAreaHeight = 280.0 + (sheetLimit * .65).clamp(0, 170);
      final card = _draftPoint != null
          ? _HitoPlacementCard(
              busy: _creatingAtPoint,
              onCancel: _discardPoint,
              onConfirm: _usePoint,
            )
          : selection == null
          ? const SizedBox.shrink()
          : TripHitoSheet(
              controller: controller,
              entry: selection,
              selectionRevision: controller.selectionRevision,
              showHitoNavigation: true,
              onPreviousHito: _nearby.previousId == null
                  ? null
                  : () => _stepHito(forward: false),
              onNextHito: _nearby.nextId == null
                  ? null
                  : () => _stepHito(forward: true),
              maxHeight: expanded
                  ? sheetLimit
                  : sheetLimit.clamp(0, compactAreaHeight - 140).toDouble(),
            );
      if (!expanded) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tripSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tripLine),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              notices,
              SizedBox(
                height: compactAreaHeight,
                child: Column(
                  children: [
                    Expanded(child: map),
                    card,
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          header,
          notices,
          Expanded(
            child: widget.bottomAction == null || _draftPoint != null
                ? map
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      map,
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _bottomAction(),
                      ),
                    ],
                  ),
          ),
          card,
        ],
      );
    },
  );
}

/// The bounded preview never invents locations or loads hito photo details.
class _MapPreviewState extends StatelessWidget {
  const _MapPreviewState({
    required this.loading,
    required this.error,
    this.onOpen,
  });
  final bool loading, error;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: loading
        ? 'Cargando mapa'
        : error
        ? 'No se pudo cargar el mapa. Abrir para reintentar'
        : 'Mapa del viaje. Aún no hay ubicaciones registradas',
    child: InkWell(
      onTap: onOpen,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: loading
              ? const CircularProgressIndicator(color: tripTeal)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      error ? Icons.cloud_off_outlined : Icons.map_outlined,
                      color: tripTeal,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error
                          ? 'No pudimos cargar el mapa'
                          : 'Aún no hay ubicaciones registradas',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PiloFamilyTheme.isActive(context)
                            ? PiloFamilyTheme.secondary
                            : tripMuted,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

/// Essential actions live in the header, leaving the map unobstructed.
class TripMapActions extends StatelessWidget {
  const TripMapActions({
    super.key,
    required this.controller,
    this.floating = false,
    this.showHitoList = true,
  });
  final TripMapController controller;
  final bool floating;
  final bool showHitoList;

  ButtonStyle? get _style => floating
      ? IconButton.styleFrom(
          minimumSize: const Size.square(48),
          backgroundColor: PiloFamilyTheme.paper,
          foregroundColor: PiloFamilyTheme.ink,
          disabledBackgroundColor: PiloFamilyTheme.soft,
          disabledForegroundColor: PiloFamilyTheme.secondary,
          side: const BorderSide(color: PiloFamilyTheme.hairline),
        )
      : null;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHitoList)
          IconButton(
            tooltip: 'Ver lista de hitos',
            style: _style,
            onPressed:
                controller.data == null || controller.data!.entries.isEmpty
                ? null
                : () =>
                      _showHitos(context, controller, controller.data!.entries),
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 22),
            color: tripInk,
          ),
        if (floating && showHitoList) const SizedBox(width: 8),
        IconButton(
          tooltip: 'Actualizar hitos',
          style: _style,
          onPressed: controller.loading ? null : controller.refresh,
          icon: controller.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tripTeal,
                  ),
                )
              : const Icon(Icons.refresh_rounded, size: 22),
          color: tripInk,
        ),
      ],
    ),
  );
}

class _LoadMessage extends StatelessWidget {
  const _LoadMessage({
    required this.message,
    required this.onRetry,
    this.empty = false,
    this.pilo = false,
  });
  final String message;
  final VoidCallback onRetry;
  final bool empty;
  final bool pilo;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            empty ? Icons.explore_outlined : Icons.cloud_off_outlined,
            size: 34,
            color: tripTeal,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: pilo ? PiloFamilyTheme.secondary : tripMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            style: pilo
                ? TextButton.styleFrom(
                    foregroundColor: PiloFamilyTheme.accentText,
                  )
                : null,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(empty ? 'Actualizar' : 'Reintentar'),
          ),
        ],
      ),
    ),
  );
}

class _HitoPlacementCard extends StatelessWidget {
  const _HitoPlacementCard({
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('coordinator-map-placement-card'),
    color: PiloFamilyTheme.paper,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ubicación del hito', style: PiloFamilyTheme.display(23)),
          const SizedBox(height: 4),
          const Text(
            'Arrastra el pin o toca otro punto.',
            style: TextStyle(fontSize: 13, color: PiloFamilyTheme.secondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: busy ? null : onCancel,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 48),
                    foregroundColor: PiloFamilyTheme.secondary,
                  ),
                  child: const Text('Descartar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: busy ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 48),
                    backgroundColor: PiloFamilyTheme.mint,
                    foregroundColor: PiloFamilyTheme.ink,
                  ),
                  child: const Text(
                    'Crear hito aquí',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MapCanvas extends StatefulWidget {
  const _MapCanvas({
    super.key,
    required this.controller,
    required this.data,
    required this.busPosition,
    required this.piloMap,
    required this.onViewportChanged,
    required this.expanded,
    this.onExpand,
    this.initialFocus,
    this.preview = false,
    this.edgeToEdge = false,
    this.showHitoList = true,
    this.coveredHeight,
    this.onSelectHito,
    this.onPlaceHito,
    this.draftPoint,
    this.onLocateCoordinator,
    this.emptyMapCenter,
  });
  final TripMapController controller;
  final TripMapData data;
  final TripBusPosition? busPosition;
  final bool piloMap;
  final void Function(MapCamera camera, bool userMoved) onViewportChanged;
  final bool expanded;
  final bool preview;
  final TripMapEntry? initialFocus;
  final bool edgeToEdge;
  final bool showHitoList;
  final double Function()? coveredHeight;
  final VoidCallback? onExpand;
  final ValueChanged<int>? onSelectHito;
  final ValueChanged<LatLng>? onPlaceHito;
  final LatLng? draftPoint;
  final Future<LatLng> Function()? onLocateCoordinator;
  final LatLng? emptyMapCenter;
  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas>
    with SingleTickerProviderStateMixin {
  final _camera = MapController();
  late final AnimationController _groupZoom;
  MapCamera? _groupZoomStart;
  LatLng? _groupZoomTarget;
  double _groupTargetZoom = 0;
  bool _ready = false;
  late bool _awaitingOpeningBus;
  int? _selectedId;
  int _selectionRevision = 0;
  int? _markerTapRevision;
  bool _locatingCoordinator = false;
  bool _draggingDraft = false;
  LatLng? _dragPoint;
  int? _dragPointer;

  void _keepDraftVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final point = widget.draftPoint;
      if (!mounted || !_ready || point == null || _draggingDraft) return;
      final camera = _camera.camera;
      final bottom =
          camera.nonRotatedSize.y - (widget.coveredHeight?.call() ?? 0) - 40;
      final pixel = camera.latLngToScreenPoint(point);
      if (bottom > 100 && pixel.y > bottom) {
        _camera.move(
          camera.center,
          camera.zoom,
          offset: Offset(0, bottom - pixel.y),
        );
        widget.onViewportChanged(_camera.camera, false);
      }
    });
  }

  Future<void> _locateCoordinator() async {
    final locate = widget.onLocateCoordinator;
    if (!_ready || _locatingCoordinator || locate == null) return;
    _locatingCoordinator = true;
    _groupZoom.stop();
    _awaitingOpeningBus = false;
    try {
      final point = await locate();
      if (!mounted || !_ready) return;
      if (!HitoLocationDraft.isValidPoint(point)) {
        throw StateError('Ubicación fuera del mapa');
      }
      // A one-time camera action, independent of sharing and hito selection.
      // Later source updates never move this map without another tap.
      _camera.move(point, _camera.camera.zoom);
      _onViewportChanged(_camera.camera, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos obtener tu ubicación. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      _locatingCoordinator = false;
    }
  }

  TripBusPosition? get _recentBusPosition =>
      widget.controller.bus.isRecent ? widget.busPosition : null;

  // Home previews show the same regional perspective at any latitude or
  // device width. Full-screen maps keep their independent opening camera.
  static const _homePreviewWidthMeters = 300000.0;

  double _homePreviewZoom(LatLng center, double width) {
    const equatorialCircumference = 40075016.686;
    final latitude = center.latitude.clamp(-85.0, 85.0) * math.pi / 180;
    final scale =
        equatorialCircumference *
        math.cos(latitude) *
        width /
        (256 * _homePreviewWidthMeters);
    return (math.log(scale) / math.ln2).clamp(2.0, tripMapMaxZoom);
  }

  TripBusPosition? get _openingBusPosition => widget.preview && widget.piloMap
      ? widget.busPosition
      : _recentBusPosition;

  @override
  void initState() {
    super.initState();
    _groupZoom = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(_tickGroupZoom);
    _selectedId = widget.controller.selectedId;
    _selectionRevision = widget.controller.selectionRevision;
    _awaitingOpeningBus =
        widget.piloMap &&
        widget.initialFocus?.position == null &&
        _openingBusPosition == null &&
        !widget.controller.bus.hasCompletedRead;
  }

  @override
  void didUpdateWidget(covariant _MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draftPoint != widget.draftPoint && !_draggingDraft) {
      _keepDraftVisible();
    }
    final revision = widget.controller.selectionRevision;
    final recenter = widget.edgeToEdge
        ? _selectionRevision != revision
        : _selectedId != widget.controller.selectedId;
    _selectedId = widget.controller.selectedId;
    _selectionRevision = revision;
    if (widget.data.mappedEntries.isEmpty &&
        widget.busPosition == null &&
        widget.emptyMapCenter == null) {
      _ready = false;
    }
    if (recenter) {
      _groupZoom.stop();
      _awaitingOpeningBus = false;
      if (_ready &&
          widget.controller.recenterOnSelection &&
          _markerTapRevision != revision) {
        _recenterSelection();
      }
      _markerTapRevision = null;
    }
    _focusOpeningBus();
    if (_ready && oldWidget.data != widget.data) {
      widget.onViewportChanged(_camera.camera, false);
    }
  }

  void _focusOpeningBus() {
    if (!_ready ||
        !_awaitingOpeningBus ||
        !widget.controller.bus.hasCompletedRead) {
      return;
    }
    if (_openingBusPosition == null) {
      _awaitingOpeningBus = false;
      return;
    }
    // The first location read can finish after the milestones. Yield to any
    // manual map interaction and keep subsequent polls from moving the camera.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ready || !_awaitingOpeningBus) return;
      _awaitingOpeningBus = false;
      final position = _openingBusPosition;
      if (position != null) {
        final zoom = widget.preview && widget.piloMap
            ? _homePreviewZoom(
                position.coordinate,
                _camera.camera.nonRotatedSize.x,
              )
            : _camera.camera.zoom;
        _camera.move(position.coordinate, zoom);
      }
    });
  }

  void _onViewportChanged(MapCamera camera, bool userMoved) {
    if (userMoved) {
      _groupZoom.stop();
      _awaitingOpeningBus = false;
    }
    widget.onViewportChanged(camera, userMoved);
  }

  void _selectMarker(int id) {
    _markerTapRevision = widget.controller.selectionRevision + 1;
    (widget.onSelectHito ?? widget.controller.select)(id);
  }

  void _openGroup(List<TripMapEntry> entries) {
    if (!_ready || entries.isEmpty) return;
    _awaitingOpeningBus = false;
    _groupZoom.stop();
    final camera = _camera.camera;
    final zoom = (camera.zoom + 1).clamp(2.0, tripMapMaxZoom);
    final target = tripHitoClusterCenter(camera, entries);
    widget.controller.clearSelection();
    _groupTargetZoom = zoom;
    if (MediaQuery.disableAnimationsOf(context)) {
      _camera.move(target, zoom);
      return;
    }
    _groupZoomStart = camera;
    _groupZoomTarget = target;
    _groupZoom.forward(from: 0);
  }

  void _tickGroupZoom() {
    final from = _groupZoomStart;
    final to = _groupZoomTarget;
    if (!_ready || from == null || to == null) return;
    final phase = Curves.easeOutCubic.transform(_groupZoom.value);
    if (phase == 0) return;
    final start = from.project(from.center);
    final end = from.project(to);
    _camera.move(
      from.unproject(start + (end - start) * phase),
      from.zoom + (_groupTargetZoom - from.zoom) * phase,
    );
  }

  void _recenterSelection() {
    final position = widget.controller.selected?.position;
    final revision = _selectionRevision;
    if (position == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_ready ||
          revision != _selectionRevision ||
          widget.controller.selected?.position != position)
        return;
      final camera = _camera.camera;
      final lift = widget.edgeToEdge ? camera.nonRotatedSize.y * .13 : 0.0;
      _camera.move(position, camera.zoom, offset: Offset(0, -lift));
      widget.onViewportChanged(_camera.camera, false);
    });
  }

  @override
  void dispose() {
    _groupZoom.dispose();
    _camera.dispose();
    super.dispose();
  }

  CameraFit get _fit {
    final safe = MediaQuery.paddingOf(context);
    final piloPreview = widget.preview && PiloFamilyTheme.isActive(context);
    return CameraFit.coordinates(
      coordinates: [
        ...widget.data.mappedEntries.map((e) => e.position!),
        if (widget.busPosition case final bus?) bus.coordinate,
        if (widget.data.mappedEntries.isEmpty &&
            widget.busPosition == null &&
            widget.emptyMapCenter != null)
          widget.emptyMapCenter!,
      ],
      padding: piloPreview
          // Reserve the lower strip for the map button.
          ? const EdgeInsets.fromLTRB(34, 32, 34, 100)
          : widget.preview
          ? const EdgeInsets.all(32)
          : widget.edgeToEdge
          ? EdgeInsets.fromLTRB(
              safe.left + 38,
              safe.top + 65,
              safe.right + 65,
              ((widget.coveredHeight?.call() ?? 0).clamp(0, 200)).toDouble() +
                  safe.bottom +
                  30,
            )
          : EdgeInsets.fromLTRB(
              50,
              widget.expanded ? 80 : 118,
              widget.expanded ? 90 : 60,
              68,
            ),
      maxZoom: 15,
      minZoom: 2,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _buildMap);

  Widget _buildMap(BuildContext context, BoxConstraints constraints) {
    final safe = MediaQuery.paddingOf(context);
    final shortMap = MediaQuery.sizeOf(context).height < 510;
    final piloPreview = widget.preview && PiloFamilyTheme.isActive(context);
    final openOnTap = widget.preview && !piloPreview;
    final points = widget.data.mappedEntries;
    final busPosition = widget.busPosition;
    final focus = widget.initialFocus?.position;
    final defaultCenter = widget.piloMap
        ? _openingBusPosition?.coordinate
        : null;
    if (points.isEmpty &&
        busPosition == null &&
        widget.emptyMapCenter == null) {
      return ColoredBox(
        color: widget.piloMap ? PiloFamilyTheme.mapBackground : tripPaper,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Estos hitos todavía no tienen ubicación. Puedes consultarlos en la lista.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.piloMap ? PiloFamilyTheme.secondary : tripMuted,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        ExcludeSemantics(
          excluding: widget.preview,
          child: IgnorePointer(
            ignoring: openOnTap,
            child: FlutterMap(
              mapController: _camera,
              options: MapOptions(
                initialCenter:
                    focus ??
                    defaultCenter ??
                    points.lastOrNull?.position ??
                    busPosition?.coordinate ??
                    widget.emptyMapCenter!,
                initialZoom: piloPreview
                    ? _homePreviewZoom(
                        defaultCenter ??
                            points.lastOrNull?.position ??
                            busPosition?.coordinate ??
                            widget.emptyMapCenter!,
                        constraints.maxWidth,
                      )
                    : focus != null
                    ? 16
                    : widget.edgeToEdge && widget.piloMap
                    ? 13.25
                    : 14,
                initialCameraFit: focus == null && !widget.piloMap
                    ? _fit
                    : null,
                minZoom: 2,
                maxZoom: tripMapMaxZoom,
                backgroundColor: PiloFamilyTheme.isActive(context)
                    ? PiloFamilyTheme.mapBackground
                    : tripPaper,
                interactionOptions: InteractionOptions(
                  flags: widget.expanded || piloPreview
                      ? InteractiveFlag.all & ~InteractiveFlag.rotate
                      : InteractiveFlag.none,
                ),
                onMapReady: () {
                  _ready = true;
                  widget.onViewportChanged(_camera.camera, false);
                  if (widget.edgeToEdge && widget.initialFocus != null) {
                    _recenterSelection();
                  }
                  _focusOpeningBus();
                },
                onTap: widget.edgeToEdge || widget.draftPoint != null
                    ? (_, point) {
                        _groupZoom.stop();
                        _awaitingOpeningBus = false;
                        if (widget.draftPoint != null) {
                          widget.onPlaceHito?.call(point);
                        } else {
                          widget.controller.clearSelection();
                        }
                      }
                    : null,
                onLongPress: widget.onPlaceHito == null
                    ? null
                    : (_, point) {
                        _groupZoom.stop();
                        _awaitingOpeningBus = false;
                        widget.onPlaceHito!(point);
                      },
                onPositionChanged: _onViewportChanged,
                onMapEvent: (event) {
                  if (event.source == MapEventSource.dragStart ||
                      event.source == MapEventSource.multiFingerGestureStart) {
                    _groupZoom.stop();
                  }
                  if (_ready) widget.onViewportChanged(_camera.camera, false);
                },
              ),
              children: [
                const LabMapBasemap(),
                IgnorePointer(
                  ignoring: widget.preview || widget.draftPoint != null,
                  child: TripHitoMarkers(
                    controller: widget.controller,
                    pilo: widget.piloMap,
                    onSelectHito: _selectMarker,
                    onSelectGroup: widget.edgeToEdge || !widget.showHitoList
                        ? _openGroup
                        : (entries) =>
                              _showHitos(context, widget.controller, entries),
                  ),
                ),
                if (busPosition != null)
                  IgnorePointer(
                    ignoring: widget.preview || widget.draftPoint != null,
                    child: _BusLayer(
                      controller: widget.controller,
                      position: busPosition,
                      pilo: widget.piloMap,
                    ),
                  ),
                if (widget.draftPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.draftPoint!,
                        width: 72,
                        height: 72,
                        child: RawGestureDetector(
                          key: const ValueKey('coordinator-map-placement-pin'),
                          behavior: HitTestBehavior.opaque,
                          gestures: {
                            EagerGestureRecognizer:
                                GestureRecognizerFactoryWithHandlers<
                                  EagerGestureRecognizer
                                >(EagerGestureRecognizer.new, (_) {}),
                          },
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (event) {
                              if (_dragPointer != null) return;
                              _dragPointer = event.pointer;
                              _dragPoint = widget.draftPoint;
                              setState(() => _draggingDraft = true);
                            },
                            onPointerMove: (event) {
                              final point = _dragPoint;
                              if (!_ready ||
                                  point == null ||
                                  event.pointer != _dragPointer)
                                return;
                              final pixel = _camera.camera.latLngToScreenPoint(
                                point,
                              );
                              _dragPoint = _camera.camera.pointToLatLng(
                                pixel +
                                    math.Point(event.delta.dx, event.delta.dy),
                              );
                              widget.onPlaceHito?.call(_dragPoint!);
                            },
                            onPointerUp: (event) {
                              if (event.pointer != _dragPointer) return;
                              _dragPoint = null;
                              _dragPointer = null;
                              setState(() => _draggingDraft = false);
                              _keepDraftVisible();
                            },
                            onPointerCancel: (event) {
                              if (event.pointer != _dragPointer) return;
                              _dragPoint = null;
                              _dragPointer = null;
                              setState(() => _draggingDraft = false);
                              _keepDraftVisible();
                            },
                            child: Semantics(
                              label:
                                  'Ubicación del nuevo hito. Arrastra para ajustar.',
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: .8,
                                  end: _draggingDraft ? 1 : 0,
                                ),
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : Duration(
                                        milliseconds: _draggingDraft
                                            ? 140
                                            : 220,
                                      ),
                                curve: Curves.easeOutCubic,
                                builder: (_, lift, _) =>
                                    PiloHitoPlacementPin(lift: lift),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (openOnTap)
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Mapa del viaje. Abrir mapa completo',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onExpand,
              ),
            ),
          ),
        if (!widget.preview)
          Positioned(
            top: widget.edgeToEdge ? safe.top + 68 : 10,
            right: widget.edgeToEdge ? safe.right + 14 : 10,
            child: Flex(
              direction: widget.edgeToEdge && shortMap
                  ? Axis.horizontal
                  : Axis.vertical,
              children: [
                if (!widget.expanded && widget.onExpand != null)
                  _MapButton(
                    icon: Icons.open_in_full_rounded,
                    label: 'Ampliar mapa',
                    text: 'Ampliar',
                    onTap: widget.onExpand!,
                  ),
                if (widget.expanded) ...[
                  if (widget.onLocateCoordinator != null) ...[
                    _MapButton(
                      icon: Icons.near_me_rounded,
                      label: 'Mi ubicación',
                      circular: widget.edgeToEdge,
                      onTap: _locateCoordinator,
                    ),
                    const SizedBox(width: 8, height: 8),
                  ],
                  _MapButton(
                    icon: Icons.fit_screen_rounded,
                    label: 'Ver mapa completo',
                    circular: widget.edgeToEdge,
                    onTap: () {
                      if (_ready) {
                        _groupZoom.stop();
                        _camera.fitCamera(_fit);
                        _onViewportChanged(_camera.camera, true);
                      }
                    },
                  ),
                  const SizedBox(width: 8, height: 8),
                  _MapButton(
                    icon: Icons.add,
                    label: 'Acercar mapa',
                    circular: widget.edgeToEdge,
                    onTap: () {
                      if (_ready) {
                        _groupZoom.stop();
                        _camera.move(
                          _camera.camera.center,
                          (_camera.camera.zoom + 1).clamp(2, tripMapMaxZoom),
                        );
                        _onViewportChanged(_camera.camera, true);
                      }
                    },
                  ),
                  const SizedBox(width: 4, height: 4),
                  _MapButton(
                    icon: Icons.remove,
                    label: 'Alejar mapa',
                    circular: widget.edgeToEdge,
                    onTap: () {
                      if (_ready) {
                        _groupZoom.stop();
                        _camera.move(
                          _camera.camera.center,
                          (_camera.camera.zoom - 1).clamp(2, tripMapMaxZoom),
                        );
                        _onViewportChanged(_camera.camera, true);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.text,
    this.circular = false,
  });
  final bool circular;
  final IconData icon;
  final String label;
  final String? text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Material(
      color: tripSurface,
      elevation: circular ? 0 : 2,
      shadowColor: const Color(0x24000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(circular ? 24 : 12),
        side: circular
            ? const BorderSide(color: PiloFamilyTheme.hairline)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(circular ? 24 : 12),
        child: Semantics(
          button: true,
          label: label,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: tripInk, size: 18),
                  if (text != null) ...[
                    const SizedBox(width: 7),
                    Text(
                      text!,
                      style: const TextStyle(
                        color: tripInk,
                        fontSize: 12,
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
  );
}

/// The bus is a separate observation, never a numbered hito or route line.
class _BusLayer extends StatelessWidget {
  const _BusLayer({
    required this.controller,
    required this.position,
    required this.pilo,
  });
  final TripMapController controller;
  final TripBusPosition position;
  final bool pilo;
  @override
  Widget build(BuildContext context) {
    final recent = controller.bus.isRecent;
    final camera = MapCamera.of(context);
    if (pilo) {
      final iconSize = TripBusMarker.iconSize;
      final height = recent ? iconSize : TripBusMarker.staleHeight(context);
      final viewportWidth = camera.nonRotatedSize.x;
      final labelWidth = (viewportWidth - 16).clamp(
        1.0,
        TripBusMarker.staleWidth,
      );
      return MarkerLayer(
        markers: [
          Marker(
            point: position.coordinate,
            width: recent
                ? iconSize
                : labelWidth.clamp(iconSize, double.infinity),
            height: height,
            // The artwork stays centered on the position as the label appears.
            alignment: Alignment(0, 1 - iconSize / height),
            child: TripBusMarker(
              position: position,
              recent: recent,
              simulation: LabMode.fixturesForTests,
              pilo: true,
              headingDegrees: position.headingDegrees,
              locationLabelWidth: labelWidth,
            ),
          ),
        ],
      );
    }
    final point = camera.latLngToScreenPoint(position.coordinate);
    final overlaps = controller.data!.mappedEntries.any((entry) {
      final pin = camera.latLngToScreenPoint(entry.position!);
      return (pin - point).magnitude < 70;
    });
    return MarkerLayer(
      markers: [
        Marker(
          point: position.coordinate,
          width: overlaps ? 200 : 64,
          height: 64,
          child: Stack(
            children: [
              Align(
                alignment: overlaps ? Alignment.centerRight : Alignment.center,
                child: TripBusMarker(position: position, recent: recent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _mapAreaHitoLabel(int count) =>
    count == 1 ? '1 hito en esta zona' : '$count hitos en esta zona';

class _MapAreaSummary extends StatefulWidget {
  const _MapAreaSummary({required this.count, this.onOpen});

  final int count;
  final VoidCallback? onOpen;

  @override
  State<_MapAreaSummary> createState() => _MapAreaSummaryState();
}

class _MapAreaSummaryState extends State<_MapAreaSummary> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) => Material(
    color: PiloFamilyTheme.paper,
    elevation: 3,
    shadowColor: const Color(0x26000000),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    child: GestureDetector(
      onVerticalDragStart: (_) => _dragDistance = 0,
      onVerticalDragUpdate: (details) => _dragDistance += details.delta.dy,
      onVerticalDragEnd: (_) {
        if (_dragDistance < -16) widget.onOpen?.call();
      },
      child: InkWell(
        onTap: widget.onOpen,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: const ShapeDecoration(
                    color: PiloFamilyTheme.connectorPast,
                    shape: StadiumBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _mapAreaHitoLabel(widget.count),
                  key: const ValueKey('pilo-map-area-count'),
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _showHitos(
  BuildContext context,
  TripMapController controller,
  List<TripMapEntry> entries,
) {
  final orderedEntries = entries.reversed.toList();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: tripSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: Text(
                '${entries.length} hitos del viaje',
                style: const TextStyle(
                  color: tripInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72, color: tripLine),
                itemBuilder: (_, index) {
                  final entry = orderedEntries[index];
                  final selected = controller.selectedId == entry.id;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: entry.id == controller.data?.latestId
                          ? tripYellow
                          : tripMint,
                      foregroundColor: tripInk,
                      child: const Icon(Icons.location_on, size: 24),
                    ),
                    title: Text(
                      entry.source.binnacleTitulo,
                      style: const TextStyle(
                        color: tripInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${tripMoment(entry)}${entry.hasLocation ? '' : ' · Sin ubicación'}',
                      style: const TextStyle(color: tripMuted, fontSize: 12),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check, color: tripTeal, size: 20)
                        : null,
                    onTap: () {
                      controller.select(entry.id);
                      Navigator.pop(sheetContext);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
