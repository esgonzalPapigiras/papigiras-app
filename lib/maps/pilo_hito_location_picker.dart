import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/lab/map_basemap.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';

/// Returns a location only after explicit confirmation. Closing the route
/// leaves the caller's draft (and the coordinator's location) untouched.
Future<HitoLocationDraft?> showPiloHitoLocationPicker(
  BuildContext context, {
  required HitoLocationDraft initial,
}) {
  final theme = PiloFamilyTheme.theme(Theme.of(context));
  return Navigator.of(context, rootNavigator: true).push<HitoLocationDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Theme(
        data: theme,
        child: _PiloHitoLocationPicker(initial: initial),
      ),
    ),
  );
}

class _PiloHitoLocationPicker extends StatefulWidget {
  const _PiloHitoLocationPicker({required this.initial});

  final HitoLocationDraft initial;

  @override
  State<_PiloHitoLocationPicker> createState() =>
      _PiloHitoLocationPickerState();
}

class _PiloHitoLocationPickerState extends State<_PiloHitoLocationPicker>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _pinLift = AnimationController(vsync: this);
  late LatLng _point = widget.initial.point;
  bool _ready = false;
  bool _refreshScheduled = false;
  bool _reduceMotion = false;
  bool _moving = false;
  bool _gestureActive = false;
  bool _flingActive = false;
  bool _zoomActive = false;
  bool _leaving = false;
  LatLng? _motionOrigin;
  Timer? _settleTimer;
  int _motionEpoch = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _pinLift.value = 0;
  }

  bool _isOriginal(LatLng point) =>
      (point.latitude - widget.initial.point.latitude).abs() < 1e-9 &&
      (point.longitude - widget.initial.point.longitude).abs() < 1e-9;

  HitoLocationDraft _draftFor(LatLng point) => _isOriginal(point)
      ? widget.initial
      : HitoLocationDraft.selectedPoint(point);

  void _beginMotion(LatLng origin) {
    if (_leaving) return;
    _settleTimer?.cancel();
    _motionEpoch++;
    if (_moving) return;
    _moving = true;
    _motionOrigin = origin;
    if (!_reduceMotion) {
      _pinLift.animateTo(
        1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scheduleLanding() {
    _settleTimer?.cancel();
    if (_gestureActive || _flingActive || _zoomActive || _leaving) return;
    // A short quiet interval bridges drag-end to fling-start, and groups
    // scroll-wheel events. A stationary held gesture never triggers landing.
    _settleTimer = Timer(const Duration(milliseconds: 110), () {
      unawaited(_landPin());
    });
  }

  Future<void> _landPin() async {
    if (!mounted ||
        !_moving ||
        _leaving ||
        _gestureActive ||
        _flingActive ||
        _zoomActive)
      return;
    _moving = false;
    final epoch = _motionEpoch;
    final origin = _motionOrigin;
    _motionOrigin = null;
    try {
      if (_reduceMotion) {
        _pinLift.value = 0;
      } else {
        await _pinLift
            .animateBack(
              0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            )
            .orCancel;
      }
      if (!mounted ||
          _leaving ||
          _reduceMotion ||
          epoch != _motionEpoch ||
          ModalRoute.of(context)?.isCurrent != true ||
          origin == null)
        return;
      final point = _map.camera.center;
      if ((origin.latitude - point.latitude).abs() > 1e-9 ||
          (origin.longitude - point.longitude).abs() > 1e-9) {
        // One short selection cue per completed change, never each map frame.
        await HapticFeedback.selectionClick();
      }
    } on TickerCanceled {
      // A new gesture or route disposal interrupts the optional feedback.
    } catch (_) {
      // Unsupported haptics must never affect choosing a location.
    }
  }

  void _mapEvent(MapEvent event) {
    if (!_ready || _leaving || event is MapEventNonRotatedSizeChange) return;
    if (event is MapEventMoveStart) {
      _gestureActive = true;
      _beginMotion(event.camera.center);
    } else if (event is MapEventFlingAnimationStart) {
      _flingActive = true;
      _beginMotion(event.camera.center);
    } else if (event is MapEventDoubleTapZoomStart) {
      _zoomActive = true;
      _beginMotion(event.camera.center);
    } else if (event is MapEventMoveEnd) {
      _gestureActive = false;
      _scheduleLanding();
    } else if (event is MapEventFlingAnimationEnd ||
        event is MapEventFlingAnimationNotStarted) {
      _flingActive = false;
      _scheduleLanding();
    } else if (event is MapEventDoubleTapZoomEnd) {
      _zoomActive = false;
      _scheduleLanding();
    } else if (event is MapEventWithMove &&
        (event.oldCamera.center != event.camera.center ||
            event.oldCamera.zoom != event.camera.zoom)) {
      _beginMotion(event.oldCamera.center);
      _scheduleLanding();
    }
  }

  void _positionChanged(MapCamera camera, bool _) {
    _point = camera.center;
    // The map also reports position during layout. Update its description
    // after that frame, never while Navigator or map layout is building.
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _zoom(double amount) {
    if (!_ready) return;
    final camera = _map.camera;
    _map.move(camera.center, (camera.zoom + amount).clamp(4.0, 19.0));
  }

  void _confirm() {
    // Read the actual camera, including a gesture's last movement, instead
    // of relying on a footer update that may still be pending this frame.
    final point = _ready ? _map.camera.center : _point;
    if (!HitoLocationDraft.isValidPoint(point)) return;
    _leaving = true;
    _settleTimer?.cancel();
    Navigator.of(context).pop(_draftFor(point));
  }

  @override
  void dispose() {
    _leaving = true;
    _settleTimer?.cancel();
    _pinLift.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draftFor(_point);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: PiloFamilyTheme.paper,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Ubicación del hito',
                          style: PiloFamilyTheme.display(27),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MapControl(
                      controlKey: const ValueKey('hito-location-cancel'),
                      tooltip: 'Cancelar ubicación',
                      icon: Icons.close_rounded,
                      color: PiloFamilyTheme.soft,
                      onPressed: () {
                        _leaving = true;
                        _settleTimer?.cancel();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FlutterMap(
                        key: const ValueKey('hito-location-map'),
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: widget.initial.point,
                          initialZoom: 16,
                          minZoom: 4,
                          maxZoom: 19,
                          cameraConstraint: CameraConstraint.containCenter(
                            bounds: LatLngBounds(
                              const LatLng(
                                -HitoLocationDraft.maximumLatitude,
                                -180,
                              ),
                              const LatLng(
                                HitoLocationDraft.maximumLatitude,
                                180,
                              ),
                            ),
                          ),
                          backgroundColor: PiloFamilyTheme.mapBackground,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                          onMapReady: () {
                            _ready = true;
                            _positionChanged(_map.camera, false);
                          },
                          onPositionChanged: _positionChanged,
                          onMapEvent: _mapEvent,
                          onTap: (_, point) {
                            if (_ready) _map.move(point, _map.camera.zoom);
                          },
                        ),
                        children: const [LabMapBasemap()],
                      ),
                      IgnorePointer(
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _pinLift,
                            builder: (_, _) => PiloHitoPlacementPin(
                              lift: _reduceMotion ? 0 : _pinLift.value,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Column(
                          children: [
                            _MapControl(
                              controlKey: const ValueKey(
                                'hito-location-original',
                              ),
                              tooltip: 'Volver al punto original',
                              icon: Icons.center_focus_strong_rounded,
                              onPressed: () {
                                if (_ready) {
                                  _map.move(widget.initial.point, 16);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            _MapControl(
                              tooltip: 'Acercar mapa',
                              icon: Icons.add_rounded,
                              onPressed: () => _zoom(1),
                            ),
                            const SizedBox(height: 8),
                            _MapControl(
                              tooltip: 'Alejar mapa',
                              icon: Icons.remove_rounded,
                              onPressed: () => _zoom(-1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Mueve el mapa o toca el lugar del hito.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      draft.label,
                      key: const ValueKey('hito-location-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_point.latitude.toStringAsFixed(5)}, '
                      '${_point.longitude.toStringAsFixed(5)}',
                      key: const ValueKey('hito-location-coordinates'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('hito-location-confirm'),
                      onPressed: _confirm,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 52),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 22),
                      label: const Text('Usar este punto'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared placement graphic for the picker and inline map creation. The ground
/// anchor is the centre of this 72×72 widget; callers animate [lift] from 0 to 1
/// and use 0 when reduced motion is enabled. Animation never changes geography.
class PiloHitoPlacementPin extends StatelessWidget {
  const PiloHitoPlacementPin({super.key, this.lift = 0})
    : assert(lift >= 0 && lift <= 1);
  final double lift;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 72,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          key: const ValueKey('hito-location-ground-shadow'),
          size: const Size(40, 16),
          painter: _LocationGroundPainter(lift),
        ),
        Transform.translate(
          // At rest, the painted tip marks MapCamera.center exactly. During
          // movement only the visual pin lifts; its ground anchor stays fixed.
          offset: Offset(0, -24 - 12 * lift),
          child: Transform.scale(
            scale: 1 + .035 * lift,
            alignment: Alignment.bottomCenter,
            child: Semantics(
              label: 'Punto seleccionado',
              child: const CustomPaint(
                key: ValueKey('hito-location-fixed-pin'),
                size: Size(36, 48),
                painter: _LocationPinPainter(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LocationGroundPainter extends CustomPainter {
  const _LocationGroundPainter(this.lift);
  final double lift;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: 12 + 10 * lift,
        height: 4 + 2 * lift,
      ),
      Paint()
        ..color = PiloFamilyTheme.ink.withValues(alpha: .18 - .07 * lift)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.2 + 1.8 * lift),
    );
    if (lift > 0) {
      canvas.drawCircle(
        center,
        2,
        Paint()..color = PiloFamilyTheme.accentText.withValues(alpha: lift),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LocationGroundPainter oldDelegate) =>
      oldDelegate.lift != lift;
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    this.controlKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = PiloFamilyTheme.paper,
  });

  final Key? controlKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
    key: controlKey,
    tooltip: tooltip,
    style: IconButton.styleFrom(
      backgroundColor: color,
      minimumSize: const Size.square(48),
      maximumSize: const Size.square(48),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 24),
  );
}

/// Geometry ends precisely at bottom-centre so the fixed pin cannot drift
/// from the coordinate being confirmed, regardless of map zoom or pan.
class _LocationPinPainter extends CustomPainter {
  const _LocationPinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shape = Path()
      ..moveTo(18, 48)
      ..cubicTo(12, 38, 0, 27, 0, 18)
      ..cubicTo(0, 8, 8, 0, 18, 0)
      ..cubicTo(28, 0, 36, 8, 36, 18)
      ..cubicTo(36, 27, 24, 38, 18, 48)
      ..close()
      ..addOval(Rect.fromCircle(center: const Offset(18, 17), radius: 6))
      ..fillType = PathFillType.evenOdd;
    canvas.drawShadow(
      shape,
      PiloFamilyTheme.ink.withValues(alpha: .16),
      3,
      true,
    );
    canvas.drawPath(shape, Paint()..color = PiloFamilyTheme.mint);
  }

  @override
  bool shouldRepaint(covariant _LocationPinPainter oldDelegate) => false;
}
