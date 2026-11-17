import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class ListPassengerCoordScreen extends StatefulWidget {
  const ListPassengerCoordScreen({super.key, required this.login});

  final TourSales login;

  @override
  State<ListPassengerCoordScreen> createState() =>
      _ListPassengerCoordScreenState();
}

class _ListPassengerCoordScreenState extends State<ListPassengerCoordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  final _searchController = TextEditingController();
  List<PassengerList> _passengers = [];
  bool _ascending = true;
  bool _loading = false;
  bool _hasError = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchPassengers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _provider.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query != _query) setState(() => _query = query);
  }

  Future<void> _fetchPassengers() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final result = await _provider.getListPassenger(
        widget.login.tourSalesId.toString(),
      );
      if (mounted) setState(() => _passengers = result);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PassengerList> get _visiblePassengers {
    final visible = _passengers.where((passenger) {
      if (_query.isEmpty) return true;
      final searchable = [
        passenger.passengerName,
        passenger.passengerApellidos,
        passenger.passengerIdentification,
      ].whereType<String>().join(' ').toLowerCase();
      return searchable.contains(_query);
    }).toList();
    visible.sort((a, b) {
      final comparison = _displayName(a).toLowerCase().compareTo(
            _displayName(b).toLowerCase(),
          );
      return _ascending ? comparison : -comparison;
    });
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PapigirasColors.canvas,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Pasajeros',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar pasajeros',
            onPressed: _loading ? null : _fetchPassengers,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Abrir menú',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_passengers.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_passengers.isEmpty) {
      return _EmptyState(hasError: _hasError, onRetry: _fetchPassengers);
    }

    final visible = _visiblePassengers;
    return RefreshIndicator(
      onRefresh: _fetchPassengers,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o RUT',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.cancel_rounded, size: 20),
                    ),
              fillColor: PapigirasColors.soft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${visible.length} de ${_passengers.length} pasajeros',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _ascending = !_ascending),
                icon: Icon(
                  _ascending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 17,
                ),
                label: Text(_ascending ? 'A–Z' : 'Z–A'),
              ),
            ],
          ),
          if (_hasError)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('No se pudo actualizar el listado.'),
            ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No hay pasajeros que coincidan con la búsqueda.',
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final passenger in visible) _buildPassenger(passenger),
        ],
      ),
    );
  }

  Widget _buildPassenger(PassengerList passenger) {
    final hasMedicalRecord = passenger.statusMedicalRecord == 'Lleno';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: PapigirasColors.surface,
            foregroundColor: PapigirasColors.ink,
            child: const Icon(Icons.person_outline_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName(passenger),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  passenger.passengerIdentification,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Tooltip(
            message: hasMedicalRecord
                ? 'Ficha médica guardada'
                : 'Ficha médica pendiente',
            child: Icon(
              hasMedicalRecord
                  ? Icons.medical_information_rounded
                  : Icons.medical_information_outlined,
              color: hasMedicalRecord
                  ? PapigirasColors.teal
                  : PapigirasColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(PassengerList passenger) {
    final name = [passenger.passengerName, passenger.passengerApellidos]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    return name.isEmpty ? 'Pasajero sin nombre' : name;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasError, required this.onRetry});
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined,
                size: 48, color: PapigirasColors.teal),
            const SizedBox(height: 14),
            Text(
              hasError
                  ? 'No pudimos cargar los pasajeros.'
                  : 'Esta gira todavía no tiene pasajeros.',
              textAlign: TextAlign.center,
            ),
            if (hasError) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
