import 'dart:convert';

import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona una gira'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: FutureBuilder<List<CoordinatorTour>>(
          future: _toursFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _message('No se pudieron cargar tus giras.');
            }
            final tours = snapshot.data ?? const <CoordinatorTour>[];
            if (tours.isEmpty) {
              return _message('No tienes giras activas asignadas.');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tours.length,
              itemBuilder: (context, index) {
                final tour = tours[index];
                final isLoading = _loadingTourId == tour.tourId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      '${tour.clientName} ${tour.course}'.trim(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${tour.tourCode}\n${tour.startDate} — ${tour.endDate}',
                    ),
                    isThreeLine: true,
                    trailing: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right, color: Colors.teal),
                    onTap: isLoading ? null : () => _selectTour(tour),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _message(String message) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
