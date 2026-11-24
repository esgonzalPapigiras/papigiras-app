import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import 'trip_bus_controller.dart';

/// Draws only the segment between two recent, confirmed fixes of the same bus.
class LiveBusMotion extends StatefulWidget {
  const LiveBusMotion({
    super.key,
    required this.position,
    required this.recent,
    required this.builder,
  });

  final TripBusPosition position;
  final bool recent;
  final Widget Function(LatLng) builder;

  @override
  State<LiveBusMotion> createState() => _LiveBusMotionState();
}

class _LiveBusMotionState extends State<LiveBusMotion>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(vsync: this, value: 1);
  late LatLng _from = widget.position.coordinate;
  bool _reduceMotion = false;

  LatLng at(LatLng end) {
    final t = _motion.value;
    if (t == 1) return end;
    return LatLng(
      _from.latitude + (end.latitude - _from.latitude) * t,
      _from.longitude + (end.longitude - _from.longitude) * t,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _motion.value = 1;
  }

  @override
  void didUpdateWidget(LiveBusMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.position;
    final next = widget.position;
    if (_reduceMotion ||
        !oldWidget.recent ||
        !widget.recent ||
        old.coordinatorId != next.coordinatorId) {
      _motion.value = 1;
      return;
    }
    if (next.coordinate == old.coordinate) return;
    final elapsed = old.recordedAt == null
        ? null
        : next.recordedAt?.difference(old.recordedAt!);
    if (elapsed == null ||
        elapsed <= Duration.zero ||
        elapsed > const Duration(seconds: 15) ||
        (next.coordinate.longitude - old.coordinate.longitude).abs() > 180 ||
        const Distance()(old.coordinate, next.coordinate) > 750) {
      _motion.value = 1;
      return;
    }
    _from = at(old.coordinate);
    _motion.duration = Duration(
      milliseconds: elapsed.inMilliseconds.clamp(1, 5000),
    );
    _motion.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (_, __) => widget.builder(at(widget.position.coordinate)),
  );

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }
}
