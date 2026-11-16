import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/lab/synthetic_location.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';

import '../../navigation/family_navigation.dart';

class TraceMapFullScreen extends StatefulWidget {
  const TraceMapFullScreen({
    super.key,
    required this.tourCode,
    this.controller,
    this.initialHitoId,
    this.edgeToEdge = false,
    this.locationControl,
    this.coordinatorId,
    this.onCreateHito,
    this.onOpenHito,
  });
  final int tourCode;
  final TripMapController? controller;
  final int? initialHitoId;
  final bool edgeToEdge;

  /// Explicit opt-in for coordinator routes; family maps remain read-only.
  final Widget? locationControl;

  /// Only coordinator routes opt in to local acknowledged sharing state.
  final int? coordinatorId;
  final Future<void> Function(HitoLocationDraft location)? onCreateHito;
  final FutureOr<void> Function(TripMapEntry entry)? onOpenHito;
  @override
  State<TraceMapFullScreen> createState() => _TraceMapFullScreenState();
}

class _TraceMapFullScreenState extends State<TraceMapFullScreen> {
  late final TripMapController _controller;
  bool _initialSelectionApplied = false;
  bool _choosingLocation = false;
  bool _placingLocation = false;

  // Only coordinator routes offer the separate list; family maps use pins
  // and the area carousel, independent of any cached role/session.
  bool get _showHitoList => widget.coordinatorId != null;
  LocationService? _locationService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = widget.coordinatorId == null
        ? null
        : context.read<LocationService?>();
    if (!identical(service, _locationService)) {
      _locationService?.removeListener(_syncOwnBusSharing);
      _locationService = service;
      service?.addListener(_syncOwnBusSharing);
    }
    _syncOwnBusSharing();
  }

  void _syncOwnBusSharing() {
    final service = _locationService;
    final coordinatorId = widget.coordinatorId;
    if (!mounted ||
        service == null ||
        coordinatorId == null ||
        service.activeTourId != widget.tourCode)
      return;
    _controller.bus.setLocalSharing(
      coordinatorId: coordinatorId,
      enabled: service.isTracking,
      confirmed: service.confirmedPosition,
    );
  }

  Future<LatLng> _readCoordinatorLocation() async {
    final source = LabSyntheticLocation.instance;
    await source.restore();
    return source.current.latLng;
  }

  Future<void> _createHito({LatLng? at}) async {
    final create = widget.onCreateHito;
    if (create == null || _choosingLocation) return;
    setState(() => _choosingLocation = true);
    try {
      // The normal action begins where the coordinator currently is, even
      // after exploring elsewhere. Only an explicit long press overrides it.
      final point = at ?? await _readCoordinatorLocation();
      if (!mounted) return;
      final source = LabSyntheticLocation.instance.current;
      await create(
        at == null
            ? HitoLocationDraft(point: point, label: source.address)
            : HitoLocationDraft.selectedPoint(point),
      );
      if (mounted && widget.controller == null) await _controller.refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos abrir el nuevo hito. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _choosingLocation = false);
    }
  }

  Future<void> _openHito(TripMapEntry entry) async {
    await widget.onOpenHito?.call(entry);
    // Standalone coordinator maps own their list. The home route instead
    // refreshes its borrowed controller together with its diary and gallery.
    if (mounted && widget.controller == null) await _controller.refresh();
  }

  Widget _newHitoButton() => Tooltip(
    message: 'Crear hito. También puedes mantener pulsado un punto del mapa.',
    child: FilledButton.icon(
      key: const ValueKey('coordinator-map-create-hito'),
      style: FilledButton.styleFrom(
        backgroundColor: PiloFamilyTheme.mint,
        foregroundColor: PiloFamilyTheme.ink,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: _choosingLocation || _placingLocation ? null : _createHito,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text(
        'Nuevo hito',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TripMapController(tourCode: widget.tourCode);
    _controller.addListener(_applyInitialSelection);
    _applyInitialSelection();
    if (widget.controller == null) _controller.refresh();
  }

  void _applyInitialSelection() {
    if (_initialSelectionApplied ||
        widget.initialHitoId == null ||
        _controller.data == null)
      return;
    _initialSelectionApplied = true;
    // A borrowed controller also drives the timeline beneath this route.
    // Do not notify that tree from inside this route's initState/build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.select(widget.initialHitoId!);
    });
  }

  @override
  void dispose() {
    _locationService?.removeListener(_syncOwnBusSharing);
    _controller.removeListener(_applyInitialSelection);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _goBack(BuildContext context) {
    final navigation = FamilyNavigationScope.maybeOf(context);
    if (navigation == null) {
      Navigator.pop(context);
    } else if (!widget.edgeToEdge && widget.initialHitoId != null) {
      navigation.select(FamilySection.diary);
    } else {
      navigation.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = PiloFamilyTheme.theme(Theme.of(context));
    final backTooltip = widget.initialHitoId == null
        ? 'Volver al inicio'
        : 'Volver a la bitácora';
    if (widget.edgeToEdge) {
      return Theme(
        data: theme,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: Scaffold(
            backgroundColor: PiloFamilyTheme.mapBackground,
            body: Stack(
              fit: StackFit.expand,
              children: [
                TripMapView(
                  controller: _controller,
                  expanded: true,
                  showHitoList: _showHitoList,
                  edgeToEdge: true,
                  initialHitoId: widget.initialHitoId,
                  onOpenHito: widget.onOpenHito == null ? null : _openHito,
                  onLocateCoordinator: widget.onCreateHito == null
                      ? null
                      : _readCoordinatorLocation,
                  emptyMapCenter: widget.onCreateHito == null
                      ? null
                      : LabSyntheticLocation.instance.current.latLng,
                  onCreateHitoAt: widget.onCreateHito == null
                      ? null
                      : (point) => _createHito(at: point),
                  onPlacingLocationChanged: (placing) {
                    if (mounted) setState(() => _placingLocation = placing);
                  },
                  bottomAction: widget.onCreateHito == null
                      ? null
                      : _newHitoButton(),
                ),
                if (widget.locationControl != null)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 68,
                    left: 14,
                    child: widget.locationControl!,
                  ),
                Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Row(
                        children: [
                          IconButton.filled(
                            tooltip: 'Volver',
                            style: IconButton.styleFrom(
                              backgroundColor: PiloFamilyTheme.paper,
                              foregroundColor: PiloFamilyTheme.ink,
                              side: const BorderSide(
                                color: PiloFamilyTheme.hairline,
                              ),
                              minimumSize: const Size.square(48),
                            ),
                            onPressed: () => _goBack(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const Spacer(),
                          TripMapActions(
                            controller: _controller,
                            floating: true,
                            showHitoList: _showHitoList,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxHeight < 500 ||
                  MediaQuery.textScalerOf(context).scale(50) > 68;
              final actions = TripMapActions(
                controller: _controller,
                showHitoList: _showHitoList,
              );
              return Column(
                children: [
                  if (compact)
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: backTooltip,
                              style: IconButton.styleFrom(
                                backgroundColor: PiloFamilyTheme.soft,
                              ),
                              onPressed: () => _goBack(context),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  'Mapa del viaje',
                                  style: PiloFamilyTheme.display(24),
                                ),
                              ),
                            ),
                            actions,
                          ],
                        ),
                      ),
                    )
                  else
                    PiloSectionBar(
                      title: 'Mapa del viaje',
                      subtitle: 'Hitos y ubicaciones de la gira',
                      backTooltip: backTooltip,
                      onBack: () => _goBack(context),
                      actions: [actions],
                    ),
                  if (widget.locationControl != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: widget.locationControl!,
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ColoredBox(
                          color: PiloFamilyTheme.soft,
                          child: TripMapView(
                            controller: _controller,
                            expanded: true,
                            showHitoList: _showHitoList,
                            initialHitoId: widget.initialHitoId,
                            onOpenHito: widget.onOpenHito == null
                                ? null
                                : _openHito,
                            onLocateCoordinator: widget.onCreateHito == null
                                ? null
                                : _readCoordinatorLocation,
                            emptyMapCenter: widget.onCreateHito == null
                                ? null
                                : LabSyntheticLocation.instance.current.latLng,
                            onCreateHitoAt: widget.onCreateHito == null
                                ? null
                                : (point) => _createHito(at: point),
                            onPlacingLocationChanged: (placing) {
                              if (mounted)
                                setState(() => _placingLocation = placing);
                            },
                            bottomAction: widget.onCreateHito == null
                                ? null
                                : _newHitoButton(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
