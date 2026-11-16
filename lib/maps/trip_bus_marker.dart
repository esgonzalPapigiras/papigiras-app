import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/maps/trip_bus_controller.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';

/// Presentation of an already recorded position. This widget never requests
/// location, infers sharing status or starts a network operation.
class TripBusMarker extends StatefulWidget {
  const TripBusMarker({
    super.key,
    required this.position,
    required this.recent,
    this.simulation = true,
    this.pilo = false,
    this.headingDegrees,
    this.locationLabelWidth = staleWidth,
    this.now,
  });

  final TripBusPosition position;
  final bool recent;
  final bool simulation;
  final bool pilo;

  /// Clockwise direction from the top of the map for the Pilo artwork.
  final double? headingDegrees;
  final double locationLabelWidth;
  final DateTime Function()? now;

  static const iconSize = 64.0;
  static const staleWidth = 136.0;
  static const _locationTextSize = 11.0;
  static const _locationIconSize = 12.0;
  static const _locationLineHeight = 1.2;
  static const _locationSpacing = 1.0;
  static const _locationPadding = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 3,
  );

  // Preserve the coordinate at the center of the icon when the label appears.
  static double staleHeight(BuildContext context) {
    final scaledLineHeight =
        MediaQuery.textScalerOf(context).scale(_locationTextSize) *
        _locationLineHeight;
    // Text layout rounds each rendered line to a whole logical pixel.
    final labelHeight = math.max(
      _locationIconSize,
      2 * scaledLineHeight.ceilToDouble(),
    );
    return iconSize +
        _locationSpacing +
        _locationPadding.vertical +
        labelHeight;
  }

  @override
  State<TripBusMarker> createState() => _TripBusMarkerState();
}

class _TripBusMarkerState extends State<TripBusMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _dialogOpen = false;
  static const _lastKnownTitle = 'Última ubicación conocida';

  String get _status => widget.recent
      ? widget.simulation
            ? 'Ubicación de prueba reciente'
            : 'Ubicación registrada recientemente'
      : 'Última posición registrada';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant TripBusMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final enabled =
        widget.recent &&
        !_dialogOpen &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (enabled) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _recordedTime() {
    final now = _localNow;
    final recorded = widget.pilo
        ? _lastRecordedTime(now)
        : widget.position.recordedAt?.toLocal();
    if (recorded == null) return 'Fecha no disponible';
    final date =
        '${_two(recorded.day)}/${_two(recorded.month)}/${recorded.year}';
    final time = '${_two(recorded.hour)}:${_two(recorded.minute)}';
    if (widget.pilo) {
      final day = DateUtils.isSameDay(recorded, now) ? 'Hoy' : date;
      return '$day a las $time';
    }
    return '$date · $time:${_two(recorded.second)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  DateTime get _localNow => (widget.now?.call() ?? DateTime.now()).toLocal();

  DateTime? _lastRecordedTime(DateTime now) {
    final recorded = widget.position.recordedAt?.toLocal();
    return recorded == null || recorded.isAfter(now) ? null : recorded;
  }

  String _lastLocationLabel() {
    final now = _localNow;
    final recorded = _lastRecordedTime(now);
    if (recorded == null) return 'Sin hora';
    if (DateUtils.isSameDay(recorded, now)) {
      final age = now.difference(recorded);
      if (age.inHours > 0) return 'Hace ${age.inHours} h';
      if (age.inMinutes > 0) return 'Hace ${age.inMinutes} min';
      return 'Hace <1 min';
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (DateUtils.isSameDay(recorded, yesterday)) return 'Ayer';
    final localizations = MaterialLocalizations.of(context);
    return recorded.year == now.year
        ? localizations.formatShortMonthDay(recorded)
        : localizations.formatCompactDate(recorded);
  }

  Future<void> _showDetails() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    _syncPulse();
    try {
      await showDialog<void>(
        context: context,
        barrierColor: widget.pilo ? const Color(0x3D111312) : null,
        builder: (dialogContext) => widget.pilo
            ? _piloDetails(dialogContext)
            : _standardDetails(dialogContext),
      );
    } finally {
      if (mounted) {
        _dialogOpen = false;
        _syncPulse();
      }
    }
  }

  Widget _piloDetails(BuildContext context) => Dialog(
    backgroundColor: PiloFamilyTheme.paper,
    surfaceTintColor: Colors.transparent,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    constraints: const BoxConstraints(maxWidth: 288),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      _lastKnownTitle,
                      style: PiloFamilyTheme.display(21).copyWith(height: 1.06),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _recordedTime(),
                    style: const TextStyle(
                      color: PiloFamilyTheme.secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  if (widget.simulation) ...[
                    const SizedBox(height: 7),
                    const Text(
                      'Posición ficticia del LAB. No representa la ubicación real del bus.',
                      style: TextStyle(
                        color: PiloFamilyTheme.secondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.standard,
              minimumSize: const Size.square(44),
              foregroundColor: PiloFamilyTheme.ink,
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    ),
  );

  Widget _standardDetails(BuildContext context) => AlertDialog(
    backgroundColor: tripSurface,
    surfaceTintColor: Colors.transparent,
    title: const Text('Bus de la gira'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _status,
            style: const TextStyle(color: tripInk, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(_recordedTime(), style: const TextStyle(color: tripMuted)),
          const SizedBox(height: 16),
          Text(
            widget.simulation
                ? 'Posición ficticia del LAB para probar el mapa. No representa la ubicación real del bus.'
                : 'Posición registrada en la aplicación. No confirma el estado de conexión del bus.',
            style: const TextStyle(color: tripMuted, height: 1.4),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final staleLabel = widget.pilo && !widget.recent
        ? _lastLocationLabel()
        : null;
    final status = staleLabel == null
        ? _status
        : '$_lastKnownTitle. $staleLabel';
    final icon = Tooltip(
      message: status,
      excludeFromSemantics: true,
      child: GestureDetector(
        key: const ValueKey('trip-bus-marker'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _showDetails,
        child: SizedBox.square(
          dimension: TripBusMarker.iconSize,
          child: AnimatedBuilder(
            animation: _pulse,
            child: RepaintBoundary(child: _artwork()),
            builder: (context, bus) {
              final phase = _pulse.value;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (widget.recent)
                    Transform.scale(
                      key: const ValueKey('trip-bus-pulse'),
                      scale: .82 + .60 * phase,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tripTeal.withValues(
                              alpha: .85 * (1 - phase),
                            ),
                            width: 2.5,
                          ),
                          color: tripMint.withValues(alpha: .38 * (1 - phase)),
                        ),
                        child: const SizedBox.square(
                          dimension: TripBusMarker.iconSize,
                        ),
                      ),
                    ),
                  bus!,
                ],
              );
            },
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: status,
      onTap: _showDetails,
      child: ExcludeSemantics(
        child: staleLabel == null
            ? icon
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: TripBusMarker._locationSpacing),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.locationLabelWidth,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showDetails,
                      child: DecoratedBox(
                        key: const ValueKey('pilo-bus-last-location-chip'),
                        decoration: const ShapeDecoration(
                          color: PiloFamilyTheme.paper,
                          shape: StadiumBorder(),
                          shadows: [
                            BoxShadow(
                              color: Color(0x24111312),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: TripBusMarker._locationPadding,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: TripBusMarker._locationIconSize,
                                color: PiloFamilyTheme.ink,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  staleLabel,
                                  key: const ValueKey('pilo-bus-last-location'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: TripBusMarker._locationTextSize,
                                    height: TripBusMarker._locationLineHeight,
                                    fontWeight: FontWeight.w600,
                                    color: PiloFamilyTheme.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _artwork() {
    const artworkKey = ValueKey('trip-bus-illustration');
    if (!widget.pilo) {
      return const CustomPaint(
        key: artworkKey,
        size: Size.square(TripBusMarker.iconSize),
        painter: _SchoolBusPainter(),
      );
    }
    const size = 52.0;
    final minibus = Image.asset(
      'assets/maps/pilo-minibus.png',
      key: artworkKey,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const CustomPaint(
        size: Size.square(size),
        painter: _SchoolBusPainter(),
      ),
    );
    final artwork = widget.recent
        ? minibus
        : ColorFiltered(colorFilter: _grayscale, child: minibus);
    final heading = widget.headingDegrees;
    if (heading == null || !heading.isFinite) return artwork;
    return Transform.rotate(
      key: const ValueKey('trip-bus-heading'),
      angle: (heading % 360) * math.pi / 180,
      child: artwork,
    );
  }

  // Luminance weights keep the windows distinct and preserve transparency.
  static const _grayscale = ColorFilter.matrix([
    .2126,
    .7152,
    .0722,
    0,
    0,
    .2126,
    .7152,
    .0722,
    0,
    0,
    .2126,
    .7152,
    .0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
}

/// Small, locally drawn front-view school bus; no bitmap, font or network asset.
class _SchoolBusPainter extends CustomPainter {
  const _SchoolBusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final fill = Paint()..style = PaintingStyle.fill;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = tripInk;
    RRect round(double x, double y, double w, double h, double radius) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(radius),
        );
    void block(RRect shape, Color color, {bool outline = false}) {
      canvas.drawRRect(shape, fill..color = color);
      if (outline) canvas.drawRRect(shape, edge);
    }

    // Wheels and mirrors are separate silhouettes, recognisable at map scale.
    block(round(17, 44, 7, 13, 2.5), tripInk);
    block(round(40, 44, 7, 13, 2.5), tripInk);
    canvas.drawLine(const Offset(12, 24), const Offset(18, 25), edge);
    canvas.drawLine(const Offset(46, 25), const Offset(52, 24), edge);
    block(round(9, 21, 5, 11, 2), tripInk);
    block(round(50, 21, 5, 11, 2), tripInk);

    final body = round(16, 8, 32, 44, 7);
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    block(body, const Color(0xFFFFD25B), outline: true);
    block(round(22, 12, 20, 4, 1.3), tripInk);
    block(round(20, 19, 24, 14, 3), const Color(0xFFB9E6F2), outline: true);
    canvas.drawLine(const Offset(32, 19), const Offset(32, 33), edge);
    canvas.drawLine(const Offset(23, 29), const Offset(28, 31), edge);
    canvas.drawLine(const Offset(36, 31), const Offset(41, 29), edge);
    canvas.drawLine(const Offset(18, 35), const Offset(46, 35), edge);
    block(round(26, 38, 12, 2, 1), tripInk);
    block(round(26, 42, 12, 2, 1), tripInk);
    canvas.drawCircle(const Offset(21, 40), 2.6, fill..color = Colors.white);
    canvas.drawCircle(const Offset(43, 40), 2.6, fill..color = Colors.white);
    canvas.drawCircle(const Offset(21, 40), 2.6, edge);
    canvas.drawCircle(const Offset(43, 40), 2.6, edge);
    block(round(18, 47, 28, 4, 1.8), tripInk);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SchoolBusPainter oldDelegate) => false;
}
