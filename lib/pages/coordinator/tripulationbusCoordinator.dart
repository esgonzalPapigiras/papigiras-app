import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class BusCrewCoorScreen extends StatefulWidget {
  const BusCrewCoorScreen({super.key, required this.login});

  final TourSales login;

  @override
  State<BusCrewCoorScreen> createState() => _BusCrewCoorScreenState();
}

class _BusCrewCoorScreenState extends State<BusCrewCoorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CoordinatorProviders _provider = CoordinatorProviders();
  List<TourTripulation> _tripulations = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTripulations();
  }

  Future<void> _loadTripulations() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tripulations = await _provider.getTripulation(
        widget.login.tourSalesId.toString(),
      );
      if (!mounted) return;
      setState(() => _tripulations = tripulations);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos cargar la tripulación.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadTripulations,
          child: ListView(
            key: PageStorageKey('crew-${widget.login.tourSalesId}'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _header(context),
              const SizedBox(height: 16),
              if (_loading && _tripulations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Cargando tripulación',
                    ),
                  ),
                )
              else ...[
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null) _errorView(context),
                if (_error == null) ..._content(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
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
              tooltip: 'Actualizar tripulación',
              onPressed: _loading ? null : _loadTripulations,
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
            'Tripulación',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Equipo a cargo de la gira',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: PapigirasColors.muted),
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context) {
    final bus = _tripulations.isEmpty ? null : _tripulations.first;
    final coordinators = _tripulations
        .where((person) => person.tourTripulationTypeId == 32)
        .toList();
    final drivers = _tripulations
        .where((person) => person.tourTripulationTypeId != 32)
        .toList();
    return [
      if (bus == null)
        const _EmptySection(
          icon: Icons.directions_bus_outlined,
          title: 'Bus por confirmar',
          message: 'Los datos aparecerán cuando estén registrados.',
        )
      else
        _BusCard(bus: bus),
      const SizedBox(height: 24),
      Text('Coordinación', style: Theme.of(context).textTheme.headlineMedium),
      if (coordinators.isEmpty)
        const _EmptyText('Aún no hay coordinadores asignados.'),
      for (final person in coordinators) _PersonCard(person: person),
      const SizedBox(height: 22),
      Text(
        drivers.length == 1 ? 'Conductor' : 'Conductores',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      if (drivers.isEmpty)
        const _EmptyText('Aún no hay conductores registrados.'),
      for (final person in drivers) _PersonCard(person: person),
    ];
  }

  Widget _errorView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadTripulations,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.bus});

  final TourTripulation bus;

  String _value(String value) =>
      value.trim().isEmpty ? 'Por confirmar' : value.trim();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PapigirasColors.ink,
        borderRadius: BorderRadius.circular(36),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: PapigirasColors.mint,
            foregroundColor: PapigirasColors.ink,
            child: Icon(Icons.directions_bus_rounded, size: 26),
          ),
          const SizedBox(height: 14),
          const Text(
            'Bus de la gira',
            style: TextStyle(
              color: PapigirasColors.surface,
              fontSize: 30,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Patente',
            style: TextStyle(color: Color(0xFFBDC7C3), fontSize: 13),
          ),
          const SizedBox(height: 3),
          Text(
            _value(bus.tourTripulationBusPatent),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: PapigirasColors.surface,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            [
              bus.tourTripulationBusBrand,
              bus.tourTripulationBusModel,
            ].where((value) => value.trim().isNotEmpty).join(' · '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFBDC7C3),
                ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF3B4441)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _BusField(
                  label: 'Empresa',
                  value: _value(bus.tourTripulationBusEnterprise),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _BusField(
                  label: 'Año',
                  value: _value(bus.tourTripulationBusYear),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusField extends StatelessWidget {
  const _BusField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFBDC7C3))),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PapigirasColors.surface,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      );
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final TourTripulation person;

  @override
  Widget build(BuildContext context) {
    final name = person.tourTripulationNameId.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: PapigirasColors.surface,
            foregroundColor: PapigirasColors.teal,
            child: Text(initials.isEmpty ? '—' : initials),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Nombre pendiente' : name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (person.tourTripulationIdentificationId.trim().isNotEmpty)
                  Text(
                    person.tourTripulationIdentificationId.trim(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: PapigirasColors.muted,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: PapigirasColors.muted),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      );
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: PapigirasColors.muted),
        ),
      );
}
