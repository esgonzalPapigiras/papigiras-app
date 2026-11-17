import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class BusCrewFatherScreen extends StatefulWidget {
  const BusCrewFatherScreen({super.key, required this.login});

  final ResponseAttorney login;

  @override
  State<BusCrewFatherScreen> createState() => _BusCrewFatherScreenState();
}

class _BusCrewFatherScreenState extends State<BusCrewFatherScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  List<TourTripulation> _crew = [];
  bool _loading = false;
  bool _hasError = false;
  String? _drawerImage;

  @override
  void initState() {
    super.initState();
    _loadDrawerImage();
    _loadCrew();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _loadDrawerImage() async {
    try {
      final photo = await _provider.getPicturePassenger(
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
      );
      if (mounted) {
        setState(() => _drawerImage = photo.image.isEmpty ? null : photo.image);
      }
    } catch (_) {
      if (mounted) setState(() => _drawerImage = null);
    }
  }

  Future<void> _loadCrew() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final result = await _provider.getTripulation(
        widget.login.tourId.toString(),
      );
      if (mounted) setState(() => _crew = result);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PapigirasColors.canvas,
      endDrawer: AppDrawerFather(
        login: widget.login,
        imageFile: null,
        imageUrl: _drawerImage,
      ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tripulación',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  'Equipo a cargo de la gira',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar tripulación',
            onPressed: _loading ? null : _loadCrew,
            icon: const Icon(Icons.refresh_rounded),
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
    if (_crew.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_crew.isEmpty) {
      return _EmptyState(hasError: _hasError, onRetry: _loadCrew);
    }
    return RefreshIndicator(
      onRefresh: _loadCrew,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _buildBusCard(_crew.first),
          const SizedBox(height: 18),
          Text('Equipo de viaje',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (_hasError)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('No se pudo actualizar la tripulación.'),
            ),
          for (var index = 0; index < _crew.length; index++)
            _buildCrewMember(_crew[index], index),
        ],
      ),
    );
  }

  Widget _buildBusCard(TourTripulation data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PapigirasColors.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: PapigirasColors.mint,
            foregroundColor: PapigirasColors.onMint,
            child: Icon(Icons.directions_bus_rounded, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bus de la gira',
                  style: TextStyle(
                    color: PapigirasColors.surface,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _busLine(
                    'Patente', data.tourTripulationBusPatent, 'Sin patente'),
                _busLine('Marca', data.tourTripulationBusBrand, 'Sin marca'),
                _busLine('Modelo', data.tourTripulationBusModel, 'Sin modelo'),
                _busLine('Año', data.tourTripulationBusYear, 'No disponible'),
                _busLine(
                  'Empresa',
                  data.tourTripulationBusEnterprise,
                  'Sin empresa',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _busLine(String label, String value, String fallback) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(color: PapigirasColors.surface, height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: PapigirasColors.mint,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: value.trim().isEmpty ? fallback : value),
          ],
        ),
      ),
    );
  }

  Widget _buildCrewMember(TourTripulation person, int index) {
    final coordinator = person.tourTripulationTypeId == 32;
    final role = coordinator ? 'Coordinador' : 'Conductor';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor:
                coordinator ? PapigirasColors.mint : PapigirasColors.surface,
            foregroundColor: PapigirasColors.ink,
            child: Icon(
              coordinator
                  ? Icons.support_agent_rounded
                  : Icons.airline_seat_recline_normal_rounded,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  person.tourTripulationNameId,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!coordinator)
                  const Text(
                    'Licencia Clase A',
                    style: TextStyle(color: PapigirasColors.muted),
                  ),
                if (person.tourTripulationIdentificationId.isNotEmpty)
                  Text(
                    person.tourTripulationIdentificationId,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
            const Icon(Icons.directions_bus_outlined,
                size: 48, color: PapigirasColors.teal),
            const SizedBox(height: 14),
            Text(
              hasError
                  ? 'No pudimos cargar la tripulación.'
                  : 'Todavía no hay tripulación asignada.',
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
