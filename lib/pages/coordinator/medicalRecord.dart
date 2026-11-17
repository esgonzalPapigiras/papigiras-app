import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecordScreenEditCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class MedicalCoordScreen extends StatefulWidget {
  const MedicalCoordScreen({super.key, required this.login});

  final TourSales login;

  @override
  State<MedicalCoordScreen> createState() => _MedicalCoordScreenState();
}

class _MedicalCoordScreenState extends State<MedicalCoordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
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
    _provider.dispose();
    super.dispose();
  }

  Future<void> _fetchMedicalRecords() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final passengers = await _provider.getListPassenger(_tourId);
      if (!mounted) return;
      setState(() => _passengers = passengers);
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
            child: Text(
              'Fichas médicas',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
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
    );
  }

  Widget _buildContent() {
    if (_passengers.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_passengers.isEmpty) {
      return _EmptyState(
        hasError: _hasError,
        onRetry: _fetchMedicalRecords,
      );
    }

    final ordered = [..._passengers]..sort((a, b) {
        final lastA = (a.passengerApellidos ?? '').trim().toLowerCase();
        final lastB = (b.passengerApellidos ?? '').trim().toLowerCase();
        final byLastName = lastA.compareTo(lastB);
        final comparison = byLastName == 0
            ? _passengerName(a).compareTo(_passengerName(b))
            : byLastName;
        return _ascending ? comparison : -comparison;
      });

    return RefreshIndicator(
      onRefresh: _fetchMedicalRecords,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          _buildSummary(_passengers.first),
          if (_hasError)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('No se pudieron actualizar las fichas.'),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _ascending = !_ascending),
              icon: Icon(
                _ascending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 18,
              ),
              label: Text(_ascending ? 'Apellido A–Z' : 'Apellido Z–A'),
            ),
          ),
          for (final passenger in ordered) _buildRecord(passenger),
        ],
      ),
    );
  }

  Widget _buildSummary(PassengerList passenger) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: PapigirasColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        children: [
          Text(
            '${passenger.countMedicalRecordOk} guardadas',
            style: const TextStyle(
              color: PapigirasColors.mint,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${passenger.countMedicalRecordNoOk} pendientes',
            style: const TextStyle(color: PapigirasColors.surface),
          ),
        ],
      ),
    );
  }

  Widget _buildRecord(PassengerList passenger) {
    final saved = passenger.statusMedicalRecord == 'Lleno';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor:
                    saved ? PapigirasColors.mint : PapigirasColors.surface,
                foregroundColor: PapigirasColors.ink,
                child: const Icon(Icons.medical_services_outlined, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _passengerName(passenger),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      passenger.passengerIdentification,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      saved ? 'Ficha guardada' : 'Pendiente',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: saved
                                ? PapigirasColors.teal
                                : PapigirasColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (saved) ...[
            const SizedBox(height: 8),
            _buildActions(passenger),
          ],
        ],
      ),
    );
  }

  String _passengerName(PassengerList passenger) {
    final fullName = [passenger.passengerName, passenger.passengerApellidos]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    return fullName.isEmpty ? 'Pasajero sin nombre' : fullName;
  }

  Widget _buildActions(PassengerList passenger) {
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
            final updated = await Navigator.of(context).push<bool>(
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
            if (updated == true && mounted) await _fetchMedicalRecords();
          },
        ),
        _action(
          tooltip: 'Ver ficha',
          icon: Icons.visibility_outlined,
          onPressed: () => _provider.viewDocumentMedicalRecord(
            _tourId,
            passengerId,
            context,
            identification,
          ),
        ),
        _action(
          tooltip: 'Descargar ficha',
          icon: Icons.download_rounded,
          onPressed: () => _runDocumentAction(
            () => _provider.downloadDocumentMedicalRecord(
              _tourId,
              passengerId,
              identification,
            ),
            success: 'Documento descargado.',
            failure: 'No se pudo descargar la ficha.',
          ),
        ),
        _action(
          tooltip: 'Compartir ficha',
          icon: Icons.share_outlined,
          onPressed: () => _runDocumentAction(
            () => _provider.shareDocumentMedicalRecord(
              _tourId,
              passengerId,
              identification,
            ),
            failure: 'No se pudo compartir la ficha.',
          ),
        ),
      ],
    );
  }

  Future<void> _runDocumentAction(
    Future<void> Function() action, {
    String? success,
    required String failure,
  }) async {
    try {
      await action();
      if (mounted && success != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure)));
      }
    }
  }

  Widget _action({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(backgroundColor: PapigirasColors.surface),
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.medical_information_outlined,
              size: 48,
              color: PapigirasColors.teal,
            ),
            const SizedBox(height: 14),
            Text(
              hasError
                  ? 'No se pudieron cargar las fichas médicas.'
                  : 'Esta gira todavía no tiene pasajeros.',
              textAlign: TextAlign.center,
            ),
            if (hasError) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
