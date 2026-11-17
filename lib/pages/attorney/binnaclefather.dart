import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/binnacledetailFather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class BitacoraFatherScreen extends StatefulWidget {
  const BitacoraFatherScreen({super.key, required this.login});
  final ResponseAttorney login;

  @override
  State<BitacoraFatherScreen> createState() => _BitacoraFatherScreenState();
}

class _BitacoraFatherScreenState extends State<BitacoraFatherScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  List<ConsolidatedTourSalesDTO> _entries = [];
  bool _loading = false;
  bool _hasError = false;
  String? _drawerImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _loadEntries();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final photo = await _provider.getPicturePassenger(
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
      );
      if (mounted) {
        setState(() => _drawerImage = photo.image.isEmpty ? null : photo.image);
      }
    } catch (_) {}
  }

  Future<void> _loadEntries() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final entries =
          await _provider.getBinnacle(widget.login.tourId.toString());
      if (mounted) setState(() => _entries = entries);
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
            child: Text('Bitácora',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
          IconButton(
            tooltip: 'Actualizar bitácora',
            onPressed: _loading ? null : _loadEntries,
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
      return _EmptyState(hasError: _hasError, onRetry: _loadEntries);
    }
    return RefreshIndicator(
      onRefresh: _loadEntries,
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
            last: entryIndex == _entries.length - 1,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetalleBitacoraFatherScreen(
                  idHito: _entries[entryIndex].binnacleDetailId.toString(),
                  login: widget.login,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry(
      {required this.entry, required this.last, required this.onOpen});
  final ConsolidatedTourSalesDTO entry;
  final bool last;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final parts = entry.binnacleFecha.split('/');
    final date =
        parts.length >= 2 ? parts.take(2).join('/') : entry.binnacleFecha;
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
                if (!last)
                  Expanded(
                      child: Container(width: 2, color: PapigirasColors.line)),
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
                    '$date · ${entry.binnacleHora}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PapigirasColors.teal,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Text(entry.binnacleTitulo,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 17, color: PapigirasColors.muted),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(entry.binnacleUbicacion,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
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
                  : 'Aún no hay hitos en la bitácora.',
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
