import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/likes/photo_likes_widgets.dart';

const tripInk = Color(0xFF17332F);
const tripTeal = Color(0xFF1D8378);
const tripMint = Color(0xFF51C7B5);
const tripOnMint = Color(0xFF0B3631);
const tripBackground = Color(0xFFF5F6F6);
const tripSurface = Color(0xFFFFFFFF);
const tripYellow = Color(0xFFFFD25B);
const tripMuted = Color(0xFF607873);
const tripPaper = Color(0xFFF2F2F2);
const tripLine = Color(0xFFE5E5E5);

String tripMoment(TripMapEntry entry, {bool fullDate = false}) {
  final date = entry.occurredAt;
  if (date == null) return 'Fecha sin confirmar';
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final day =
      '${date.day} ${months[date.month - 1]}${fullDate ? ' ${date.year}' : ''}';
  final time = entry.source.binnacleHora.trim();
  return time.isEmpty ? day : '$day · $time';
}

class TripPhoto extends StatefulWidget {
  const TripPhoto({
    super.key,
    required this.encoded,
    this.fit = BoxFit.cover,
    this.cacheWidth = 240,
  });
  final String encoded;
  final BoxFit fit;
  final int cacheWidth;
  @override
  State<TripPhoto> createState() => _TripPhotoState();
}

Uint8List _decodeTripPhoto(String encoded) {
  return base64Decode(encoded.split(',').last);
}

class _TripPhotoState extends State<TripPhoto> {
  Uint8List? _bytes;
  bool _loading = true;
  int _generation = 0;
  Future<void> _decode() async {
    final generation = ++_generation;
    final encoded = widget.encoded;
    _loading = true;
    _bytes = null;
    Uint8List? decoded;
    try {
      // Avoid copying/decoding unbounded individual images on a mobile device.
      if (encoded.length > 20 * 1024 * 1024)
        throw const FormatException('Image too large');
      decoded = encoded.length > 128 * 1024
          ? await compute(_decodeTripPhoto, encoded)
          : _decodeTripPhoto(encoded);
    } catch (_) {
      decoded = null;
    }
    if (mounted && generation == _generation) {
      setState(() {
        _bytes = decoded;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant TripPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.encoded != widget.encoded) _decode();
  }

  Widget _unavailable() => const ColoredBox(
    color: tripPaper,
    child: Center(
      child: Icon(
        Icons.hide_image_outlined,
        color: tripMuted,
        semanticLabel: 'Imagen no disponible',
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => _loading
      ? const ColoredBox(
          color: tripPaper,
          child: Center(
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: tripTeal),
            ),
          ),
        )
      : _bytes == null || _bytes!.isEmpty
      ? _unavailable()
      : Image.memory(
          _bytes!,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          gaplessPlayback: false,
          errorBuilder: (_, __, ___) => _unavailable(),
        );
}

class TripPhotoGallery extends StatefulWidget {
  const TripPhotoGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.tourId,
    this.hitoId,
    this.imageIds = const [],
  });
  final List<String> images;
  final int initialIndex;
  final int? tourId, hitoId;
  final List<int?> imageIds;
  @override
  State<TripPhotoGallery> createState() => _TripPhotoGalleryState();
}

class _TripPhotoGalleryState extends State<TripPhotoGallery> {
  late final PageController _pages;
  late int _index;
  @override
  void initState() {
    super.initState();
    _index = widget.images.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.images.length - 1);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF10201C),
    appBar: AppBar(
      backgroundColor: const Color(0xFF10201C),
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(color: Colors.white),
      centerTitle: true,
      title: Text('${_index + 1} de ${widget.images.length}'),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Cerrar fotos',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (_, index) => Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: TripPhoto(
                        encoded: widget.images[index],
                        fit: BoxFit.contain,
                        cacheWidth: 1600,
                      ),
                    ),
                  ),
                  if (widget.tourId != null &&
                      widget.hitoId != null &&
                      index < widget.imageIds.length &&
                      (widget.imageIds[index] ?? 0) > 0)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: PhotoLikeButton(
                        tourId: widget.tourId!,
                        hitoId: widget.hitoId!,
                        photoId: widget.imageIds[index]!,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.images.length > 1)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    color: Colors.white,
                    disabledColor: Colors.white24,
                    tooltip: 'Foto anterior',
                    onPressed: _index > 0
                        ? () => _pages.previousPage(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  const SizedBox(width: 40),
                  IconButton(
                    color: Colors.white,
                    disabledColor: Colors.white24,
                    tooltip: 'Foto siguiente',
                    onPressed: _index + 1 < widget.images.length
                        ? () => _pages.nextPage(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                          )
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

void openTripPhotos(
  BuildContext context,
  List<String> images, {
  int initialIndex = 0,
  int? tourId,
  int? hitoId,
  List<int?> imageIds = const [],
}) {
  if (images.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TripPhotoGallery(
        images: images,
        initialIndex: initialIndex,
        tourId: tourId,
        hitoId: hitoId,
        imageIds: imageIds,
      ),
    ),
  );
}
