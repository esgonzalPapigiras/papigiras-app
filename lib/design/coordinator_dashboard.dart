import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/TourSales.dart';

class CoordinatorDashboardView extends StatelessWidget {
  const CoordinatorDashboardView({
    super.key,
    required this.tour,
    required this.passengerCounts,
    required this.onMenu,
    required this.onProfile,
    required this.onNewHito,
    required this.onCounter,
    required this.onPassengers,
    required this.onActivities,
    required this.onMedicalRecords,
    required this.onCrew,
    required this.onDocuments,
    required this.onDiary,
  });

  final TourSales tour;
  final Future<Map<String, int>> passengerCounts;
  final VoidCallback onMenu;
  final VoidCallback onProfile;
  final VoidCallback onNewHito;
  final VoidCallback onCounter;
  final VoidCallback onPassengers;
  final VoidCallback onActivities;
  final VoidCallback onMedicalRecords;
  final VoidCallback onCrew;
  final VoidCallback onDocuments;
  final VoidCallback onDiary;

  String get _coordinatorName => tour.tourTripulationNameId.trim();

  String get _tripDescription => [
        tour.nameClient.trim(),
        tour.courseClient.trim(),
        if (tour.seasonClient > 0) '${tour.seasonClient}',
      ].where((value) => value.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(context),
        const SizedBox(height: 18),
        _tourHeading(context),
        const SizedBox(height: 16),
        _passengerSummary(context),
        const SizedBox(height: 12),
        _secondaryActions(context),
      ],
    );
    final actions = _primaryActions(context, stacked: largeText);

    return LayoutBuilder(
      builder: (context, bounds) {
        final scrollAll = bounds.maxHeight < 430 || largeText;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: scrollAll
                ? SingleChildScrollView(
                    key: const PageStorageKey('coordinator-home-scroll'),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                    child: Column(
                      children: [content, const SizedBox(height: 12), actions],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          key: const PageStorageKey('coordinator-home-scroll'),
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                          child: content,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                        child: actions,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _toolbar(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onProfile,
          child: const CircleAvatar(
            radius: 28,
            backgroundColor: PapigirasColors.soft,
            backgroundImage: AssetImage('assets/profile.jpg'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _coordinatorName.isEmpty ? 'Mi perfil' : _coordinatorName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Coordinador/a · Mi perfil',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Menú de la cuenta',
          style: IconButton.styleFrom(
            backgroundColor: PapigirasColors.soft,
            minimumSize: const Size.square(44),
          ),
          onPressed: onMenu,
          icon: const Icon(Icons.menu_rounded, size: 22),
        ),
      ],
    );
  }

  Widget _tourHeading(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tour.tourCode.trim().isEmpty ? 'Mi gira' : tour.tourCode,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              tooltip: 'Información de la gira',
              style: IconButton.styleFrom(
                backgroundColor: PapigirasColors.soft,
                minimumSize: const Size.square(44),
              ),
              onPressed: () => _showTripDetails(context),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
            ),
          ],
        ),
        if (_tripDescription.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            _tripDescription,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: PapigirasColors.muted),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DatePill(
                label: 'Salida',
                value: _displayDate(tour.tourSalesInit),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: PapigirasColors.muted,
              ),
            ),
            Expanded(
              child: _DatePill(
                label: 'Regreso',
                value: _displayDate(tour.tourSalesFinal),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _passengerSummary(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: passengerCounts,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final counts = snapshot.data ?? const <String, int>{};
        final students = (counts['M'] ?? 0) + (counts['F'] ?? 0);
        final companions = (counts['AM'] ?? 0) + (counts['AF'] ?? 0);
        return Material(
          color: PapigirasColors.soft,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPassengers,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pasajeros',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (loading)
                    const LinearProgressIndicator()
                  else if (snapshot.hasError)
                    Text(
                      'No se pudieron cargar los pasajeros',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: PapigirasColors.danger),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _CountValue(
                            label: 'Alumnos',
                            value: students,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CountValue(
                            label: 'Acompañantes',
                            value: companions,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _secondaryActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompactAction(
            icon: Icons.event_note_outlined,
            label: 'Actividades',
            onTap: onActivities,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactAction(
            icon: Icons.medical_information_outlined,
            label: 'Fichas médicas',
            onTap: onMedicalRecords,
          ),
        ),
      ],
    );
  }

  Widget _primaryActions(BuildContext context, {required bool stacked}) {
    final create = Material(
      color: PapigirasColors.mint,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onNewHito,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nuevo hito',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Publica una actualización de la gira',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              CircleAvatar(
                radius: 20,
                backgroundColor: PapigirasColors.ink,
                child: Icon(Icons.add_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
    final counter = _CompactAction(
      icon: Icons.qr_code_scanner_rounded,
      label: 'Contador',
      onTap: onCounter,
    );
    if (stacked) {
      return Column(children: [create, const SizedBox(height: 8), counter]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: create),
          const SizedBox(width: 8),
          SizedBox(width: 92, child: counter),
        ],
      ),
    );
  }

  Future<void> _showTripDetails(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tour.tourCode,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              if (_tripDescription.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_tripDescription),
              ],
              const SizedBox(height: 16),
              _SheetAction(
                icon: Icons.person_outline_rounded,
                label: 'Mi perfil',
                onTap: () {
                  Navigator.pop(sheetContext);
                  onProfile();
                },
              ),
              _SheetAction(
                icon: Icons.directions_bus_outlined,
                label: 'Tripulación',
                onTap: () {
                  Navigator.pop(sheetContext);
                  onCrew();
                },
              ),
              _SheetAction(
                icon: Icons.folder_outlined,
                label: 'Documentos',
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDocuments();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.isEmpty ? 'Por confirmar' : value;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }
}

class CoordinatorDashboardDock extends StatelessWidget {
  const CoordinatorDashboardDock({
    super.key,
    required this.onDiary,
    required this.onCrew,
    required this.onDocuments,
  });

  final VoidCallback onDiary;
  final VoidCallback onCrew;
  final VoidCallback onDocuments;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 500;
    final items = [
      (label: 'Inicio', icon: Icons.home_rounded, onTap: () {}),
      (label: 'Bitácora', icon: Icons.auto_stories_rounded, onTap: onDiary),
      (label: 'Tripulación', icon: Icons.directions_bus_rounded, onTap: onCrew),
      (
        label: 'Documentos',
        icon: Icons.folder_open_rounded,
        onTap: onDocuments
      ),
    ];
    return Material(
      color: PapigirasColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: LayoutBuilder(
            builder: (context, bounds) {
              const gap = 7.0;
              final diameter = ((bounds.maxWidth - 3 * gap) / 4).clamp(
                44.0,
                compact ? 52.0 : 92.0,
              );
              final showLabels = !compact;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (index, item) in items.indexed) ...[
                    if (index > 0) const SizedBox(width: gap),
                    SizedBox.square(
                      dimension: diameter,
                      child: TextButton(
                        onPressed: item.onTap,
                        style: TextButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          backgroundColor: index == 0
                              ? PapigirasColors.mint
                              : const Color(0xFFECEDEC),
                          foregroundColor: PapigirasColors.ink,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.icon, size: 23),
                            if (showLabels) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PapigirasColors.soft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      );
}

class _CountValue extends StatelessWidget {
  const _CountValue({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_rounded),
        onTap: onTap,
      );
}
