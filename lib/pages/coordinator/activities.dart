import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/Itinerary.dart';
import 'package:papigiras_app/dto/RequestActivities.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacleaddlist.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class ActivitiesCoordScreen extends StatefulWidget {
  const ActivitiesCoordScreen({super.key, required this.login});

  final TourSales login;

  @override
  State<ActivitiesCoordScreen> createState() => _ActivitiesCoordScreenState();
}

class _ActivitiesCoordScreenState extends State<ActivitiesCoordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _participants = TextEditingController();
  final _coordinatorProvider = CoordinatorProviders();
  Itinerary? _selectedActivity;
  List<Itinerary> _itineraries = [];
  List<ActivitiesList> _activities = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchItineraries();
  }

  @override
  void dispose() {
    _participants.dispose();
    _coordinatorProvider.dispose();
    super.dispose();
  }

  Future<void> _fetchItineraries() async {
    try {
      final tour = widget.login.tourSalesId.toString();
      final itineraries = await _coordinatorProvider.getItineray(tour);
      if (!mounted) return;
      final activities = await _coordinatorProvider.getItinerayGuardados(tour);
      if (!mounted) return;
      setState(() {
        final previousId = _selectedActivity?.itineraryId;
        _itineraries = itineraries.toSet().toList();
        _activities = activities;
        _selectedActivity =
            _itineraries
                .where((activity) => activity.itineraryId == previousId)
                .firstOrNull ??
            _itineraries.firstOrNull;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos cargar las actividades.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addActivity() async {
    if (_saving || _selectedActivity == null) return;
    final quantity = int.tryParse(_participants.text);
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el número de participantes.')),
      );
      return;
    }
    final request = RequestActivities(
      activityId: _selectedActivity!.itineraryId,
      quantityPassenger: quantity,
      tourSalesId: widget.login.tourSalesId,
    );
    setState(() => _saving = true);
    try {
      await _coordinatorProvider.activitiesCreate(request);
      if (!mounted) return;
      await _fetchItineraries();
      if (!mounted) return;
      final continueToDashboard = await showDialog<bool>(
        context: _scaffoldKey.currentContext!,
        builder: (context) => AlertDialog(
          backgroundColor: PiloFamilyTheme.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Actividad agregada'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (mounted && continueToDashboard == true) {
        Navigator.of(context).push(
          buildCoordinatorRoute(
            TravelCoordinatorDashboard(login: widget.login),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos agregar la actividad.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      key: _scaffoldKey,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) => ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              CoordinatorTopBar(
                login: widget.login,
                scaffoldKey: _scaffoldKey,
                title: 'Actividades',
              ),
              ..._buildContent(context),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _buildContent(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<Itinerary>(
              key: ValueKey(_selectedActivity),
              isExpanded: true,
              itemHeight: null,
              initialValue: _selectedActivity,
              items: _itineraries.map((activity) {
                return DropdownMenuItem<Itinerary>(
                  value: activity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(activity.itinerary),
                  ),
                );
              }).toList(),
              onChanged: _loading || _saving
                  ? null
                  : (activity) => setState(() => _selectedActivity = activity),
              decoration: _fieldDecoration('Actividad'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _participants,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: _fieldDecoration('Participantes'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _selectedActivity == null || _saving
                  ? null
                  : _addActivity,
              icon: const Icon(Icons.add_rounded),
              label: Text(_saving ? 'Agregando…' : 'Agregar'),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loading && _itineraries.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Text('No hay actividades disponibles.'),
              ),
            if (_activities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Semantics(
                  header: true,
                  child: Text('Actividades guardadas', style: text.titleMedium),
                ),
              ),
          ],
        ),
      ),
      for (final entry in _activities) _activityCard(context, entry),
    ];
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: PiloFamilyTheme.soft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: PiloFamilyTheme.accentText),
    ),
  );

  Widget _activityCard(BuildContext context, ActivitiesList entry) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PiloFamilyTheme.soft,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(entry.activitiesName, style: text.bodyLarge),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  entry.quantityPassengerCheck.toString(),
                  semanticsLabel:
                      '${entry.quantityPassengerCheck} participantes',
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
