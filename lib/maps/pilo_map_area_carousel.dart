import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/maps/pilo_map_expanded_card.dart';
import 'package:papigiras_app/maps/trip_hito_detail.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';

/// Shared by the area counter and individual map markers.
class PiloMapAreaCarousel extends StatefulWidget {
  const PiloMapAreaCarousel({
    super.key,
    required this.controller,
    required this.entries,
    required this.selectedId,
    required this.compactMaxHeight,
    required this.expandedMaxHeight,
    required this.bottomInset,
    required this.onSelected,
    required this.onClose,
    this.onOpenHito,
  });

  final TripMapController controller;
  final List<TripMapEntry> entries;
  final int selectedId;
  final double compactMaxHeight;
  final double expandedMaxHeight;
  final double bottomInset;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;
  final ValueChanged<TripMapEntry>? onOpenHito;

  @override
  State<PiloMapAreaCarousel> createState() => _PiloMapAreaCarouselState();
}

class _PiloMapAreaCarouselState extends State<PiloMapAreaCarousel> {
  late final PageController _pages;
  final _details =
      LinkedHashMap<int, (TripMapEntry, Future<DetailHitoList?>)>();
  int _syncRevision = 0;
  bool _syncing = false;
  double _dragDistance = 0;
  bool _expanded = false;

  int get _selectedPage =>
      math.max(0, widget.entries.indexWhere((e) => e.id == widget.selectedId));

  @override
  void initState() {
    super.initState();
    _pages = PageController(
      initialPage: _selectedPage,
      keepPage: false,
      viewportFraction: .9,
    );
    _requestDetail();
  }

  @override
  void didUpdateWidget(covariant PiloMapAreaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _details.clear();
    _requestDetail();
    if (widget.entries.isEmpty) return;
    final target = _selectedPage;
    if (!_syncing && _pages.hasClients && _pages.page?.round() == target) {
      return;
    }
    _syncing = true;
    final revision = ++_syncRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _syncRevision) return;
      if (_pages.hasClients) _pages.jumpToPage(target);
      _syncing = false;
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _requestDetail() {
    if (widget.entries.isEmpty) return;
    final entry = widget.entries[_selectedPage];
    final cached = _details.remove(entry.id);
    if (cached != null && identical(cached.$1, entry)) {
      _details[entry.id] = cached;
      return;
    }
    _details[entry.id] = (entry, _loadDetail(entry.id));
    while (_details.length > 3) {
      _details.remove(_details.keys.first);
    }
  }

  Future<DetailHitoList?> _loadDetail(int id) async {
    try {
      return await widget.controller.detail(id);
    } catch (_) {
      // Keep the summary usable; the detail page provides its own retry UI.
      return null;
    }
  }

  void _selectPage(int index) {
    if (_syncing || index >= widget.entries.length) return;
    final id = widget.entries[index].id;
    if (id != widget.selectedId) widget.onSelected(id);
  }

  void _step(int index) {
    if (!_pages.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openDetail() {
    final controller = widget.controller;
    final entry = widget.entries[_selectedPage];
    if (widget.onOpenHito != null) {
      widget.onOpenHito!(entry);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TripHitoDetail(controller: controller, entry: entry, pilo: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Leave room for both title lines and the date when text is enlarged.
    final extraTextHeight =
        math.max(0.0, MediaQuery.textScalerOf(context).scale(17) - 17) * 3;
    final compactHeight = math.min(
      widget.compactMaxHeight,
      176 + extraTextHeight + widget.bottomInset,
    );
    final height = _expanded ? widget.expandedMaxHeight : compactHeight;
    if (!height.isFinite || height <= 0 || widget.entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final inset = widget.bottomInset
        .clamp(0.0, math.max(0.0, height - 92))
        .toDouble();
    final selected = _selectedPage;
    return AnimatedContainer(
      key: const ValueKey('pilo-map-area-carousel'),
      height: height,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 230),
      curve: Curves.easeOutCubic,
      child: Material(
        color: PiloFamilyTheme.paper,
        elevation: 3,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final controlHeight = math.min(44.0, bounds.maxHeight / 3);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: controlHeight,
                    child: Row(
                      children: [
                        _arrow(
                          'previous',
                          'Hito anterior',
                          Icons.chevron_left_rounded,
                          selected > 0 ? () => _step(selected - 1) : null,
                        ),
                        Expanded(child: _handle()),
                        _arrow(
                          'next',
                          'Siguiente hito',
                          Icons.chevron_right_rounded,
                          selected + 1 < widget.entries.length
                              ? () => _step(selected + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      key: const ValueKey('pilo-map-area-pages'),
                      controller: _pages,
                      itemCount: widget.entries.length,
                      onPageChanged: _selectPage,
                      itemBuilder: (context, index) {
                        final entry = widget.entries[index];
                        final cached = _details[entry.id];
                        final detail = identical(cached?.$1, entry)
                            ? cached?.$2
                            : null;
                        return ExcludeSemantics(
                          excluding: index != selected,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _expanded
                                ? PiloMapExpandedCard(
                                    key: ValueKey(
                                      'pilo-map-area-hito-${entry.id}',
                                    ),
                                    entry: entry,
                                    controller: widget.controller,
                                    detail: detail,
                                    active:
                                        index == selected &&
                                        (ModalRoute.of(context)?.isCurrent ??
                                            true),
                                  )
                                : GestureDetector(
                                    onTap: index == selected
                                        ? _toggleSize
                                        : null,
                                    child: _AreaCard(
                                      key: ValueKey(
                                        'pilo-map-area-hito-${entry.id}',
                                      ),
                                      entry: entry,
                                      detail: detail,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: controlHeight + 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                '${selected + 1} de ${widget.entries.length}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: PiloFamilyTheme.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                          FilledButton(
                            key: const ValueKey('pilo-map-area-detail'),
                            onPressed: _openDetail,
                            style: FilledButton.styleFrom(
                              backgroundColor: PiloFamilyTheme.mint,
                              foregroundColor: PiloFamilyTheme.ink,
                              shape: const StadiumBorder(),
                              minimumSize: const Size(120, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Ver hito', maxLines: 1),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 17,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _arrow(
    String direction,
    String label,
    IconData icon,
    VoidCallback? action,
  ) => IconButton(
    key: ValueKey('pilo-map-area-$direction'),
    tooltip: label,
    onPressed: action,
    constraints: const BoxConstraints.tightFor(width: 48, height: 44),
    padding: EdgeInsets.zero,
    color: PiloFamilyTheme.ink,
    icon: Icon(icon),
  );

  void _toggleSize() => setState(() => _expanded = !_expanded);

  Widget _handle() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onVerticalDragStart: (_) => _dragDistance = 0,
    onVerticalDragUpdate: (event) => _dragDistance += event.delta.dy,
    onVerticalDragEnd: (event) {
      final velocity = event.primaryVelocity ?? 0;
      if (_dragDistance < -20 || velocity < -350) {
        if (!_expanded) _toggleSize();
      } else if (_dragDistance > 20 || velocity > 350) {
        if (_expanded) {
          _toggleSize();
        } else {
          widget.onClose();
        }
      }
    },
    child: Tooltip(
      message: _expanded
          ? 'Reducir tarjeta del hito'
          : 'Ampliar tarjeta del hito',
      child: InkWell(
        key: const ValueKey('pilo-map-area-handle'),
        onTap: _toggleSize,
        child: Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: const ShapeDecoration(
              color: PiloFamilyTheme.connectorPast,
              shape: StadiumBorder(),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({super.key, required this.entry, required this.detail});

  final TripMapEntry entry;
  final Future<DetailHitoList?>? detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = entry.source.binnacleTitulo.trim();
    return Material(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final imageSize = math.min(
            68.0,
            math.max(0.0, bounds.maxHeight - 16),
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            child: Row(
              children: [
                if (imageSize >= 24) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox.square(
                      key: ValueKey('pilo-map-area-photo-${entry.id}'),
                      dimension: imageSize,
                      child: FutureBuilder<DetailHitoList?>(
                        future: detail,
                        builder: (context, snapshot) {
                          final image = snapshot.data?.images.firstOrNull;
                          if (image != null && image.isNotEmpty) {
                            return TripPhoto(encoded: image);
                          }
                          return const ColoredBox(
                            color: PiloFamilyTheme.dockIdle,
                            child: Icon(
                              Icons.photo_outlined,
                              color: PiloFamilyTheme.secondary,
                              size: 21,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    primary: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? 'Hito' : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(
                            fontSize: 17,
                            letterSpacing: -.3,
                            fontWeight: FontWeight.w700,
                            height: 1.16,
                            color: PiloFamilyTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tripMoment(entry),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: PiloFamilyTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
