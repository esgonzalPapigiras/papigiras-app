import 'package:flutter/material.dart';
import '../likes/photo_likes_widgets.dart';
import 'package:papigiras_app/design/apple_design_trial.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/maps/trip_hito_sheet.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

/// One chronology for both roles. Permissions and the existing detail route
/// remain the responsibility of the role-specific [onOpenDetail] callback.
class TripBinnacleTimeline extends StatefulWidget {
  const TripBinnacleTimeline({
    super.key,
    required this.tourId,
    required this.onOpenDetail,
    this.showAuthor = true,
    this.onOpenMap,
    this.provider,
    this.controller,
    this.familyHeader,
  });

  final int tourId;
  final Future<void> Function(TripMapEntry entry) onOpenDetail;
  final bool showAuthor;
  final ValueChanged<int>? onOpenMap;
  final CoordinatorProviders? provider;
  final TripMapController? controller;

  /// The family presentation uses its own header and full-width cards.
  final Widget Function(VoidCallback? onRefresh)? familyHeader;

  @override
  State<TripBinnacleTimeline> createState() => _TripBinnacleTimelineState();
}

class _TripBinnacleTimelineState extends State<TripBinnacleTimeline> {
  late TripMapController _controller;
  final _scroll = ScrollController();
  int? _expandedEntryId;
  DateTime? _familyDate;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  void _createController() {
    _controller =
        widget.controller ??
        (TripMapController(tourCode: widget.tourId, provider: widget.provider)
          ..refresh());
    _controller.addListener(_pruneExpandedEntry);
  }

  void _pruneExpandedEntry() {
    // The AnimatedBuilder observes this same notification and rebuilds after
    // this listener. No child callback or setState is needed during a refresh.
    final data = _controller.data;
    if (_controller.loading || _controller.error != null || data == null) {
      return;
    }
    if (_expandedEntryId != null && data.entryById(_expandedEntryId!) == null) {
      _expandedEntryId = null;
    }
    if (_familyDate != null &&
        !data.entries.any((entry) => _calendarDate(entry) == _familyDate)) {
      _familyDate = null;
    }
  }

  void _setExpandedEntry(int id, bool expanded) {
    if (expanded) {
      if (_expandedEntryId == id || _controller.data?.entryById(id) == null) {
        return;
      }
      setState(() => _expandedEntryId = id);
    } else if (_expandedEntryId == id) {
      setState(() => _expandedEntryId = null);
    }
  }

  @override
  void didUpdateWidget(covariant TripBinnacleTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tourId != widget.tourId ||
        oldWidget.provider != widget.provider ||
        oldWidget.controller != widget.controller) {
      _controller.removeListener(_pruneExpandedEntry);
      if (oldWidget.controller == null) _controller.dispose();
      if (oldWidget.tourId != widget.tourId) {
        _expandedEntryId = null;
        _familyDate = null;
      }
      _createController();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_pruneExpandedEntry);
    if (widget.controller == null) _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openDetail(TripMapEntry entry) async {
    await widget.onOpenDetail(entry);
    if (mounted && widget.controller == null) await _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([
      _controller.refresh(),
      refreshPhotoLikes(context, widget.tourId),
    ]);
  }

  void _openMap(TripMapEntry entry) {
    if (!entry.hasLocation) return;
    if (widget.onOpenMap != null) {
      widget.onOpenMap!(entry.id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TraceMapFullScreen(
          tourCode: widget.tourId,
          controller: _controller,
          initialHitoId: entry.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.familyHeader == null
      ? AppleDesignTrialScope(child: Builder(builder: _buildTimeline))
      : _buildFamilyTimeline();

  DateTime? _calendarDate(TripMapEntry entry) =>
      parseTripMapDate(entry.source.binnacleFecha, '00:00');

  String _dayLabel(DateTime day) {
    const months = [
      'ene.',
      'feb.',
      'mar.',
      'abr.',
      'may.',
      'jun.',
      'jul.',
      'ago.',
      'sept.',
      'oct.',
      'nov.',
      'dic.',
    ];
    return '${day.day} ${months[day.month - 1]}';
  }

  void _selectFamilyDate(DateTime? date) {
    if (date == _familyDate) return;
    setState(() => _familyDate = date);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _familyDateChip(DateTime? date, String label, DateTime? selected) {
    final active = selected == date;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => _selectFamilyDate(date),
        selectedColor: PiloFamilyTheme.ink,
        backgroundColor: PiloFamilyTheme.soft,
        showCheckmark: false,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          color: active ? PiloFamilyTheme.paper : PiloFamilyTheme.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }

  Widget _buildFamilyTimeline() => ColoredBox(
    color: PiloFamilyTheme.paper,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final data = _controller.data;
        final allEntries = data?.entries.reversed.toList() ?? <TripMapEntry>[];
        final dates = {
          for (final entry in allEntries)
            if (_calendarDate(entry) case final DateTime day) day,
        }.toList()..sort((a, b) => b.compareTo(a));
        final selected = dates.contains(_familyDate) ? _familyDate : null;
        final entries = selected == null
            ? allEntries
            : allEntries
                  .where((entry) => _calendarDate(entry) == selected)
                  .toList();
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: RefreshIndicator(
              color: PiloFamilyTheme.accentText,
              onRefresh: _refresh,
              child: CustomScrollView(
                key: PageStorageKey('trip-timeline-${widget.tourId}'),
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                cacheExtent: 0,
                slivers: [
                  SliverToBoxAdapter(
                    child: widget.familyHeader!(
                      _controller.loading ? null : _refresh,
                    ),
                  ),
                  if (dates.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      sliver: SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsetsDirectional.only(
                            start: 16,
                            end: 8,
                          ),
                          child: Row(
                            children: [
                              _familyDateChip(null, 'Todos', selected),
                              for (final date in dates)
                                _familyDateChip(
                                  date,
                                  _dayLabel(date),
                                  selected,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (data == null && _controller.error == null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: PiloFamilyTheme.accentText,
                        ),
                      ),
                    )
                  else if (data == null || allEntries.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _message(
                        data == null
                            ? 'No pudimos cargar la bitácora.'
                            : 'Todavía no hay hitos en esta gira.',
                        retry: data == null,
                      ),
                    )
                  else ...[
                    if (_controller.error case final String error)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            error,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 16, 20),
                      sliver: SliverList.builder(
                        itemCount: entries.length,
                        findChildIndexCallback: (key) {
                          final index = entries.indexWhere(
                            (entry) =>
                                key == ValueKey('timeline-entry-${entry.id}'),
                          );
                          return index < 0 ? null : index;
                        },
                        itemBuilder: (context, index) => _familyTimelineRow(
                          context,
                          entries[index],
                          first: index == 0,
                          last: index == entries.length - 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _familyTimelineRow(
    BuildContext context,
    TripMapEntry entry, {
    required bool first,
    required bool last,
  }) {
    const railWidth = 20.0;
    const railAxis = 5.0;
    const markerGap = 4.0;
    final day = _calendarDate(entry);
    final expanded = _expandedEntryId == entry.id;
    final emphasized = expanded || first;
    final markerRadius = emphasized ? 4.5 : 3.5;
    // The point aligns with the date row, including when that row grows.
    final dateHeight = MediaQuery.textScalerOf(context).scale(11) * 1.2 + 10;
    final markerCenter = 5 + (dateHeight < 48 ? 48 : dateHeight) / 2;
    final markerColor = expanded
        ? PiloFamilyTheme.accentText
        : first
        ? PiloFamilyTheme.ink
        : PiloFamilyTheme.connectorPast;
    const rail = ColoredBox(
      color: PiloFamilyTheme.connectorLine,
      child: SizedBox(width: 1),
    );

    return Stack(
      key: ValueKey('timeline-entry-${entry.id}'),
      children: [
        if (!first)
          PositionedDirectional(
            top: 0,
            height: markerCenter - markerRadius - markerGap,
            start: railAxis - .5,
            child: rail,
          ),
        if (!last)
          PositionedDirectional(
            top: markerCenter + markerRadius + markerGap,
            bottom: 0,
            start: railAxis - .5,
            child: rail,
          ),
        PositionedDirectional(
          top: markerCenter - markerRadius,
          start: railAxis - markerRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: markerRadius * 2),
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: railWidth,
            bottom: last ? 0 : 10,
          ),
          child: TripHitoSheet(
            key: ValueKey('timeline-sheet-${entry.id}'),
            controller: _controller,
            entry: entry,
            selectionRevision: 0,
            maxHeight: MediaQuery.sizeOf(context).height / 3,
            allowHide: false,
            timelineMode: true,
            expanded: expanded,
            onExpansionChanged: (value) => _setExpandedEntry(entry.id, value),
            showAuthor: widget.showAuthor,
            detailLabel: 'Ver más',
            onOpenDetail: () => _openDetail(entry),
            familyDateLabel: day == null
                ? 'Fecha sin confirmar'
                : '${_dayLabel(day)} · ${_eventClock(entry)}',
            onFamilyMap: entry.hasLocation ? () => _openMap(entry) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context) => ColoredBox(
    color: AppleTrialColors.background,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final data = _controller.data;
        if (data == null) {
          return _controller.error == null
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppleTrialColors.accent,
                  ),
                )
              : _message('No pudimos cargar la bitácora.', retry: true);
        }
        if (data.entries.isEmpty) {
          return _message('Todavía no hay hitos en esta gira.');
        }
        final entries = data.entries.reversed.toList();
        final indices = {
          for (var i = 0; i < entries.length; i++)
            'timeline-entry-${entries[i].id}': i,
        };
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        'Bitácora del viaje',
                        style: TextStyle(
                          color: AppleTrialColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar bitácora',
                    onPressed: _controller.loading ? null : _refresh,
                    icon: _controller.loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppleTrialColors.accent,
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            color: AppleTrialColors.accent,
                            size: 22,
                          ),
                  ),
                ],
              ),
            ),
            if (_controller.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Text(
                  _controller.error!,
                  style: const TextStyle(
                    color: AppleTrialColors.secondary,
                    fontSize: 13,
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppleTrialColors.accent,
                onRefresh: _refresh,
                child: ListView.builder(
                  key: PageStorageKey('trip-timeline-${widget.tourId}'),
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Only built, visible rows request the existing detail API.
                  // Its response includes photos; the controller caches three.
                  cacheExtent: 0,
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
                  itemCount: entries.length,
                  findChildIndexCallback: (key) =>
                      key is ValueKey<String> ? indices[key.value] : null,
                  itemBuilder: (context, index) => _row(
                    context,
                    entries[index],
                    isLast: index == entries.length - 1,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _message(String message, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppleTrialColors.secondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _controller.refresh,
            icon: const Icon(Icons.refresh),
            label: Text(retry ? 'Reintentar' : 'Actualizar'),
          ),
        ],
      ),
    ),
  );

  Widget _row(
    BuildContext context,
    TripMapEntry entry, {
    required bool isLast,
  }) {
    final date = parseTripMapDate(entry.source.binnacleFecha, '00:00');
    final clock = _eventClock(entry);
    final dateLabel = date == null
        ? 'Sin fecha'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    final dateSpoken = date == null
        ? 'Fecha sin confirmar'
        : '$dateLabel/${date.year}';
    final railWidth = MediaQuery.textScalerOf(context).scale(13) > 18
        ? 78.0
        : 62.0;
    return Padding(
      key: ValueKey('timeline-entry-${entry.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          if (!isLast)
            Positioned(
              top: 48,
              bottom: 0,
              left: railWidth / 2 - .5,
              child: const ColoredBox(
                color: AppleTrialColors.line,
                child: SizedBox(width: 1),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: railWidth,
                child: Column(
                  children: [
                    Semantics(
                      label: 'Fecha y hora del hito: $dateSpoken, $clock',
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            Text(
                              dateLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppleTrialColors.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              clock,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppleTrialColors.secondary,
                                fontSize: 13,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: AppleTrialColors.background,
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: ValueKey('timeline-map-${entry.id}'),
                        tooltip: entry.hasLocation
                            ? 'Ver hito en el mapa'
                            : 'Este hito no tiene ubicación',
                        onPressed: entry.hasLocation
                            ? () => _openMap(entry)
                            : null,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: const Icon(Icons.location_on_outlined, size: 24),
                        color: AppleTrialColors.accent,
                        disabledColor: AppleTrialColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  key: ValueKey('timeline-card-${entry.id}'),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppleTrialColors.surface,
                    border: Border.all(color: AppleTrialColors.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TripHitoSheet(
                    key: ValueKey('timeline-sheet-${entry.id}'),
                    controller: _controller,
                    entry: entry,
                    // A map selection must not reset another timeline card.
                    selectionRevision: 0,
                    maxHeight: MediaQuery.sizeOf(context).height / 3,
                    allowHide: false,
                    timelineMode: true,
                    expanded: _expandedEntryId == entry.id,
                    onExpansionChanged: (expanded) =>
                        _setExpandedEntry(entry.id, expanded),
                    showMoment: false,
                    showAuthor: widget.showAuthor,
                    detailLabel: 'Ver más',
                    expandedDescriptionMaxLines: 3,
                    scrollCompactContent: false,
                    onOpenDetail: () => _openDetail(entry),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _eventClock(TripMapEntry entry) {
    final stored = entry.source.binnacleHora.trim();
    final isoClock = RegExp(
      r'[T ](\d{2}:\d{2}(?::\d{2})?)',
    ).firstMatch(entry.source.binnacleFecha)?.group(1);
    final clock = stored.isNotEmpty ? stored : isoClock ?? '';
    final parsed = parseTripMapDate('2000-01-01', clock);
    if (clock.isEmpty || parsed == null) return 'Sin hora';
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}
