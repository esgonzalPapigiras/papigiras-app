import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../design/apple_design_trial.dart';
import '../design/pilo_family_theme.dart';
import '../dto/tourTripulation.dart';
import '../provider/coordinatorProvider.dart';
import 'crew_avatar.dart';
import 'crew_coordinator.dart';
import 'trip_crew_controller.dart';

/// The same content and identity/photo rules for families and coordinators.
class TripCrewView extends StatefulWidget {
  const TripCrewView({
    super.key,
    required this.tourId,
    this.provider,
    this.piloHeader,
  });
  final int tourId;
  final CoordinatorProviders? provider;
  final Widget Function(VoidCallback? refresh)? piloHeader;
  @override
  State<TripCrewView> createState() => _TripCrewViewState();
}

class _TripCrewViewState extends State<TripCrewView> {
  late TripCrewController _controller;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _controller = TripCrewController(
      tourId: widget.tourId,
      provider: widget.provider,
    )..addListener(_changed);
    _controller.refresh();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant TripCrewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tourId != widget.tourId ||
        oldWidget.provider != widget.provider) {
      _controller.removeListener(_changed);
      _controller.dispose();
      _bind();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pilo = widget.piloHeader != null;
    final refresh = _controller.loading ? null : _controller.refresh;
    return ColoredBox(
      color: pilo ? PiloFamilyTheme.paper : AppleTrialColors.surface,
      child: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          key: PageStorageKey('crew-${widget.tourId}'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (widget.piloHeader case final header?)
              header(refresh)
            else
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('Tripulación', style: t.headlineSmall),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar tripulación',
                    onPressed: refresh,
                    icon: const Icon(
                      CupertinoIcons.arrow_clockwise,
                      color: AppleTrialColors.accent,
                    ),
                  ),
                ],
              ),
            SizedBox(height: pilo ? 4 : 16),
            if (_controller.loading && !_controller.initialized)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Cargando tripulación',
                  ),
                ),
              )
            else ...[
              if (_controller.loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  semanticsLabel: 'Actualizando tripulación',
                ),
              if (_controller.transportError)
                _error('No pudimos actualizar el bus y los conductores.'),
              if (_controller.buses.isNotEmpty)
                for (final bus in _controller.buses) ...[
                  _BusCard(bus: bus, pilo: pilo),
                  const SizedBox(height: 12),
                ]
              else if (!_controller.transportError)
                const _EmptySection(
                  icon: CupertinoIcons.bus,
                  title: 'Bus por confirmar',
                  message:
                      'Los datos aparecerán aquí cuando estén registrados.',
                ),
              const SizedBox(height: 12),
              _heading('Coordinación'),
              if (_controller.crewError)
                _error('No pudimos actualizar los coordinadores.'),
              if (_controller.coordinators.isEmpty && !_controller.crewError)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Aún no hay coordinadores asignados.',
                    style: TextStyle(color: AppleTrialColors.secondary),
                  ),
                ),
              for (var i = 0; i < _controller.coordinators.length; i++) ...[
                _coordinator(_controller.coordinators[i]),
                if (!pilo && i < _controller.coordinators.length - 1)
                  const Divider(indent: 80, height: 1),
              ],
              const SizedBox(height: 22),
              _heading(
                _controller.drivers.length == 1 ? 'Conductor' : 'Conductores',
              ),
              if (_controller.drivers.isEmpty && !_controller.transportError)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Aún no hay conductores registrados.',
                    style: TextStyle(color: AppleTrialColors.secondary),
                  ),
                ),
              for (var i = 0; i < _controller.drivers.length; i++) ...[
                _PersonRow(
                  avatar: pilo
                      ? const CircleAvatar(
                          radius: 24,
                          backgroundColor: PiloFamilyTheme.paper,
                          foregroundColor: PiloFamilyTheme.ink,
                          child: Icon(Icons.person_rounded),
                        )
                      : const CrewAvatar(bus: false),
                  name: _controller.drivers[i].tourTripulationNameId,
                  rut: _controller.drivers[i].tourTripulationIdentificationId,
                  pilo: pilo,
                ),
                if (!pilo && i < _controller.drivers.length - 1)
                  const Divider(indent: 80, height: 1),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _heading(String title) => Semantics(
    header: true,
    child: Text(
      title,
      style: widget.piloHeader != null
          ? PiloFamilyTheme.display(27)
          : Theme.of(context).textTheme.titleMedium,
    ),
  );
  Widget _error(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        TextButton.icon(
          onPressed: _controller.loading ? null : _controller.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    ),
  );
  Widget _coordinator(CrewCoordinator person) => _PersonRow(
    avatar: person.id == null
        ? _Initials(name: person.name)
        : FutureBuilder<Uint8List?>(
            future: _controller.photo(person.id!),
            builder: (context, snapshot) {
              // Clear stale pixels immediately when a refreshed identity/photo is loading.
              final bytes =
                  snapshot.connectionState == ConnectionState.done &&
                      !snapshot.hasError
                  ? snapshot.data
                  : null;
              return SizedBox.square(
                key: ValueKey('crew-photo-${person.id}'),
                dimension: 64,
                child: ClipOval(
                  child: bytes == null
                      ? _Initials(name: person.name)
                      : Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          width: 64,
                          height: 64,
                          cacheWidth:
                              (64 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          semanticLabel: 'Foto de ${person.name}',
                          errorBuilder: (_, _, _) =>
                              _Initials(name: person.name),
                        ),
                ),
              );
            },
          ),
    name: person.name,
    rut: person.rut,
    pilo: widget.piloHeader != null,
  );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.avatar,
    required this.name,
    required this.rut,
    this.pilo = false,
  });
  final Widget avatar;
  final String name;
  final String rut;
  final bool pilo;
  @override
  Widget build(BuildContext context) => Container(
    margin: pilo ? const EdgeInsets.only(top: 10) : null,
    padding: pilo
        ? const EdgeInsets.symmetric(vertical: 12, horizontal: 14)
        : const EdgeInsets.symmetric(vertical: 15),
    decoration: pilo
        ? BoxDecoration(
            color: PiloFamilyTheme.soft,
            borderRadius: BorderRadius.circular(28),
          )
        : null,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        avatar,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.trim().isEmpty ? 'Nombre pendiente' : name.trim(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (rut.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  rut.trim(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: pilo
                        ? PiloFamilyTheme.secondary
                        : AppleTrialColors.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = words
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    return Semantics(
      label: 'Perfil de $name, sin foto disponible',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE7F3EF),
          ),
          child: Text(
            initials.isEmpty ? '—' : initials,
            textScaler: TextScaler.noScaling,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppleTrialColors.accent),
          ),
        ),
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.bus, this.pilo = false});
  final TourTripulation bus;
  final bool pilo;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    String value(String text) =>
        text.trim().isEmpty ? 'Por confirmar' : text.trim();
    return Container(
      key: ValueKey('crew-bus-${bus.tourTripulationBusPatent}'),
      decoration: BoxDecoration(
        color: pilo ? PiloFamilyTheme.ink : const Color(0xFFEAF4F0),
        borderRadius: BorderRadius.circular(pilo ? 36 : 24),
      ),
      padding: EdgeInsets.all(pilo ? 20 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pilo) ...[
            const CircleAvatar(
              radius: 26,
              backgroundColor: PiloFamilyTheme.mint,
              foregroundColor: PiloFamilyTheme.ink,
              child: Icon(Icons.directions_bus_rounded, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              'Bus de la gira',
              style: PiloFamilyTheme.display(32, color: PiloFamilyTheme.paper),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (!pilo) ...[
                const CrewAvatar(bus: true, size: 72),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pilo ? 'Patente' : 'Bus · Patente',
                      style: pilo
                          ? t.bodySmall?.copyWith(color: PiloFamilyTheme.onDark)
                          : t.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value(bus.tourTripulationBusPatent),
                      style: pilo
                          ? t.titleLarge?.copyWith(color: PiloFamilyTheme.paper)
                          : t.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        bus.tourTripulationBusBrand,
                        bus.tourTripulationBusModel,
                      ].where((s) => s.trim().isNotEmpty).join(' · '),
                      style: pilo
                          ? t.bodyMedium?.copyWith(
                              color: PiloFamilyTheme.onDark,
                            )
                          : t.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: pilo ? const Color(0xFF3B4441) : null),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) {
              final company = _BusField(
                'Empresa',
                value(bus.tourTripulationBusEnterprise),
                dark: pilo,
              );
              final year = _BusField(
                'Año',
                value(bus.tourTripulationBusYear),
                dark: pilo,
              );
              if (box.maxWidth < 220 ||
                  MediaQuery.textScalerOf(context).scale(15) > 23) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [company, const SizedBox(height: 12), year],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: company),
                  const SizedBox(width: 14),
                  Expanded(child: year),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BusField extends StatelessWidget {
  const _BusField(this.label, this.value, {this.dark = false});
  final String label;
  final String value;
  final bool dark;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: dark
            ? Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: PiloFamilyTheme.onDark)
            : Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: dark ? PiloFamilyTheme.paper : null,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
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
        Icon(icon, size: 30, color: AppleTrialColors.secondary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppleTrialColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
