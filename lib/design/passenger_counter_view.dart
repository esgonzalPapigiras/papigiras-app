import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'pilo_family_theme.dart';

/// Presentation only. The page owns roster loading, QR decoding and counting.
class CounterPassenger {
  const CounterPassenger({
    required this.id,
    required this.name,
    required this.counted,
  });
  final String id, name;
  final bool counted;
}

enum CounterFilter { all, pending, counted }

class PassengerCounterView extends StatefulWidget {
  const PassengerCounterView({
    super.key,
    required this.passengers,
    required this.loading,
    required this.hasError,
    required this.scanning,
    required this.onScan,
    required this.onReset,
    required this.onRetry,
    required this.onToggle,
    required this.onMenu,
    this.feedback,
    this.scrollController,
    this.onBack,
  });

  final List<CounterPassenger> passengers;
  final bool loading, hasError, scanning;
  final String? feedback;
  final VoidCallback onScan, onReset, onRetry, onMenu;
  final void Function(String id, bool counted) onToggle;
  final ScrollController? scrollController;
  final VoidCallback? onBack;

  @override
  State<PassengerCounterView> createState() => _PassengerCounterViewState();
}

class _PassengerCounterViewState extends State<PassengerCounterView> {
  CounterFilter _filter = CounterFilter.all;

  IconData _icon(BuildContext context, IconData apple, IconData material) =>
      Theme.of(context).platform == TargetPlatform.iOS ? apple : material;

  @override
  Widget build(BuildContext context) {
    final counted = widget.passengers.where((p) => p.counted).length;
    final pending = widget.passengers.length - counted;
    final rows = widget.passengers
        .where(
          (p) => switch (_filter) {
            CounterFilter.all => true,
            CounterFilter.pending => !p.counted,
            CounterFilter.counted => p.counted,
          },
        )
        .toList();
    final ready = !widget.loading && !widget.hasError;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = (constraints.maxWidth - 620) / 2;
        final horizontal = inset > 20 ? inset : 20.0;
        return Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: widget.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                key: const PageStorageKey('passenger-counter-scroll'),
                slivers: [
                  SliverToBoxAdapter(
                    child: PiloSectionBar(
                      title: 'Contador',
                      compact: true,
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        6,
                        horizontal,
                        4,
                      ),
                      onBack:
                          widget.onBack ??
                          () => Navigator.of(context).maybePop(),
                      actions: [
                        IconButton(
                          key: const ValueKey('counter-reset'),
                          tooltip: 'Reiniciar contador',
                          onPressed: ready && counted > 0
                              ? widget.onReset
                              : null,
                          icon: Icon(
                            _icon(
                              context,
                              CupertinoIcons.arrow_counterclockwise,
                              Icons.restart_alt,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Menú',
                          onPressed: widget.onMenu,
                          icon: const Icon(Icons.menu_rounded),
                        ),
                      ],
                    ),
                  ),
                  if (ready && widget.passengers.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        8,
                        horizontal,
                        8,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _summary(context, counted, pending),
                            const SizedBox(height: 16),
                            if (widget.feedback != null) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(widget.feedback!),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _filters(context),
                          ],
                        ),
                      ),
                    ),
                  if (widget.loading)
                    SliverToBoxAdapter(
                      child: _state(
                        context,
                        'Cargando pasajeros…',
                        loading: true,
                      ),
                    )
                  else if (widget.hasError)
                    SliverToBoxAdapter(
                      child: _state(
                        context,
                        'No pudimos cargar los pasajeros.',
                        action: TextButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ),
                    )
                  else if (widget.passengers.isEmpty)
                    SliverToBoxAdapter(
                      child: _state(
                        context,
                        'Aún no hay pasajeros en esta gira.',
                      ),
                    )
                  else if (rows.isEmpty)
                    SliverToBoxAdapter(
                      child: _state(
                        context,
                        _filter == CounterFilter.pending
                            ? 'Todos están contabilizados.'
                            : 'Todavía no hay pasajeros contabilizados.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        0,
                        horizontal,
                        16,
                      ),
                      sliver: SliverList.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) =>
                            _passenger(context, rows[index]),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('counter-scan'),
                  onPressed:
                      ready && widget.passengers.isNotEmpty && !widget.scanning
                      ? widget.onScan
                      : null,
                  icon: Icon(
                    _icon(
                      context,
                      CupertinoIcons.qrcode_viewfinder,
                      Icons.qr_code_scanner,
                    ),
                  ),
                  label: const Text('Escanear QR'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summary(BuildContext context, int counted, int pending) {
    final total = widget.passengers.length;
    return Container(
      key: const ValueKey('counter-summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PiloFamilyTheme.ink,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total ${total == 1 ? 'pasajero' : 'pasajeros'}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: PiloFamilyTheme.onDark),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 420 &&
                  MediaQuery.textScalerOf(context).scale(15) > 23;
              final a = _metric(
                context,
                counted,
                'Contabilizados',
                'counter-counted',
                PiloFamilyTheme.mint,
              );
              final b = _metric(
                context,
                pending,
                'Faltan',
                'counter-pending',
                PiloFamilyTheme.paper,
              );
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [a, const SizedBox(height: 16), b],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: a),
                        const SizedBox(width: 20),
                        Expanded(child: b),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: total == 0 ? 0 : counted / total,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: const Color(0xFF353A38),
            color: PiloFamilyTheme.mint,
            semanticsLabel: 'Progreso del conteo',
            semanticsValue: '$counted de $total pasajeros',
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    int value,
    String label,
    String key,
    Color color,
  ) => Semantics(
    label: '$label: $value',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          key: ValueKey(key),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontSize: 34, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: PiloFamilyTheme.onDark),
        ),
      ],
    ),
  );

  Widget _filters(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final filter in CounterFilter.values)
        ChoiceChip(
          key: ValueKey('counter-filter-${filter.name}'),
          label: Text(switch (filter) {
            CounterFilter.all => 'Todos',
            CounterFilter.pending => 'Faltan',
            CounterFilter.counted => 'Contados',
          }),
          selected: _filter == filter,
          onSelected: (_) => setState(() => _filter = filter),
          showCheckmark: false,
          selectedColor: PiloFamilyTheme.mint,
          backgroundColor: PiloFamilyTheme.soft,
          side: BorderSide.none,
          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: _filter == filter ? FontWeight.w600 : FontWeight.w400,
          ),
          shape: const StadiumBorder(),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
    ],
  );

  Widget _passenger(BuildContext context, CounterPassenger p) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 16, height: 1.3),
                ),
                const SizedBox(height: 4),
                Text(
                  p.counted ? 'Contabilizado' : 'Pendiente',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: p.counted
                        ? PiloFamilyTheme.accentText
                        : PiloFamilyTheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            container: true,
            label: p.name,
            child: Switch.adaptive(
              key: ValueKey('counter-passenger-${p.id}'),
              value: p.counted,
              activeTrackColor: PiloFamilyTheme.accentText,
              onChanged: (value) => widget.onToggle(p.id, value),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _state(
    BuildContext context,
    String message, {
    bool loading = false,
    Widget? action,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    child: Column(
      children: [
        if (loading) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
        ],
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (action != null) ...[const SizedBox(height: 8), action],
      ],
    ),
  );
}
