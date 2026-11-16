import 'package:flutter/material.dart';

import 'pilo_family_theme.dart';

/// A quick, anonymous tally. Identifying passengers belongs to the full counter.
/// The sheet owns the count, roster loading, expansion, and QR navigation.
class PiloQuickCounterView extends StatelessWidget {
  const PiloQuickCounterView({
    super.key,
    required this.count,
    required this.total,
    required this.loading,
    required this.hasError,
    required this.onIncrement,
    required this.onDecrement,
    required this.onReset,
    required this.onRetry,
    required this.onExpand,
    required this.onScan,
    required this.onClose,
    required this.scrollController,
  });

  final int count, total;
  final bool loading, hasError;
  final VoidCallback onIncrement, onDecrement, onReset, onRetry;
  final VoidCallback onExpand, onScan, onClose;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final ready = !loading && !hasError && total > 0;
    return SingleChildScrollView(
      key: const ValueKey('quick-counter-scroll'),
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Contador',
                        style: PiloFamilyTheme.display(28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('quick-counter-reset'),
                    tooltip: 'Reiniciar conteo rápido',
                    onPressed: ready && count > 0 ? onReset : null,
                    style: IconButton.styleFrom(
                      foregroundColor: PiloFamilyTheme.secondary,
                      disabledForegroundColor: PiloFamilyTheme.connectorPast,
                      minimumSize: const Size.square(44),
                      maximumSize: const Size.square(44),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.restart_alt_rounded, size: 21),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey('quick-counter-close'),
                    tooltip: 'Cerrar contador',
                    style: IconButton.styleFrom(
                      backgroundColor: PiloFamilyTheme.soft,
                      minimumSize: const Size.square(44),
                      maximumSize: const Size.square(44),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Conteo rápido',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: PiloFamilyTheme.secondary,
                ),
              ),
              const SizedBox(height: 16),
              if (loading)
                _status(
                  'Cargando pasajeros…',
                  child: const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (hasError)
                _status(
                  'No pudimos cargar los pasajeros.',
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reintentar'),
                  ),
                )
              else if (total == 0)
                _status('Aún no hay pasajeros en esta gira.')
              else if (largeText) ...[
                _value(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _decrement(ready),
                    const SizedBox(width: 24),
                    _increment(ready),
                  ],
                ),
              ] else
                Row(
                  children: [
                    _decrement(ready),
                    const SizedBox(width: 12),
                    Expanded(child: _value()),
                    const SizedBox(width: 12),
                    _increment(ready),
                  ],
                ),
              const SizedBox(height: 20),
              if (largeText)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _scan(ready),
                    const SizedBox(height: 8),
                    _expand(),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(flex: 3, child: _scan(ready)),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _expand()),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _value() => Semantics(
    key: const ValueKey('quick-counter-value'),
    liveRegion: true,
    label: 'Conteo rápido: $count de $total pasajeros',
    excludeSemantics: true,
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 48,
            height: 1.2,
            letterSpacing: -2,
            fontWeight: FontWeight.w700,
            color: PiloFamilyTheme.ink,
          ),
        ),
        Text(
          '/ $total',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            height: 1.3,
            color: PiloFamilyTheme.secondary,
          ),
        ),
      ],
    ),
  );

  Widget _decrement(bool ready) => _step(
    key: 'quick-counter-decrement',
    label: 'Restar un pasajero al conteo rápido',
    icon: Icons.remove_rounded,
    color: PiloFamilyTheme.soft,
    action: ready && count > 0 ? onDecrement : null,
  );

  Widget _increment(bool ready) => _step(
    key: 'quick-counter-increment',
    label: 'Sumar un pasajero al conteo rápido',
    icon: Icons.add_rounded,
    color: PiloFamilyTheme.mint,
    action: ready && count < total ? onIncrement : null,
  );

  Widget _step({
    required String key,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? action,
  }) => IconButton(
    key: ValueKey(key),
    tooltip: label,
    onPressed: action,
    style: IconButton.styleFrom(
      backgroundColor: color,
      disabledBackgroundColor: PiloFamilyTheme.soft,
      disabledForegroundColor: PiloFamilyTheme.connectorPast,
      foregroundColor: PiloFamilyTheme.ink,
      minimumSize: const Size.square(56),
      maximumSize: const Size.square(56),
      padding: EdgeInsets.zero,
    ),
    icon: Icon(icon, size: 28),
  );

  Widget _scan(bool ready) => FilledButton.icon(
    key: const ValueKey('quick-counter-scan'),
    onPressed: ready ? onScan : null,
    style: FilledButton.styleFrom(
      backgroundColor: PiloFamilyTheme.soft,
      foregroundColor: PiloFamilyTheme.ink,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      minimumSize: const Size(44, 48),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
    label: const Text('Escanear QR', textAlign: TextAlign.center),
  );

  Widget _expand() => TextButton.icon(
    key: const ValueKey('quick-counter-expand'),
    onPressed: onExpand,
    style: TextButton.styleFrom(
      foregroundColor: PiloFamilyTheme.accentText,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      minimumSize: const Size(44, 48),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    icon: const Icon(Icons.open_in_full_rounded, size: 17),
    label: const Text('Ampliar', textAlign: TextAlign.center),
  );

  Widget _status(String message, {Widget? child}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.35,
            color: PiloFamilyTheme.secondary,
          ),
        ),
        if (child != null) ...[const SizedBox(height: 10), child],
      ],
    ),
  );
}
