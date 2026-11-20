import '../navigation/family_navigation.dart';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../design/pilo_family_theme.dart';
import '../lab/media.dart';
import '../likes/photo_likes_widgets.dart';
import '../utils/page_navigation.dart';
import 'trip_gallery_controller.dart';

class TripGalleryScreen extends StatefulWidget {
  const TripGalleryScreen({
    super.key,
    required this.tourId,
    required this.departure,
    this.controller,
  });
  final int tourId;
  final String departure;
  final TripGalleryController? controller;
  @override
  State<TripGalleryScreen> createState() => _TripGalleryScreenState();
}

class _TripGalleryScreenState extends State<TripGalleryScreen> {
  late final TripGalleryController _controller;
  final _scroll = ScrollController();
  DateTime? _selectedDate;

  bool get _hasMore => _selectedDate == null
      ? _controller.hasMore
      : _controller.hasMoreOnDate(_selectedDate!);
  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TripGalleryController(tourId: widget.tourId);
    _controller.addListener(_changed);
    _scroll.addListener(_nearEnd);
    if (!_controller.initialized && !_controller.loading) _controller.refresh();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nearEnd();
    });
  }

  void _nearEnd() {
    final waitingForDay =
        _selectedDate != null &&
        _controller.photosForDate(_selectedDate).isEmpty;
    if (_scroll.hasClients &&
        (waitingForDay || _scroll.position.extentAfter < 480) &&
        _controller.errorForDate(_selectedDate) == null &&
        _hasMore) {
      _controller.loadMore(date: _selectedDate);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _controller.removeListener(_changed);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _open(TripGalleryPhoto photo) {
    final photos = _controller.photosForDate(_selectedDate);
    final index = photos.indexWhere((item) => item.key == photo.key);
    if (index < 0) return;
    Navigator.of(context).push(
      buildPapiRoute(
        _GalleryViewer(
          controller: _controller,
          initialIndex: index,
          date: _selectedDate,
        ),
      ),
    );
  }

  void _back() {
    final navigation = FamilyNavigationScope.maybeOf(context);
    if (navigation != null) {
      navigation.back();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _controller.refresh(date: _selectedDate),
      refreshPhotoLikes(context, widget.tourId),
    ]);
  }

  void _selectDate(DateTime? date) {
    if (_selectedDate == date) return;
    setState(() => _selectedDate = date);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nearEnd();
    });
  }

  Widget _dateChip(DateTime? date, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _selectedDate == date,
      onSelected: (_) => _selectDate(date),
      selectedColor: PiloFamilyTheme.mint,
      backgroundColor: PiloFamilyTheme.soft,
      showCheckmark: false,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        color: PiloFamilyTheme.ink,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
  );

  Widget _sectionHeader(BuildContext context) {
    final refresh = IconButton(
      tooltip: 'Actualizar galería',
      onPressed: _controller.loading ? null : _refresh,
      icon: const Icon(CupertinoIcons.arrow_clockwise),
    );
    final compact =
        MediaQuery.sizeOf(context).height < 640 ||
        MediaQuery.textScalerOf(context).scale(16) > 24;
    if (!compact) {
      return PiloSectionBar(
        title: 'Galería',
        subtitle: 'Fotos de la gira',
        onBack: _back,
        backTooltip: 'Volver al inicio',
        actions: [refresh],
      );
    }
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Volver al inicio',
              onPressed: _back,
              style: IconButton.styleFrom(
                backgroundColor: PiloFamilyTheme.soft,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Galería', style: PiloFamilyTheme.display(26)),
              ),
            ),
            refresh,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dates = {
      ..._controller.dates,
      if (_selectedDate case final DateTime date) date,
    }.toList()..sort();
    final shownDays = _controller.daysForDate(_selectedDate);
    return Theme(
      data: PiloFamilyTheme.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: PiloFamilyTheme.paper,
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  key: const PageStorageKey('trip-gallery-scroll'),
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  cacheExtent: 240,
                  slivers: [
                    SliverToBoxAdapter(child: Builder(builder: _sectionHeader)),
                    if (dates.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Wrap(
                            children: [
                              _dateChip(null, 'Todos'),
                              for (final day in dates)
                                _dateChip(
                                  day,
                                  galleryDateLabel(day, includeYear: false),
                                ),
                            ],
                          ),
                        ),
                      ),
                    for (final day in shownDays) ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        sliver: SliverToBoxAdapter(child: _dayHeader(day)),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, block) {
                              final start = block * 5;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PhotoCollage(
                                  dayOffset: start,
                                  photos: day.photos.sublist(
                                    start,
                                    (start + 5).clamp(0, day.photos.length),
                                  ),
                                  controller: _controller,
                                  onOpen: _open,
                                ),
                              );
                            },
                            childCount: (day.photos.length / 5).ceil(),
                            addAutomaticKeepAlives: false,
                          ),
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(child: _status()),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayHeader(TripGalleryDay day) {
    final title = day.title(widget.departure);
    final date = day.date == null ? null : galleryDateLabel(day.date!);
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PiloFamilyTheme.display(27)),
          if (date != null && date != title)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                date,
                style: const TextStyle(
                  fontSize: 14,
                  color: PiloFamilyTheme.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _status() {
    final error = _controller.errorForDate(_selectedDate);
    if (error != null)
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(error, textAlign: TextAlign.center),
            TextButton(
              onPressed: () => _controller.retry(date: _selectedDate),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    if (_controller.loading)
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cargando fotos…',
              style: TextStyle(color: PiloFamilyTheme.secondary, fontSize: 14),
            ),
          ],
        ),
      );
    if (_hasMore)
      return Center(
        child: TextButton(
          onPressed: () => _controller.loadMore(date: _selectedDate),
          child: const Text('Cargar más fotos'),
        ),
      );
    if (_selectedDate != null &&
        _controller.photosForDate(_selectedDate).isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(
          children: [
            const Text('No hay fotos disponibles para esta fecha.'),
            TextButton(
              onPressed: () => _selectDate(null),
              child: const Text('Ver todas las fotos'),
            ),
          ],
        ),
      );
    }
    if (_selectedDate == null && _controller.photos.isEmpty) {
      final unavailable = _controller.unavailableImages > 0;
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.photo_on_rectangle,
              size: 44,
              color: PiloFamilyTheme.accentText,
            ),
            const SizedBox(height: 16),
            Text(
              unavailable ? 'Fotos no disponibles' : 'Aún no hay fotos',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              unavailable
                  ? 'No se pudieron recuperar las fotos de estos hitos.'
                  : 'Las fotos publicadas en los hitos del viaje aparecerán aquí.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: PiloFamilyTheme.secondary),
            ),
          ],
        ),
      );
    }
    if (_controller.unavailableImagesForDate(_selectedDate) > 0)
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Algunas fotos no están disponibles.',
          textAlign: TextAlign.center,
          style: TextStyle(color: PiloFamilyTheme.secondary, fontSize: 14),
        ),
      );
    return const SizedBox.shrink();
  }
}

/// A deterministic collage; loading a photo never moves its neighbours.
/// Within each block, read the large photo, then the two stacked photos
/// from top to bottom, then the next row. The viewer keeps the same order.
class _PhotoCollage extends StatelessWidget {
  const _PhotoCollage({
    required this.dayOffset,
    required this.photos,
    required this.controller,
    required this.onOpen,
  });
  final int dayOffset;
  final List<TripGalleryPhoto> photos;
  final TripGalleryController controller;
  final ValueChanged<TripGalleryPhoto> onOpen;
  Widget _tile(int i, {bool featured = false}) {
    final photo = photos[i];
    final title = photo.title;
    final date = photo.date == null
        ? ''
        : ' del ${galleryDateLabel(photo.date!)}';
    final hasPhotoId = (photo.photoId ?? 0) > 0;
    return Material(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(featured ? 28 : 22),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label:
                'Abrir foto ${dayOffset + i + 1}$date${title.isEmpty ? '' : ': $title'}',
            child: InkWell(
              key: ValueKey('gallery-photo-${photo.key}'),
              onTap: () => onOpen(photo),
              child: ExcludeSemantics(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _GalleryImage(
                      key: ValueKey('thumb-${photo.key}'),
                      controller: controller,
                      photo: photo,
                    ),
                    if (featured && title.isNotEmpty)
                      IgnorePointer(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(
                              12,
                              18,
                              12,
                              hasPhotoId ? 62 : 14,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xE6000000)],
                              ),
                            ),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (hasPhotoId)
            Positioned(
              right: 8,
              bottom: 8,
              child: PhotoLikeButton(
                tourId: controller.tourId,
                hitoId: photo.hitoId,
                photoId: photo.photoId!,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, bounds) {
      final width = bounds.maxWidth;
      if (photos.length == 1) {
        return SizedBox(
          height: width * .68,
          width: width,
          child: _tile(0, featured: true),
        );
      }
      if (photos.length == 2) {
        return SizedBox(
          height: width * .62,
          child: Row(
            children: [
              Expanded(child: SizedBox.expand(child: _tile(0))),
              const SizedBox(width: 8),
              Expanded(child: SizedBox.expand(child: _tile(1))),
            ],
          ),
        );
      }
      return Column(
        children: [
          SizedBox(
            height: width * .73,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox.expand(child: _tile(0, featured: true)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: SizedBox.expand(child: _tile(1))),
                      const SizedBox(height: 8),
                      Expanded(child: SizedBox.expand(child: _tile(2))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (photos.length > 3) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: width * .56,
              child: Row(
                children: [
                  Expanded(child: SizedBox.expand(child: _tile(3))),
                  if (photos.length > 4) ...[
                    const SizedBox(width: 8),
                    Expanded(child: SizedBox.expand(child: _tile(4))),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _GalleryImage extends StatefulWidget {
  const _GalleryImage({
    super.key,
    required this.controller,
    required this.photo,
    this.full = false,
  });
  final TripGalleryController controller;
  final TripGalleryPhoto photo;
  final bool full;
  @override
  State<_GalleryImage> createState() => _GalleryImageState();
}

class _GalleryImageState extends State<_GalleryImage> {
  late Future<Uint8List?> _bytes;
  void _load() => _bytes = widget.full
      ? widget.controller.fullImage(widget.photo)
      : widget.controller.thumbnail(widget.photo);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _GalleryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo ||
        oldWidget.controller != widget.controller)
      _load();
  }

  Widget _failed() => Center(
    child: IconButton(
      tooltip: 'Reintentar foto',
      color: widget.full ? Colors.white : PiloFamilyTheme.secondary,
      onPressed: () => setState(_load),
      icon: const Icon(Icons.refresh),
    ),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      if (snapshot.data == null || snapshot.hasError) return _failed();
      return Image.memory(
        snapshot.data!,
        fit: widget.full ? BoxFit.contain : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: widget.full ? 1600 : 600,
        errorBuilder: (_, __, ___) => _failed(),
      );
    },
  );
}

class _GalleryViewer extends StatefulWidget {
  const _GalleryViewer({
    required this.controller,
    required this.initialIndex,
    required this.date,
  });
  final TripGalleryController controller;
  final int initialIndex;
  final DateTime? date;
  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

enum _PhotoAction { share, download }

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _pages;
  late int _index;
  _PhotoAction? _activeAction;
  bool get _hasMore => widget.date == null
      ? widget.controller.hasMore
      : widget.controller.hasMoreOnDate(widget.date!);
  List<TripGalleryPhoto> get _photos =>
      widget.controller.photosForDate(widget.date);
  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = PageController(initialPage: _index);
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAhead();
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAhead();
    });
  }

  void _loadAhead() {
    if (_index >= _photos.length - 3 &&
        widget.controller.errorForDate(widget.date) == null &&
        _hasMore)
      widget.controller.loadMore(date: widget.date);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _pages.dispose();
    super.dispose();
  }

  void _move(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  bool get _viewerIsVisible {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return false;
    final navigation = FamilyNavigationScope.maybeOf(context);
    return navigation == null || navigation.selected == FamilySection.gallery;
  }

  Future<void> _exportPhoto(
    _PhotoAction action,
    TripGalleryPhoto photo,
    BuildContext buttonContext,
  ) async {
    if (_activeAction != null) return;
    setState(() => _activeAction = action);
    try {
      final bytes = await widget.controller.fullImage(photo);
      if (!_viewerIsVisible || !buttonContext.mounted) return;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Foto no disponible');
      }
      if (action == _PhotoAction.share) {
        await LabMedia.shareImage(
          bytes,
          buttonContext,
          isCurrent: () => _viewerIsVisible,
        );
      } else {
        await LabMedia.saveImage(bytes, isCurrent: () => _viewerIsVisible);
        if (_viewerIsVisible) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto guardada en la galería.')),
          );
        }
      }
    } catch (_) {
      if (_viewerIsVisible) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == _PhotoAction.share
                  ? 'No pudimos compartir la foto. Inténtalo nuevamente.'
                  : 'No pudimos descargar la foto. Inténtalo nuevamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Widget _exportButton(_PhotoAction action, TripGalleryPhoto? photo) {
    final sharing = action == _PhotoAction.share;
    final label = sharing ? 'Compartir foto' : 'Descargar foto';
    return Builder(
      builder: (buttonContext) => IconButton(
        tooltip: label,
        color: Colors.white,
        disabledColor: Colors.white38,
        onPressed: photo == null || _activeAction != null
            ? null
            : () => _exportPhoto(action, photo, buttonContext),
        icon: _activeAction == action
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  color: PiloFamilyTheme.mint,
                  strokeWidth: 2,
                  semanticsLabel: sharing
                      ? 'Preparando foto para compartir'
                      : 'Descargando foto',
                ),
              )
            : Icon(
                sharing
                    ? CupertinoIcons.share
                    : CupertinoIcons.arrow_down_to_line,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final controller = widget.controller;
    final photo = _index < photos.length ? photos[_index] : null;
    return Scaffold(
      backgroundColor: PiloFamilyTheme.ink,
      appBar: AppBar(
        backgroundColor: PiloFamilyTheme.ink,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${photos.length}${_hasMore ? '+' : ''}',
          style: const TextStyle(fontSize: 17, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Cerrar fotos',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        actions: [
          _exportButton(_PhotoAction.share, photo),
          _exportButton(_PhotoAction.download, photo),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: const ValueKey('gallery-viewer'),
                controller: _pages,
                itemCount: photos.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _loadAhead();
                },
                itemBuilder: (_, i) => Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      key: ValueKey('zoom-${photos[i].key}'),
                      minScale: 1,
                      maxScale: 4,
                      child: _GalleryImage(
                        key: ValueKey('full-${photos[i].key}'),
                        controller: controller,
                        photo: photos[i],
                        full: true,
                      ),
                    ),
                    if ((photos[i].photoId ?? 0) > 0)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: PhotoLikeButton(
                          tourId: controller.tourId,
                          hitoId: photos[i].hitoId,
                          photoId: photos[i].photoId!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (controller.errorForDate(widget.date) != null)
              TextButton(
                onPressed: () => controller.retry(date: widget.date),
                child: const Text(
                  'Reintentar carga',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Foto anterior',
                    color: Colors.white,
                    disabledColor: Colors.white24,
                    onPressed: _index > 0 ? () => _move(_index - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  const SizedBox(width: 40),
                  if (controller.loading && _index == photos.length - 1)
                    const SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Foto siguiente',
                      color: Colors.white,
                      disabledColor: Colors.white24,
                      onPressed: _index + 1 < photos.length
                          ? () => _move(_index + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
