import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecordScreenEditCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:papigiras_app/utils/passenger_roster_data.dart';

class MedicalCoordScreen extends StatefulWidget {
  const MedicalCoordScreen({super.key, required this.login});

  final TourSales login;

  @override
  State<MedicalCoordScreen> createState() => _MedicalCoordScreenState();
}

class _MedicalCoordScreenState extends State<MedicalCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _coordinatorProvider = CoordinatorProviders();
  List<PassengerList> _passengers = [];
  bool _ascending = true;
  bool _loading = false;
  bool _hasError = false;

  String get _tourId => widget.login.tourSalesId.toString();

  @override
  void initState() {
    super.initState();
    _fetchMedicalRecords();
  }

  @override
  void dispose() {
    _coordinatorProvider.dispose();
    super.dispose();
  }

  Future<void> _fetchMedicalRecords() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final passengers = await _coordinatorProvider.getListPassenger(_tourId);
      if (!mounted) return;
      setState(() => _passengers = passengers);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      key: _scaffoldKey,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PiloSectionBar(
            title: 'Fichas médicas',
            compact: true,
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              IconButton(
                tooltip: 'Actualizar fichas',
                onPressed: _loading ? null : _fetchMedicalRecords,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Abrir menú',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ],
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    ),
  );

  Widget _buildContent() {
    if (_passengers.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_passengers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _hasError
                    ? 'No se pudieron cargar las fichas médicas.'
                    : 'Esta gira todavía no tiene pasajeros.',
                textAlign: TextAlign.center,
              ),
              if (_hasError)
                TextButton(
                  onPressed: _fetchMedicalRecords,
                  child: const Text('Reintentar'),
                ),
            ],
          ),
        ),
      );
    }

    final ordered = [..._passengers]
      ..sort((a, b) {
        final lastA = (a.passengerApellidos ?? '').trim().toLowerCase();
        final lastB = (b.passengerApellidos ?? '').trim().toLowerCase();
        final byLastName = lastA.compareTo(lastB);
        final order = byLastName == 0
            ? rosterName(a).compareTo(rosterName(b))
            : byLastName;
        return _ascending ? order : -order;
      });
    final summary = _passengers.first;
    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _fetchMedicalRecords,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summary(summary),
                    if (_hasError)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('No se pudieron actualizar las fichas.'),
                      ),
                    TextButton.icon(
                      onPressed: () => setState(() => _ascending = !_ascending),
                      icon: Icon(
                        _ascending
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 18,
                      ),
                      label: Text(_ascending ? 'Apellido A–Z' : 'Apellido Z–A'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverList.builder(
                itemCount: ordered.length,
                itemBuilder: (context, index) => _record(ordered[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(PassengerList passenger) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: PiloFamilyTheme.ink,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(
          '${passenger.countMedicalRecordOk} guardadas',
          style: const TextStyle(
            color: PiloFamilyTheme.mint,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '${passenger.countMedicalRecordNoOk} pendientes',
          style: const TextStyle(color: PiloFamilyTheme.paper),
        ),
      ],
    ),
  );

  Widget _record(PassengerList passenger) {
    final saved = hasSavedMedicalRecord(passenger);
    final name = formatStudentName(passenger.passengerName, null);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PiloFamilyTheme.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: saved
                    ? PiloFamilyTheme.mint
                    : PiloFamilyTheme.paper,
                foregroundColor: PiloFamilyTheme.ink,
                child: const Icon(Icons.medical_services_outlined, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? rosterName(passenger) : name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      passenger.passengerIdentification,
                      style: const TextStyle(color: PiloFamilyTheme.secondary),
                    ),
                    Text(
                      saved ? 'Ficha guardada' : 'Pendiente',
                      style: TextStyle(
                        color: saved
                            ? PiloFamilyTheme.accentText
                            : PiloFamilyTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (saved) ...[const SizedBox(height: 8), _actions(passenger)],
        ],
      ),
    );
  }

  Widget _actions(PassengerList passenger) {
    final passengerId = passenger.passengerId.toString();
    final identification = passenger.passengerIdentification;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _action(
          tooltip: 'Editar ficha',
          icon: Icons.edit_outlined,
          onPressed: () async {
            final wasUpdated = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => MedicalRecordScreenEditCoordinator(
                  login: widget.login,
                  idPassenger: passengerId,
                  idDocumento: identification,
                  nombrepassenger: passenger.passengerName ?? '',
                  passengerApellidos: passenger.passengerApellidos ?? '',
                ),
              ),
            );
            if (wasUpdated == true && mounted) await _fetchMedicalRecords();
          },
        ),
        _action(
          tooltip: 'Ver ficha',
          icon: Icons.visibility_outlined,
          onPressed: () => _coordinatorProvider.viewDocumentMedicalRecord(
            _tourId,
            passengerId,
            context,
            identification,
          ),
        ),
        _action(
          tooltip: 'Descargar ficha',
          icon: Icons.download_rounded,
          onPressed: () => _runPdfAction(
            () => _coordinatorProvider.downloadDocumentMedicalRecord(
              _tourId,
              passengerId,
              identification,
            ),
            'No se pudo descargar la ficha.',
          ),
        ),
        _action(
          tooltip: 'Compartir ficha',
          icon: Icons.share_outlined,
          onPressed: () => _runPdfAction(
            () => _coordinatorProvider.shareDocumentMedicalRecord(
              _tourId,
              passengerId,
              identification,
            ),
            'No se pudo compartir la ficha.',
          ),
        ),
      ],
    );
  }

  Future<void> _runPdfAction(
    Future<void> Function() run,
    String errorMessage,
  ) async {
    try {
      await run();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Widget _action({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: tooltip,
    style: IconButton.styleFrom(backgroundColor: PiloFamilyTheme.paper),
    onPressed: onPressed,
    icon: Icon(icon, size: 22),
  );
}
