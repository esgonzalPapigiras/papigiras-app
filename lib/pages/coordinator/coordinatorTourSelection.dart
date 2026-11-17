import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/coordinator_tour_picker.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoordinatorTourSelectionScreen extends StatefulWidget {
  final CoordinatorLogin coordinator;
  final List<CoordinatorTour>? initialTours;

  const CoordinatorTourSelectionScreen({
    super.key,
    required this.coordinator,
    this.initialTours,
  });

  @override
  State<CoordinatorTourSelectionScreen> createState() =>
      _CoordinatorTourSelectionScreenState();
}

class _CoordinatorTourSelectionScreenState
    extends State<CoordinatorTourSelectionScreen> {
  final CoordinatorProviders _provider = CoordinatorProviders();
  late Future<List<CoordinatorTour>> _toursFuture;
  int? _loadingTourId;

  @override
  void initState() {
    super.initState();
    _toursFuture = widget.initialTours == null
        ? _provider.getCoordinatorTours()
        : Future.value(widget.initialTours!);
  }

  Future<void> _selectTour(CoordinatorTour tour) async {
    if (_loadingTourId != null) return;
    setState(() => _loadingTourId = tour.tourId);
    try {
      final detail = await _provider.getCoordinatorTourDetail(tour.tourId);
      final selected = TourSales.fromCoordinatorTour(
        coordinator: widget.coordinator,
        tour: detail,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selectedTourId', selected.tourSalesId);
      await prefs.setString('loginData', jsonEncode(selected.toJson()));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => TravelCoordinatorDashboard(login: selected),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loadingTourId = null);
    }
  }

  void _reloadTours() {
    setState(() => _toursFuture = _provider.getCoordinatorTours());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CoordinatorTour>>(
      future: _toursFuture,
      builder: (context, snapshot) => CoordinatorTourPicker(
        snapshot: snapshot,
        loadingTourId: _loadingTourId,
        onSelect: _selectTour,
        onRetry: _reloadTours,
      ),
    );
  }
}
