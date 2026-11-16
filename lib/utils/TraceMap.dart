import 'package:flutter/material.dart';
import 'package:papigiras_app/utils/page_navigation.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_view.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';

class TraceMap extends StatefulWidget {
  const TraceMap({super.key, required this.tourCode, this.preview = false});
  final int tourCode;
  final bool preview;
  @override
  State<TraceMap> createState() => _TraceMapState();
}

class _TraceMapState extends State<TraceMap> {
  late TripMapController _controller;
  void _createController() {
    _controller = TripMapController(tourCode: widget.tourCode)..refresh();
  }

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(covariant TraceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tourCode != widget.tourCode) {
      _controller.dispose();
      _createController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TripMapView(
    controller: _controller,
    preview: widget.preview,
    onExpand: () => Navigator.of(context).push(
      buildPapiRoute(
        TraceMapFullScreen(tourCode: widget.tourCode, controller: _controller),
      ),
    ),
  );
}
