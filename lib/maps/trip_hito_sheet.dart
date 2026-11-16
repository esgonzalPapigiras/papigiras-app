import 'dart:typed_data';
import '../likes/photo_likes_widgets.dart';
import '../voice/trip_voice_player.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:papigiras_app/design/apple_design_trial.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/maps/trip_hito_detail.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';

enum _SheetExtent { compact, expanded, hidden }

/// A nonmodal, height-limited hito preview shared by both map presentations.
/// Selecting a pin (including the same pin again) restores its compact preview.
class TripHitoSheet extends StatefulWidget {
  const TripHitoSheet({
    super.key,
    required this.controller,
    required this.entry,
    required this.selectionRevision,
    required this.maxHeight,
    this.allowHide = true,
    this.showHitoNavigation = false,
    this.onPreviousHito,
    this.onNextHito,
    this.onOpenDetail,
    this.detailLabel = 'Ver hito',
    this.showMoment = true,
    this.showAuthor = false,
    this.expandedDescriptionMaxLines = 3,
    this.scrollCompactContent = true,
    this.piloMap = false,
    this.bottomInset = 0,
    this.onHide,
    this.timelineMode = false,
    this.expanded,
    this.onExpansionChanged,
    this.familyDateLabel,
    this.onFamilyMap,
  }) : assert((expanded == null) == (onExpansionChanged == null));

  final TripMapController controller;
  final TripMapEntry entry;
  final int selectionRevision;
  final double maxHeight;
  final bool allowHide;
  final bool showHitoNavigation;
  final VoidCallback? onPreviousHito;
  final VoidCallback? onNextHito;
  final VoidCallback? onOpenDetail;
  final String detailLabel;
  final bool showMoment;
  final bool showAuthor;
  final int? expandedDescriptionMaxLines;
  final bool scrollCompactContent;

  /// Presentation opt-in for the Pilo family map.
  final bool piloMap;
  final double bottomInset;
  final VoidCallback? onHide;

  /// Timeline cards toggle only on tap and leave vertical gestures to the list.
  /// Map sheets retain their original drag, dismissal and photo-gallery behavior.
  final bool timelineMode;

  /// Optional parent-owned expansion. The timeline uses this to keep just one
  /// card open across list virtualization; maps retain their local extent.
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;
  final String? familyDateLabel;
  final VoidCallback? onFamilyMap;

  @override
  State<TripHitoSheet> createState() => _TripHitoSheetState();
}

class _TripHitoSheetState extends State<TripHitoSheet> {
  _SheetExtent _extent = _SheetExtent.compact;
  final _contentScroll = ScrollController(keepScrollOffset: false);
  final _photos = PageController(keepPage: false);
  final _familyPhotosKey = GlobalKey();
  Future<DetailHitoList>? _detail;
  bool _retry = false;
  int _requestRevision = 0;
  int _photoIndex = 0;
  int _selectionGeneration = 0;
  double _horizontalDistance = 0;
  double _dragDistance = 0;
  double? _dragHeight;
  double _dragStartHeight = 0;
  double _scrollDragDistance = 0;

  Color get _mapInk => widget.piloMap ? PiloFamilyTheme.ink : tripInk;
  Color get _mapMuted => widget.piloMap ? PiloFamilyTheme.secondary : tripMuted;
  Color get _mapAccent =>
      widget.piloMap ? PiloFamilyTheme.accentText : tripTeal;
  BorderRadius get _photoCorners =>
      BorderRadius.circular(widget.piloMap ? 16 : 12);

  bool get _canHide =>
      widget.allowHide && !widget.timelineMode && widget.expanded == null;

  @override
  void initState() {
    super.initState();
    if (widget.expanded == true) _extent = _SheetExtent.expanded;
  }

  @override
  void didUpdateWidget(covariant TripHitoSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canHide && _extent == _SheetExtent.hidden) {
      _extent = _SheetExtent.compact;
    }
    final newSelection =
        oldWidget.entry.id != widget.entry.id ||
        oldWidget.selectionRevision != widget.selectionRevision ||
        oldWidget.controller != widget.controller;
    if (newSelection) {
      _extent = _SheetExtent.compact;
      _horizontalDistance = 0;
      _dragHeight = null;
      _dragDistance = 0;
      _photoIndex = 0;
      _detail = null;
      _retry = false;
      _requestRevision++;
      _selectionGeneration++;
      _resetScroll(resetPhotos: true);
    } else if (!identical(oldWidget.entry, widget.entry)) {
      // Refresh creates new entries and clears the controller's detail cache.
      // Reload that detail without changing the user's chosen presentation.
      // FutureBuilder remounts its pager, whose first page is always zero.
      _photoIndex = 0;
      _detail = null;
      _retry = false;
      _requestRevision++;
    }
    final controlled = widget.expanded;
    if (controlled != null) {
      final desired = controlled ? _SheetExtent.expanded : _SheetExtent.compact;
      if (_extent != desired) {
        _extent = desired;
        _dragHeight = null;
        _scrollDragDistance = 0;
        if (desired == _SheetExtent.compact && widget.familyDateLabel == null) {
          _photoIndex = 0;
          _resetScroll(resetPhotos: true);
        }
      }
    }
  }

  @override
  void dispose() {
    _contentScroll.dispose();
    _photos.dispose();
    super.dispose();
  }

  void _resetScroll({bool resetPhotos = false}) {
    final generation = _selectionGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _selectionGeneration) return;
      if (_contentScroll.hasClients) _contentScroll.jumpTo(0);
      if (resetPhotos && _photos.hasClients) _photos.jumpToPage(0);
    });
  }

  void _setExtent(_SheetExtent extent) {
    if (_extent == extent) return;
    if (extent == _SheetExtent.hidden && widget.onHide != null) {
      widget.onHide!();
      return;
    }
    if (widget.expanded != null) {
      // Only user actions request a change; didUpdateWidget applies the parent
      // value silently, avoiding callbacks while the timeline is building.
      widget.onExpansionChanged!(extent == _SheetExtent.expanded);
      return;
    }
    setState(() {
      _extent = extent;
      _dragHeight = null;
      if (extent == _SheetExtent.compact) _photoIndex = 0;
    });
    _scrollDragDistance = 0;
    if (extent == _SheetExtent.compact) _resetScroll(resetPhotos: true);
  }

  void _expand() => _setExtent(_SheetExtent.expanded);

  void _collapse() => _setExtent(
    _extent == _SheetExtent.expanded || !_canHide
        ? _SheetExtent.compact
        : _SheetExtent.hidden,
  );

  void _toggle() => _extent == _SheetExtent.expanded
      ? _setExtent(_SheetExtent.compact)
      : _expand();

  void _finishDrag(double distance, {double velocity = 0}) {
    if (distance > 28 || velocity > 350) {
      _collapse();
    } else if (distance < -28 || velocity < -350) {
      _expand();
    }
  }

  double get _maximumHeight =>
      widget.maxHeight.isFinite ? math.max(0.0, widget.maxHeight) : 0.0;

  double get _compactHeight {
    final hasVoice = widget.entry.source.voiceNote != null;
    final inset = widget.bottomInset.clamp(0.0, _maximumHeight);
    return inset +
        math.min(
          hasVoice ? 218.0 : (widget.piloMap ? 145.0 : 170.0),
          (_maximumHeight - inset) * (hasVoice ? .85 : .65),
        );
  }

  double get _settledHeight => switch (_extent) {
    _SheetExtent.hidden => 0.0,
    _SheetExtent.compact => _compactHeight,
    _SheetExtent.expanded => _maximumHeight,
  };

  void _startHandleDrag(DragStartDetails _) {
    _dragDistance = 0;
    _dragStartHeight = _settledHeight;
    setState(() => _dragHeight = _dragStartHeight);
  }

  void _moveHandle(DragUpdateDetails event) {
    _dragDistance += event.delta.dy;
    setState(() {
      _dragHeight = (_dragStartHeight - _dragDistance).clamp(
        _canHide
            ? 0.0
            : widget.piloMap
            ? _compactHeight
            : math.min(170.0, _maximumHeight * .65),
        _maximumHeight,
      );
    });
  }

  void _endHandleDrag(DragEndDetails event) {
    setState(() => _dragHeight = null);
    _finishDrag(_dragDistance, velocity: event.primaryVelocity ?? 0);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification) {
      _scrollDragDistance = 0;
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      // Content scrolls normally. Pulling past its top collapses the sheet;
      // pushing past the compact preview's bottom expands it.
      if (notification.overscroll < 0 || _extent == _SheetExtent.compact) {
        _scrollDragDistance -= notification.overscroll;
      }
    } else if (notification is ScrollEndNotification) {
      final distance = _scrollDragDistance;
      _scrollDragDistance = 0;
      if (distance.abs() > 28) {
        // Scroll notifications arrive during layout; change height afterwards.
        final generation = _selectionGeneration;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _selectionGeneration) {
            _finishDrag(distance);
          }
        });
      }
    }
    return false;
  }

  void _retryDetail() => setState(() {
    _retry = true;
    _detail = null;
    _requestRevision++;
  });

  String _text(String? detailed, String original) =>
      detailed?.trim().isNotEmpty == true ? detailed!.trim() : original;

  @override
  Widget build(BuildContext context) {
    final expanded = _extent == _SheetExtent.expanded;
    if (widget.timelineMode) return _content(expanded);
    final height = _dragHeight ?? _settledHeight;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final sheet = SizedBox(
      height: height,
      width: double.infinity,
      child: _extent == _SheetExtent.hidden || _maximumHeight == 0
          ? const SizedBox.shrink()
          : Semantics(
              container: true,
              value: expanded ? 'Ampliada' : 'Compacta',
              increasedValue: expanded ? null : 'Ampliada',
              decreasedValue: expanded
                  ? 'Compacta'
                  : (_canHide ? 'Oculta' : null),
              onIncrease: expanded ? null : _expand,
              onDecrease: expanded || _canHide ? _collapse : null,
              customSemanticsActions: {
                if (_canHide)
                  const CustomSemanticsAction(label: 'Ocultar hito'): () =>
                      _setExtent(_SheetExtent.hidden),
              },
              child: ClipRect(
                // Keep the 44px handle laid out while the visible sheet
                // follows the finger through smaller heights, including zero.
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: math.max(44.0, height),
                  maxHeight: math.max(44.0, height),
                  child: Material(
                    color: widget.piloMap ? PiloFamilyTheme.paper : tripSurface,
                    borderRadius: widget.piloMap
                        ? const BorderRadius.vertical(
                            top: Radius.circular(PiloFamilyTheme.cardRadius),
                          )
                        : null,
                    clipBehavior: widget.piloMap ? Clip.antiAlias : Clip.none,
                    child: GestureDetector(
                      key: const ValueKey('trip-hito-carousel'),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: widget.showHitoNavigation
                          ? (_) => _horizontalDistance = 0
                          : null,
                      onHorizontalDragUpdate: widget.showHitoNavigation
                          ? (details) => setState(() {
                              _horizontalDistance += details.delta.dx;
                            })
                          : null,
                      onHorizontalDragEnd: widget.showHitoNavigation
                          ? _endHorizontalDrag
                          : null,
                      onHorizontalDragCancel: widget.showHitoNavigation
                          ? () => setState(() => _horizontalDistance = 0)
                          : null,
                      child: Column(
                        children: [
                          _handle(),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, bounds) {
                                final content = Transform.translate(
                                  offset: Offset(
                                    reducedMotion
                                        ? 0
                                        : _horizontalDistance.clamp(
                                            -24.0,
                                            24.0,
                                          ),
                                    0,
                                  ),
                                  child: _content(expanded),
                                );
                                if (!widget.piloMap) return content;
                                final showDetail =
                                    expanded &&
                                    bounds.maxHeight > 0 &&
                                    (_dragHeight == null ||
                                        bounds.maxHeight >= 44);
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: content),
                                    if (showDetail)
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxHeight: bounds.maxHeight,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            20,
                                            0,
                                            20,
                                            bounds.maxHeight >= 48 ? 4 : 0,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            heightFactor: 1,
                                            child: _mapDetailButton(context),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            height: widget.bottomInset.clamp(
                              0.0,
                              math.max(0, height - 44),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
    if (reducedMotion) {
      // Flutter's zero-duration RenderAnimatedSize can reenter its layout.
      // An immediate size change also respects the user's motion preference.
      return KeyedSubtree(key: const ValueKey('trip-hito-sheet'), child: sheet);
    }
    return AnimatedSize(
      key: const ValueKey('trip-hito-sheet'),
      // Keep this render object during dragging so the recognizer and pager
      // remain mounted. One millisecond follows the finger without layout
      // reentrancy from a zero-duration animation.
      duration: Duration(milliseconds: _dragHeight != null ? 1 : 200),
      curve: Curves.easeOutCubic,
      alignment: widget.timelineMode
          ? Alignment.topCenter
          : Alignment.bottomCenter,
      clipBehavior: Clip.hardEdge,
      child: sheet,
    );
  }

  void _endHorizontalDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final distance = _horizontalDistance;
    setState(() => _horizontalDistance = 0);
    if (distance.abs() < 40 && velocity.abs() < 350) return;
    final forward = distance.abs() >= 40 ? distance < 0 : velocity < 0;
    (forward ? widget.onNextHito : widget.onPreviousHito)?.call();
  }

  Widget _handle() {
    final grabber = Semantics(
      button: true,
      label: _extent == _SheetExtent.expanded ? 'Reducir hito' : 'Ampliar hito',
      onTap: _toggle,
      child: GestureDetector(
        key: const ValueKey('trip-hito-handle'),
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onVerticalDragStart: _startHandleDrag,
        onVerticalDragUpdate: _moveHandle,
        onVerticalDragEnd: _endHandleDrag,
        onVerticalDragCancel: () => setState(() => _dragHeight = null),
        child: SizedBox(
          height: 44,
          width: double.infinity,
          child: Center(
            child: Container(
              width: widget.piloMap ? 32 : 36,
              height: 4,
              decoration: BoxDecoration(
                color: _mapMuted.withValues(alpha: widget.piloMap ? .66 : .5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
    if (!widget.showHitoNavigation) return grabber;
    return Row(
      children: [
        _hitoArrow(
          'Volver al hito anterior visible',
          Icons.chevron_left_rounded,
          widget.onPreviousHito,
          'trip-previous-nearby',
        ),
        Expanded(child: grabber),
        _hitoArrow(
          'Ver siguiente hito cercano',
          Icons.chevron_right_rounded,
          widget.onNextHito,
          'trip-next-nearby',
        ),
      ],
    );
  }

  Widget _hitoArrow(
    String label,
    IconData icon,
    VoidCallback? action,
    String key,
  ) => IconButton(
    key: ValueKey(key),
    tooltip: label,
    onPressed: action,
    color: _mapAccent,
    disabledColor: _mapMuted.withValues(alpha: .25),
    iconSize: 23,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 48, height: 44),
    icon: Icon(icon),
  );

  Widget _content(bool expanded) {
    // Start/retry in build so FutureBuilder immediately attaches an error
    // handler, even when the provider fails synchronously.
    _detail ??= widget.controller.detail(widget.entry.id, retry: _retry);
    _retry = false;
    return FutureBuilder<DetailHitoList>(
      key: ValueKey(_requestRevision),
      future: _detail,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        final images = detail?.images ?? const <String>[];
        if (widget.familyDateLabel != null) {
          return _familyCard(snapshot, expanded);
        }
        if (widget.timelineMode) return _timelineCard(snapshot, expanded);
        return GestureDetector(
          key: const ValueKey('trip-hito-card-tap'),
          behavior: HitTestBehavior.opaque,
          onTap: expanded ? null : _expand,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: SingleChildScrollView(
              controller: _contentScroll,
              physics: expanded || widget.scrollCompactContent
                  ? const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    )
                  : const NeverScrollableScrollPhysics(),
              padding: widget.piloMap
                  ? const EdgeInsets.fromLTRB(20, 0, 20, 16)
                  : const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final photoWidth = images.isEmpty
                      ? 0.0
                      : math.min(
                          expanded ? 155.0 : 88.0,
                          constraints.maxWidth * (expanded ? .42 : .29),
                        );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _summary(detail, expanded)),
                          if (images.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            if (expanded)
                              _inlinePhotos(
                                images,
                                photoWidth,
                                imageIds: detail?.imageIds ?? const [],
                              )
                            else
                              _thumbnail(
                                images,
                                photoWidth,
                                imageIds: detail?.imageIds ?? const [],
                              ),
                          ] else if (snapshot.hasError && !expanded) ...[
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: _mapMuted,
                                size: 22,
                                semanticLabel:
                                    'Fotos no disponibles. Amplía para reintentar.',
                              ),
                            ),
                          ],
                        ],
                      ),
                      if ((detail?.voiceNote ??
                              widget.entry.source.voiceNote) !=
                          null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _voicePlayer(detail),
                        ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: _mapAccent,
                            backgroundColor: widget.piloMap
                                ? PiloFamilyTheme.soft
                                : tripPaper,
                          ),
                        ),
                      if (expanded) ...[
                        if (snapshot.hasError) _detailError(),
                        if ((detail?.missingImageCount ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              detail!.missingImageCount == 1
                                  ? 'Una foto no está disponible.'
                                  : '${detail.missingImageCount} fotos no están disponibles.',
                              style: TextStyle(color: _mapMuted, fontSize: 13),
                            ),
                          ),
                        if (_text(
                          detail?.descripcion,
                          widget.entry.source.binnacleDescripcion,
                        ).trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _text(
                                detail?.descripcion,
                                widget.entry.source.binnacleDescripcion,
                              ),
                              maxLines: widget.expandedDescriptionMaxLines,
                              overflow:
                                  widget.expandedDescriptionMaxLines == null
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _mapInk,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        if (!widget.piloMap)
                          Align(
                            alignment: Alignment.centerRight,
                            child: _mapDetailButton(context),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mapDetailButton(BuildContext context) => TextButton.icon(
    onPressed:
        widget.onOpenDetail ??
        () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TripHitoDetail(
              controller: widget.controller,
              entry: widget.entry,
            ),
          ),
        ),
    style: TextButton.styleFrom(
      foregroundColor: widget.piloMap ? PiloFamilyTheme.ink : tripTeal,
      backgroundColor: widget.piloMap ? PiloFamilyTheme.mint : null,
      shape: widget.piloMap ? const StadiumBorder() : null,
      minimumSize: const Size(0, 44),
      padding: EdgeInsets.symmetric(horizontal: widget.piloMap ? 16 : 8),
    ),
    label: Text(widget.detailLabel),
    icon: const Icon(Icons.arrow_outward_rounded, size: 16),
  );

  Widget _familyCard(AsyncSnapshot<DetailHitoList> snapshot, bool expanded) {
    final detail = snapshot.data;
    final images = detail?.images ?? const <String>[];
    final rawTitle = _text(detail?.titulo, widget.entry.source.binnacleTitulo);
    final title = rawTitle.trim().isEmpty ? 'Hito sin título' : rawTitle;
    final description = _text(
      detail?.descripcion,
      widget.entry.source.binnacleDescripcion,
    ).trim();
    // Historical addresses can start with a separator for an empty field.
    final location = _locationLabel(
      detail,
    ).replaceFirst(RegExp(r'^[,;]+\s*'), '').trim();

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: DecoratedBox(
                  decoration: const ShapeDecoration(
                    color: PiloFamilyTheme.paper,
                    shape: StadiumBorder(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      widget.familyDateLabel!,
                      style: const TextStyle(
                        color: PiloFamilyTheme.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              HitoLikeCount(
                tourId: widget.controller.tourCode,
                hitoId: widget.entry.id,
              ),
              IconButton(
                key: const ValueKey('trip-timeline-toggle'),
                tooltip: expanded ? 'Reducir hito' : 'Ampliar hito',
                onPressed: _toggle,
                icon: Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, bounds) {
              final photoSize = math.min(78.0, bounds.maxWidth * .28);
              Widget photos(double width, double height) => ClipRRect(
                key: _familyPhotosKey,
                borderRadius: BorderRadius.circular(18),
                child: _inlinePhotos(
                  images,
                  width,
                  imageIds: expanded
                      ? (detail?.imageIds ?? const [])
                      : const [],
                  toggleOnTap: true,
                  height: height,
                  familyExpanded: expanded,
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.3,
                                  height: 1.2,
                                  color: PiloFamilyTheme.ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              location.isEmpty
                                  ? 'Ubicación registrada'
                                  : location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PiloFamilyTheme.secondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (images.isNotEmpty && !expanded) ...[
                        const SizedBox(width: 12),
                        photos(photoSize, photoSize),
                      ],
                    ],
                  ),
                  if (images.isNotEmpty && expanded) ...[
                    const SizedBox(height: 12),
                    photos(
                      bounds.maxWidth,
                      (bounds.maxWidth * .62).clamp(180.0, 220.0),
                    ),
                  ],
                ],
              );
            },
          ),
          if (snapshot.connectionState == ConnectionState.waiting) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              minHeight: 2,
              color: PiloFamilyTheme.accentText,
              backgroundColor: PiloFamilyTheme.soft,
            ),
          ],
          if (expanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: PiloFamilyTheme.hairline),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  description,
                  key: const ValueKey('trip-timeline-description'),
                  maxLines: widget.expandedDescriptionMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (widget.showAuthor)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _timelineAuthorFooter(),
              ),
            if ((detail?.voiceNote ?? widget.entry.source.voiceNote) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _voicePlayer(detail),
              ),
            if (snapshot.hasError) _detailError(),
            if ((detail?.missingImageCount ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  detail!.missingImageCount == 1
                      ? 'Una foto no está disponible.'
                      : '${detail.missingImageCount} fotos no están disponibles.',
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    key: ValueKey('timeline-map-${widget.entry.id}'),
                    tooltip: widget.onFamilyMap == null
                        ? 'Este hito no tiene ubicación'
                        : 'Ver hito en el mapa',
                    onPressed: widget.onFamilyMap,
                    icon: const Icon(Icons.location_on_outlined),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('trip-timeline-detail'),
                    onPressed: widget.onOpenDetail,
                    icon: const Icon(Icons.arrow_outward_rounded, size: 19),
                    label: Text(widget.detailLabel),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    return Material(
      key: ValueKey('timeline-card-${widget.entry.id}'),
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(PiloFamilyTheme.cardRadius),
      color: PiloFamilyTheme.soft,
      child: Semantics(
        container: true,
        value: expanded ? 'Ampliada' : 'Compacta',
        increasedValue: expanded ? null : 'Ampliada',
        decreasedValue: expanded ? 'Compacta' : null,
        onIncrease: expanded ? null : _expand,
        onDecrease: expanded ? _collapse : null,
        child: InkWell(
          key: const ValueKey('trip-hito-card-tap'),
          onTap: _toggle,
          child: MediaQuery.disableAnimationsOf(context)
              ? content
              : AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: content,
                ),
        ),
      ),
    );
  }

  Widget _timelineCard(AsyncSnapshot<DetailHitoList> snapshot, bool expanded) {
    final detail = snapshot.data;
    final images = detail?.images ?? const <String>[];
    final hasVoice =
        (detail?.voiceNote ?? widget.entry.source.voiceNote) != null;
    return LayoutBuilder(
      builder: (context, bounds) {
        final width = math.max(1.0, bounds.maxWidth - 24);
        final scaledText = MediaQuery.textScalerOf(context).scale(13);
        final stackedFooter =
            widget.showAuthor && (width < 250 || scaledText > 18);
        final authorHeight = math.max(28.0, scaledText * 2.3);
        final footerHeight = stackedFooter ? authorHeight + 48.0 : 48.0;
        final photoWidth = images.isEmpty
            ? 0.0
            : math.min(
                expanded ? 155.0 : 68.0,
                width *
                    (expanded
                        ? (scaledText > 18 && width < 240 ? .34 : .42)
                        : .29),
              );
        final summaryWidth = math.max(
          1.0,
          width - (images.isEmpty ? 0 : photoWidth + 12),
        );
        // Closed rows fit their real content instead of reserving an empty
        // 170px panel. Text scaling can grow them within the same preview cap.
        var summaryHeight =
            _timelineTextHeight(
              _text(detail?.titulo, widget.entry.source.binnacleTitulo),
              _timelineTitleStyle,
              summaryWidth,
              maxLines: 2,
            ) +
            5 +
            _timelineTextHeight(
              _locationLabel(detail),
              _timelineLocationStyle,
              summaryWidth,
              maxLines: 1,
            );
        if (widget.showMoment) {
          summaryHeight +=
              5 +
              _timelineTextHeight(
                tripMoment(widget.entry),
                _timelineMetadataStyle,
                summaryWidth,
                maxLines: 1,
              );
        }
        final compactHeight =
            24 +
            math.max(summaryHeight, photoWidth) +
            footerHeight +
            (hasVoice ? 56 : 0);
        final essentialHeight =
            24 + summaryHeight + footerHeight + (hasVoice ? 56 : 0);
        var accessibleHeight = essentialHeight;
        if (expanded && essentialHeight > _maximumHeight) {
          final description = _text(
            detail?.descripcion,
            widget.entry.source.binnacleDescripcion,
          ).trim();
          if (description.isNotEmpty) {
            accessibleHeight +=
                8 +
                _timelineTextHeight(
                  description,
                  _timelineBodyStyle,
                  width,
                  maxLines: 1,
                );
          }
        }
        // The one-third preview remains the default. On a short display with
        // enlarged text, let the list row grow enough to retain its title,
        // location, author and actions instead of clipping essential content.
        final height = expanded
            ? math.max(_maximumHeight, accessibleHeight)
            : math.max(
                essentialHeight,
                math.min(_maximumHeight, compactHeight),
              );
        final card = SizedBox(
          height: height,
          width: double.infinity,
          child: Semantics(
            container: true,
            value: expanded ? 'Ampliada' : 'Compacta',
            increasedValue: expanded ? null : 'Ampliada',
            decreasedValue: expanded ? 'Compacta' : null,
            onIncrease: expanded ? null : _expand,
            onDecrease: expanded ? _collapse : null,
            child: Material(
              color: AppleTrialColors.surface,
              child: GestureDetector(
                key: const ValueKey('trip-hito-card-tap'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                // Vertical gestures still belong only to the surrounding list.
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final fittedPhoto = math.min(
                              photoWidth,
                              constraints.maxHeight,
                            );
                            if (expanded) {
                              return _timelineExpandedBody(
                                detail,
                                images,
                                constraints,
                                fittedPhoto,
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _timelineSummary(detail)),
                                if (images.isNotEmpty && fittedPhoto > 0) ...[
                                  const SizedBox(width: 12),
                                  _thumbnail(
                                    images,
                                    fittedPhoto,
                                    imageIds: detail?.imageIds ?? const [],
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      if (hasVoice)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: _voicePlayer(detail),
                        ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: footerHeight,
                        child: _timelineFooter(
                          snapshot,
                          expanded,
                          stacked: stackedFooter,
                          authorHeight: authorHeight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (MediaQuery.disableAnimationsOf(context)) {
          return KeyedSubtree(
            key: const ValueKey('trip-hito-sheet'),
            child: card,
          );
        }
        return AnimatedSize(
          key: const ValueKey('trip-hito-sheet'),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: card,
        );
      },
    );
  }

  Widget _timelineFooter(
    AsyncSnapshot<DetailHitoList> snapshot,
    bool expanded, {
    required bool stacked,
    required double authorHeight,
  }) {
    final actions = Row(
      children: [
        if (snapshot.hasError)
          IconButton(
            tooltip: 'Reintentar fotografías',
            onPressed: _retryDetail,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const Icon(
              Icons.image_not_supported_outlined,
              size: 20,
              color: AppleTrialColors.secondary,
            ),
          )
        else if (snapshot.connectionState == ConnectionState.waiting)
          const SizedBox.square(
            dimension: 24,
            child: Center(
              child: SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppleTrialColors.accent,
                ),
              ),
            ),
          ),
        if (widget.showAuthor && !stacked)
          Expanded(flex: 2, child: _timelineAuthorFooter()),
        Flexible(
          fit: widget.showAuthor && !stacked ? FlexFit.loose : FlexFit.tight,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('trip-timeline-detail'),
              onPressed:
                  widget.onOpenDetail ??
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TripHitoDetail(
                        controller: widget.controller,
                        entry: widget.entry,
                      ),
                    ),
                  ),
              style: TextButton.styleFrom(
                foregroundColor: AppleTrialColors.accent,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                widget.detailLabel,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppleTrialColors.accent,
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        SizedBox.square(
          dimension: 48,
          child: IconButton(
            key: const ValueKey('trip-timeline-toggle'),
            tooltip: expanded ? 'Reducir hito' : 'Ampliar hito',
            onPressed: _toggle,
            padding: const EdgeInsets.all(10),
            icon: DecoratedBox(
              decoration: BoxDecoration(
                color: AppleTrialColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppleTrialColors.line),
              ),
              child: SizedBox.square(
                dimension: 28,
                child: Icon(
                  expanded ? Icons.remove : Icons.add,
                  size: 18,
                  color: AppleTrialColors.accent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    if (!stacked) return actions;
    return Column(
      children: [
        SizedBox(height: authorHeight, child: _timelineAuthorFooter()),
        SizedBox(height: 48, child: actions),
      ],
    );
  }

  Widget _voicePlayer(DetailHitoList? detail) {
    final note = (detail?.voiceNote ?? widget.entry.source.voiceNote)!;
    return TripVoicePlayer(
      key: ValueKey('voice-${widget.entry.id}-${note.id}'),
      duration: note.duration,
      loadFile: () => widget.controller.voice(widget.entry.id, note),
    );
  }

  static const _timelineTitleStyle = TextStyle(
    color: AppleTrialColors.ink,
    fontSize: 17,
    height: 1.22,
    fontWeight: FontWeight.w600,
  );
  static const _timelineLocationStyle = TextStyle(
    color: AppleTrialColors.secondary,
    fontSize: 13,
    height: 1.3,
  );
  static const _timelineMetadataStyle = TextStyle(
    color: AppleTrialColors.secondary,
    fontSize: 13,
    height: 1.25,
  );
  static const _timelineBodyStyle = TextStyle(
    color: AppleTrialColors.ink,
    fontSize: 14,
    height: 1.4,
  );

  TextPainter _timelinePainter(
    String text,
    TextStyle style,
    double width, {
    int? maxLines,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  )..layout(maxWidth: width);

  double _timelineTextHeight(
    String text,
    TextStyle style,
    double width, {
    int? maxLines,
  }) {
    final painter = _timelinePainter(text, style, width, maxLines: maxLines);
    final height = painter.height.ceilToDouble();
    painter.dispose();
    return height;
  }

  Widget _timelineAuthorFooter() {
    final author = widget.entry.source.author;
    final name = author?.fullName.trim() ?? '';
    final label = name.isEmpty ? 'Registro histórico' : name;
    return Tooltip(
      message: label,
      child: Row(
        children: [
          FutureBuilder<Uint8List?>(
            future: widget.controller.authorPicture(widget.entry),
            builder: (context, snapshot) => ClipOval(
              child: SizedBox.square(
                dimension: 28,
                child: snapshot.data == null
                    ? const ColoredBox(
                        color: AppleTrialColors.background,
                        child: Icon(
                          Icons.person_rounded,
                          size: 19,
                          color: AppleTrialColors.accent,
                        ),
                      )
                    : Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        cacheWidth: 84,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          color: AppleTrialColors.accent,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppleTrialColors.secondary,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineExpandedBody(
    DetailHitoList? detail,
    List<String> images,
    BoxConstraints constraints,
    double photoWidth,
  ) {
    final description = _text(
      detail?.descripcion,
      widget.entry.source.binnacleDescripcion,
    ).trim();
    final hasPhoto = images.isNotEmpty && photoWidth > 0;
    final textWidth = math.max(
      1.0,
      constraints.maxWidth - (hasPhoto ? photoWidth + 10 : 0),
    );
    var textHeight =
        _timelineTextHeight(
          _text(detail?.titulo, widget.entry.source.binnacleTitulo),
          _timelineTitleStyle,
          textWidth,
          maxLines: 2,
        ) +
        5 +
        _timelineTextHeight(
          _locationLabel(detail),
          _timelineLocationStyle,
          textWidth,
          maxLines: 1,
        );
    if (widget.showMoment)
      textHeight +=
          5 +
          _timelineTextHeight(
            tripMoment(widget.entry),
            _timelineMetadataStyle,
            textWidth,
            maxLines: 1,
          );
    final preferredHeader = math.max(textHeight, hasPhoto ? 135.0 : 0.0);
    var headerHeight = math.min(preferredHeader, constraints.maxHeight);
    var showDescription = false;
    if (description.isNotEmpty) {
      final firstLine = _timelineTextHeight(
        description,
        _timelineBodyStyle,
        constraints.maxWidth,
        maxLines: 1,
      );
      final fullDescription = _timelineTextHeight(
        description,
        _timelineBodyStyle,
        constraints.maxWidth,
      );
      final minimumHeader = math.max(textHeight, hasPhoto ? 68.0 : 0.0);
      final roomForFullDescription =
          constraints.maxHeight - fullDescription - 8;
      if (roomForFullDescription >= minimumHeader) {
        // A modestly shorter preview can reveal the whole story instead of
        // truncating it while leaving avoidable whitespace beside the photo.
        headerHeight = math.min(preferredHeader, roomForFullDescription);
      } else {
        headerHeight = math.min(
          preferredHeader,
          math.max(0.0, constraints.maxHeight - firstLine - 8),
        );
      }
      showDescription = constraints.maxHeight - headerHeight - 8 >= firstLine;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('trip-timeline-header'),
          height: headerHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _timelineSummary(detail)),
              if (hasPhoto) ...[
                const SizedBox(width: 10),
                _inlinePhotos(
                  images,
                  photoWidth,
                  imageIds: detail?.imageIds ?? const [],
                  toggleOnTap: true,
                  height: math.min(135.0, headerHeight),
                ),
              ],
            ],
          ),
        ),
        if (showDescription) ...[
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, space) {
                final painter = _timelinePainter(
                  description,
                  _timelineBodyStyle,
                  space.maxWidth,
                );
                final fitsAll = painter.height <= space.maxHeight + .1;
                var fittingLines = painter.computeLineMetrics().length;
                painter.dispose();
                if (!fitsAll) {
                  // Measure actual paragraph heights: summing rounded line
                  // metrics can unnecessarily hide a line with native fonts.
                  var lower = 0;
                  var upper = fittingLines;
                  while (lower < upper) {
                    final candidate = (lower + upper + 1) ~/ 2;
                    final limited = _timelinePainter(
                      description,
                      _timelineBodyStyle,
                      space.maxWidth,
                      maxLines: candidate,
                    );
                    final fits = limited.height <= space.maxHeight + .1;
                    limited.dispose();
                    if (fits) {
                      lower = candidate;
                    } else {
                      upper = candidate - 1;
                    }
                  }
                  fittingLines = lower;
                }
                if (fittingLines == 0) return const SizedBox.shrink();
                return Text(
                  description,
                  key: const ValueKey('trip-timeline-description'),
                  style: _timelineBodyStyle,
                  maxLines: fitsAll ? null : fittingLines,
                  overflow: fitsAll ? TextOverflow.clip : TextOverflow.ellipsis,
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _timelineSummary(DetailHitoList? detail) => LayoutBuilder(
    builder: (context, constraints) {
      final title = _text(detail?.titulo, widget.entry.source.binnacleTitulo);
      final location = _locationLabel(detail);
      double remaining = constraints.maxHeight;
      final children = <Widget>[];
      double measure(String text, TextStyle style, int lines) =>
          _timelineTextHeight(
            text,
            style,
            constraints.maxWidth,
            maxLines: lines,
          );
      bool addText(String text, TextStyle style, int lines) {
        if (text.isEmpty) return false;
        final gap = children.isEmpty ? 0.0 : 5.0;
        final height = measure(text, style, lines);
        if (height + gap > remaining + .1) return false;
        if (gap > 0) children.add(SizedBox(height: gap));
        children.add(
          Text(
            text,
            style: style,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
          ),
        );
        remaining -= height + gap;
        return true;
      }

      final reserveLocation = measure(location, _timelineLocationStyle, 1) + 5;
      var titleLines = 2;
      if (measure(title, _timelineTitleStyle, 2) + reserveLocation > remaining)
        titleLines = 1;
      if (!addText(title, _timelineTitleStyle, titleLines)) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              title,
              style: _timelineTitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
      addText(location, _timelineLocationStyle, 1);
      if (widget.showMoment)
        addText(tripMoment(widget.entry), _timelineMetadataStyle, 1);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    },
  );

  String _locationLabel(DetailHitoList? detail) {
    if (!widget.entry.hasLocation) return 'Sin ubicación en el mapa';
    final location = _text(
      detail?.ubicacion,
      widget.entry.source.binnacleUbicacion,
    ).trim();
    // Some historical descriptions contain the old geocoder's exception.
    // Hide that implementation payload without changing stored text/coordinates.
    if (location.isEmpty ||
        RegExp(
          r'PlatformException|MissingPluginException|geocod(?:ing|er).*?(?:error|exception)|error.*?geocod',
          caseSensitive: false,
        ).hasMatch(location)) {
      return 'Ubicación registrada';
    }
    return location;
  }

  Widget _summary(DetailHitoList? detail, bool expanded) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        _text(detail?.titulo, widget.entry.source.binnacleTitulo),
        maxLines: expanded ? 3 : 2,
        overflow: TextOverflow.ellipsis,
        style: widget.piloMap
            ? PiloFamilyTheme.display(25)
            : const TextStyle(
                color: tripInk,
                fontSize: 18,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
      ),
      const SizedBox(height: 7),
      Text(
        _locationLabel(detail),
        maxLines: widget.piloMap && !expanded ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: _mapMuted, fontSize: 13, height: 1.3),
      ),
      if (widget.showAuthor) ...[
        const SizedBox(height: 6),
        Text(
          widget.entry.source.author == null
              ? 'Autor: registro histórico'
              : widget.entry.source.author!.fullName.trim().isEmpty
              ? 'Autor no disponible'
              : 'Autor: ${widget.entry.source.author!.fullName}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _mapMuted, fontSize: 12, height: 1.25),
        ),
      ],
      if (widget.showMoment) ...[
        const SizedBox(height: 6),
        Text(
          tripMoment(widget.entry),
          style: TextStyle(
            color: widget.piloMap ? _mapAccent : tripMuted,
            fontSize: 12,
            height: 1.25,
          ),
        ),
      ],
    ],
  );

  Widget _thumbnail(
    List<String> images,
    double width, {
    List<int?> imageIds = const [],
  }) => Semantics(
    label:
        '${images.length} ${images.length == 1 ? 'foto' : 'fotos'}. Ampliar hito.',
    child: ClipRRect(
      key: ValueKey('trip-photo-gallery-${widget.entry.id}'),
      borderRadius: _photoCorners,
      child: SizedBox.square(
        dimension: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TripPhoto(encoded: images.first),
            if (images.length > 1)
              Positioned(
                right: 5,
                top: 5,
                child: _photoCount('1/${images.length}'),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _inlinePhotos(
    List<String> images,
    double width, {
    bool toggleOnTap = false,
    double? height,
    bool? familyExpanded,
    List<int?> imageIds = const [],
  }) => SizedBox(
    key: const ValueKey('trip-inline-photos'),
    width: width,
    height: height ?? math.min(145.0, math.max(120.0, width)),
    child: Stack(
      children: [
        PageView.builder(
          controller: _photos,
          physics: familyExpanded == false
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: images.length,
          onPageChanged: (index) => setState(() => _photoIndex = index),
          itemBuilder: (context, index) => Semantics(
            button: true,
            label: toggleOnTap
                ? '${familyExpanded == false ? 'Ampliar' : 'Contraer'} hito. '
                      'Foto ${index + 1} de ${images.length}'
                : 'Abrir foto ${index + 1} de ${images.length}',
            child: Padding(
              padding: familyExpanded == null
                  ? const EdgeInsets.symmetric(horizontal: 2)
                  : EdgeInsets.zero,
              child: InkWell(
                key: ValueKey('trip-inline-photo-$index'),
                onTap: toggleOnTap
                    ? _toggle
                    : () => openTripPhotos(
                        context,
                        images,
                        initialIndex: index,
                        tourId: widget.controller.tourCode,
                        hitoId: widget.entry.id,
                        imageIds: imageIds,
                      ),
                borderRadius: familyExpanded == null
                    ? _photoCorners
                    : BorderRadius.zero,
                child: ClipRRect(
                  borderRadius: familyExpanded == null
                      ? _photoCorners
                      : BorderRadius.zero,
                  child: TripPhoto(encoded: images[index], cacheWidth: 480),
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            right: 7,
            top: 5,
            child: IgnorePointer(
              child: _photoCount(
                '${math.min(_photoIndex + 1, images.length)}/${images.length}',
              ),
            ),
          ),
        if (_photoIndex < imageIds.length && imageIds[_photoIndex] != null)
          Positioned(
            right: 2,
            bottom: 2,
            child: PhotoLikeButton(
              tourId: widget.controller.tourCode,
              hitoId: widget.entry.id,
              photoId: imageIds[_photoIndex]!,
            ),
          ),
      ],
    ),
  );

  Widget _photoCount(String count) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _mapInk.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          count,
          style: const TextStyle(color: tripSurface, fontSize: 11),
        ),
      ),
    ),
  );

  Widget _detailError() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(
          'No pudimos cargar las fotos.',
          style: TextStyle(color: _mapMuted, fontSize: 13),
        ),
        Tooltip(
          message: 'Reintentar fotografías',
          child: TextButton.icon(
            onPressed: _retryDetail,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
            style: TextButton.styleFrom(foregroundColor: _mapAccent),
          ),
        ),
      ],
    ),
  );
}
