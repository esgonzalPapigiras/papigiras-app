import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/pages/coordinator/detailbinnacleCoodinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class BitacoraCoordScreen extends StatefulWidget {
  const BitacoraCoordScreen({super.key, required this.login});

  final TourSales login;

  @override
  State<BitacoraCoordScreen> createState() => _BitacoraCoordScreenState();
}

class _BitacoraCoordScreenState extends State<BitacoraCoordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  List<ConsolidatedTourSalesDTO> _entries = [];
  bool _loading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _fetchEntries() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final result = await _provider.getBinnacle(
        widget.login.tourSalesId.toString(),
      );
      if (mounted) setState(() => _entries = result);
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
              'Bitácora',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar bitácora',
            onPressed: _loading ? null : _fetchEntries,
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
    if (_entries.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty) {
      return _EmptyState(hasError: _hasError, onRetry: _fetchEntries);
    }
    return RefreshIndicator(
      onRefresh: _fetchEntries,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        itemCount: _entries.length + (_hasError ? 1 : 0),
        itemBuilder: (context, index) {
          if (_hasError && index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('No se pudo actualizar la bitácora.'),
            );
          }
          final entryIndex = index - (_hasError ? 1 : 0);
          return _TimelineEntry(
            entry: _entries[entryIndex],
            isLast: entryIndex == _entries.length - 1,
            onOpen: () => _openDetail(_entries[entryIndex]),
          );
        },
      ),
    );
  }

  Future<void> _openDetail(ConsolidatedTourSalesDTO entry) async {
    final changed = await Navigator.of(context).push<dynamic>(
      buildCoordinatorRoute(
        DetalleBitacoraCoordScreen(
          idHito: entry.binnacleDetailId.toString(),
          login: widget.login,
          canModify: entry.canModify,
        ),
      ),
    );
    if (changed == true && mounted) await _fetchEntries();
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.entry,
    required this.isLast,
    required this.onOpen,
  });

  final ConsolidatedTourSalesDTO entry;
  final bool isLast;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: PapigirasColors.mint,
                    shape: BoxShape.circle,
                    border: Border.all(color: PapigirasColors.teal, width: 3),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: PapigirasColors.line,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PapigirasColors.soft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateAndTime(entry),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PapigirasColors.teal,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    entry.binnacleTitulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 17,
                        color: PapigirasColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          entry.binnacleUbicacion,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    entry.author == null
                        ? 'Autor: registro histórico'
                        : 'Autor: ${entry.author!.fullName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Ver detalle'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateAndTime(ConsolidatedTourSalesDTO entry) {
    final parts = entry.binnacleFecha.split('/');
    final date =
        parts.length >= 2 ? parts.take(2).join('/') : entry.binnacleFecha;
    return '$date · ${entry.binnacleHora}';
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
            const Icon(Icons.route_outlined,
                size: 48, color: PapigirasColors.teal),
            const SizedBox(height: 14),
            Text(
              hasError
                  ? 'No pudimos cargar la bitácora.'
                  : 'Todavía no hay hitos en esta gira.',
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
