import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class CountDownCoordScreen extends StatefulWidget {
  const CountDownCoordScreen({super.key, required this.login});

  final TourSales login;

  @override
  State<CountDownCoordScreen> createState() => _CountDownCoordScreenState();
}

class _CountDownCoordScreenState extends State<CountDownCoordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  List<_CounterPassenger> _passengers = [];
  bool _loading = false;
  bool _hasError = false;
  bool _scanning = false;
  String? _feedback;

  int get _verified => _passengers.where((item) => item.verified).length;

  @override
  void initState() {
    super.initState();
    _fetchPassengers();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        _passengers = result.map(_CounterPassenger.fromPassenger).toList()
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanQrCode() async {
    if (_scanning || _loading || _passengers.isEmpty) return;
    setState(() => _scanning = true);
    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const QRViewExample()),
      );
      if (!mounted || result == null) return;
      if (result.trim().isEmpty) {
        _showFeedback('No se pudo leer el QR. Vuelve a intentarlo.');
      } else {
        _markPassenger(result.trim());
      }
    } catch (_) {
      if (mounted) _showFeedback('No pudimos abrir el lector QR.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _resetCounter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Reiniciar el conteo?'),
        content: const Text(
          'Todos los pasajeros quedarán pendientes de verificar en esta pantalla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      for (final passenger in _passengers) {
        passenger.verified = false;
      }
      _feedback = 'Conteo reiniciado.';
    });
  }

  void _markPassenger(String id) {
    final index = _passengers.indexWhere((item) => item.id == id);
    if (index < 0) {
      _showFeedback('Este QR no corresponde a un pasajero de esta gira.');
      return;
    }
    if (_passengers[index].verified) {
      _showFeedback('${_passengers[index].name} ya está contabilizado.');
      return;
    }
    setState(() {
      _passengers[index].verified = true;
      _feedback = '${_passengers[index].name}: contabilizado.';
    });
  }

  void _showFeedback(String message) => setState(() => _feedback = message);

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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
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
              'Contador',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar pasajeros',
            onPressed: _loading ? null : _fetchPassengers,
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
      return _EmptyState(hasError: _hasError, onRetry: _fetchPassengers);
    }
    return RefreshIndicator(
      onRefresh: _fetchPassengers,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          _buildCounterCard(),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _scanning ? null : _scanQrCode,
            icon: _scanning
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_scanner_rounded),
            label: Text(_scanning ? 'Abriendo lector…' : 'Escanear QR'),
          ),
          TextButton(
            onPressed: _resetCounter,
            child: const Text('Reiniciar conteo'),
          ),
          if (_feedback != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PapigirasColors.soft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(_feedback!, textAlign: TextAlign.center),
            ),
          for (var index = 0; index < _passengers.length; index++)
            _buildPassenger(index),
        ],
      ),
    );
  }

  Widget _buildCounterCard() {
    final complete = _verified == _passengers.length;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: PapigirasColors.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Text(
            '$_verified / ${_passengers.length}',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color:
                      complete ? PapigirasColors.mint : PapigirasColors.surface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            complete ? 'Todos contabilizados' : 'Pasajeros contabilizados',
            style: const TextStyle(color: PapigirasColors.surface),
          ),
        ],
      ),
    );
  }

  Widget _buildPassenger(int index) {
    final passenger = _passengers[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color:
            passenger.verified ? PapigirasColors.soft : PapigirasColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PapigirasColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              passenger.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Switch(
            value: passenger.verified,
            onChanged: (value) => setState(() {
              passenger.verified = value;
              _feedback = value
                  ? '${passenger.name}: contabilizado.'
                  : '${passenger.name}: pendiente.';
            }),
          ),
        ],
      ),
    );
  }
}

class _CounterPassenger {
  _CounterPassenger(
      {required this.id, required this.name, required this.verified});

  factory _CounterPassenger.fromPassenger(PassengerList passenger) {
    final name = [passenger.passengerName, passenger.passengerApellidos]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    return _CounterPassenger(
      id: passenger.passengerId.toString(),
      name: name.isEmpty ? 'Pasajero sin nombre' : name,
      verified: passenger.passengerverificate,
    );
  }

  final String id;
  final String name;
  bool verified;
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
            const Icon(Icons.qr_code_scanner_rounded,
                size: 48, color: PapigirasColors.teal),
            const SizedBox(height: 14),
            Text(
              hasError
                  ? 'No pudimos cargar el contador.'
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

class QRViewExample extends StatefulWidget {
  const QRViewExample({super.key});

  @override
  State<QRViewExample> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final qrKey = GlobalKey(debugLabel: 'QR');
  StreamSubscription<Barcode>? _subscription;
  bool _handled = false;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          QRView(key: qrKey, onQRViewCreated: _onCreated),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton(
                tooltip: 'Cerrar lector',
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
          const Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(color: PapigirasColors.mint, width: 3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onCreated(QRViewController controller) {
    _subscription = controller.scannedDataStream.listen((scan) async {
      if (_handled) return;
      _handled = true;
      await controller.pauseCamera();
      await _subscription?.cancel();
      _subscription = null;
      final id = extractTourPassenger(scan.code ?? '');
      if (mounted) Navigator.of(context).pop(id ?? '');
    });
  }
}

String? extractTourPassenger(String raw) {
  try {
    final parsed = json.decode(raw);
    if (parsed is Map && parsed['url'] is String) {
      return Uri.parse(parsed['url'] as String)
          .queryParameters['tourPassenger'];
    }
  } catch (_) {}
  try {
    final parameter = Uri.parse(raw).queryParameters['tourPassenger'];
    if (parameter != null) return parameter;
  } catch (_) {}
  return RegExp(r'tourPassenger=([^&\s]+)').firstMatch(raw)?.group(1);
}
