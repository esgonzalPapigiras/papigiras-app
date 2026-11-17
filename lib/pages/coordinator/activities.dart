import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _participants = TextEditingController();
  final CoordinatorProviders _provider = CoordinatorProviders();
  Itinerary? _selectedActivity;
  List<Itinerary> _itineraries = const [];
  List<ActivitiesList> _activities = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchItineraries();
  }

  @override
  void dispose() {
    _participants.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _fetchItineraries() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tourId = widget.login.tourSalesId.toString();
      final itineraries = await _provider.getItineray(tourId);
      final activities = await _provider.getItinerayGuardados(tourId);
      if (!mounted) return;
      final unique = itineraries.toSet().toList();
      final previousId = _selectedActivity?.itineraryId;
      Itinerary? selected;
      for (final item in unique) {
        if (item.itineraryId == previousId) selected = item;
      }
      setState(() {
        _itineraries = unique;
        _activities = activities;
        _selectedActivity = selected ?? (unique.isEmpty ? null : unique.first);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos cargar las actividades.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addActivity() async {
    if (_saving || _selectedActivity == null) return;
    final quantity = int.tryParse(_participants.text);
    if (quantity == null || quantity < 0) {
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
      await _provider.activitiesCreate(request);
      if (!mounted) return;
      _participants.clear();
      await _fetchItineraries();
      if (!mounted) return;
      final continueToDashboard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Actividad agregada'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
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
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _fetchItineraries,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _header(context),
              const SizedBox(height: 24),
              DropdownButtonFormField<Itinerary>(
                key: ValueKey(_selectedActivity),
                isExpanded: true,
                itemHeight: null,
                initialValue: _selectedActivity,
                items: _itineraries
                    .map(
                      (activity) => DropdownMenuItem<Itinerary>(
                        value: activity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(activity.itinerary),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loading || _saving
                    ? null
                    : (activity) =>
                        setState(() => _selectedActivity = activity),
                decoration: const InputDecoration(labelText: 'Actividad'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _participants,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Participantes'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    _selectedActivity == null || _saving ? null : _addActivity,
                icon: const Icon(Icons.add_rounded),
                label: Text(_saving ? 'Agregando…' : 'Agregar'),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                Text(_error!, textAlign: TextAlign.center),
                TextButton.icon(
                  onPressed: _fetchItineraries,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
              if (!_loading && _error == null && _itineraries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Text('No hay actividades disponibles.'),
                ),
              if (_activities.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Actividades guardadas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final entry in _activities) _activityCard(context, entry),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                style: IconButton.styleFrom(
                  backgroundColor: PapigirasColors.soft,
                  minimumSize: const Size.square(48),
                ),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Actualizar actividades',
                onPressed: _loading ? null : _fetchItineraries,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Abrir menú',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(
              'Actividades',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Registra la participación de la gira',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: PapigirasColors.muted),
          ),
        ],
      );

  Widget _activityCard(BuildContext context, ActivitiesList entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.activitiesName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            entry.quantityPassengerCheck.toString(),
            semanticsLabel: '${entry.quantityPassengerCheck} participantes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
