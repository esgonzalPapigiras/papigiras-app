import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../lab/media_data.dart';
import '../maps/trip_map_controller.dart';
import '../maps/trip_map_data.dart';
import 'pilo_family_theme.dart';

/// Small home preview, using the same authenticated detail cache as the map.
/// This is not a total-photo query: never imply that three previews are all of
/// the photos, or show a made-up remaining count. Gallery retains full paging.
class PiloFamilyGalleryPreview extends StatefulWidget {
  const PiloFamilyGalleryPreview({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  final TripMapController controller;
  final VoidCallback onOpen;

  @override
  State<PiloFamilyGalleryPreview> createState() =>
      _PiloFamilyGalleryPreviewState();
}

class _PiloFamilyGalleryPreviewState extends State<PiloFamilyGalleryPreview> {
  static const _maxHitos = 6;
  TripMapData? _source;
  List<Uint8List> _photos = const [];
  bool _loading = false;
  bool _failed = false;
  bool _exhausted = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updated);
    _updated();
  }

  @override
  void didUpdateWidget(covariant PiloFamilyGalleryPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updated);
      widget.controller.addListener(_updated);
      _source = widget.controller.data;
      _load(_source);
    }
  }

  @override
  void dispose() {
    ++_generation;
    widget.controller.removeListener(_updated);
    super.dispose();
  }

  void _updated() {
    if (!mounted) return;
    final data = widget.controller.data;
    if (!identical(data, _source)) {
      _source = data;
      _load(data);
    } else {
      setState(
        () {},
      ); // List refresh/error state; selecting pins never fetches.
    }
  }

  Future<void> _load(TripMapData? data) async {
    final generation = ++_generation;
    final controller = widget.controller;
    final entries = data?.entries.reversed.toList() ?? <TripMapEntry>[];
    setState(() {
      _photos = const [];
      _loading = entries.isNotEmpty;
      _failed = false;
      _exhausted = entries.isEmpty;
    });
    final photos = <Uint8List>[];
    var failed = false;
    var inspected = 0;
    for (final entry in entries.take(_maxHitos)) {
      if (!_current(generation)) return;
      ++inspected;
      try {
        final detail = await controller.detail(entry.id);
        if (!_current(generation)) return;
        for (final encoded in detail.images) {
          if (photos.length == 3) break;
          final thumb = await _thumbnail(encoded);
          if (!_current(generation)) return;
          if (thumb != null) {
            photos.add(thumb);
          } else {
            failed = true;
          }
        }
        if (detail.missingImageCount > 0) failed = true;
      } catch (_) {
        failed = true;
      }
      if (photos.length == 3) break;
    }
    if (!_current(generation)) return;
    setState(() {
      _photos = photos;
      _loading = false;
      _failed = failed;
      _exhausted = inspected == entries.length;
    });
  }

  bool _current(int generation) => mounted && generation == _generation;

  Future<Uint8List?> _thumbnail(String encoded) async {
    final bytes = encoded.length > 128 * 1024
        ? await compute(LocalImageData.decode, encoded)
        : LocalImageData.decode(encoded);
    if (bytes == null) return null;
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 400,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          return data?.buffer.asUint8List();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fonts = Theme.of(context).textTheme;
    final loading = _loading || (_source == null && widget.controller.loading);
    final failed = _failed || widget.controller.error != null;
    return Column(
      key: const ValueKey('family-gallery-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Fotos del viaje',
                style: fonts.titleSmall?.copyWith(fontSize: 14),
              ),
            ),
            TextButton(
              key: const ValueKey('family-gallery-open'),
              onPressed: widget.onOpen,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(left: 8),
                minimumSize: const Size(44, 44),
                foregroundColor: PiloFamilyTheme.accentText,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ver todas', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
            ),
          ],
        ),
        if (_photos.isNotEmpty)
          SizedBox(
            height: 78,
            child: Row(
              children: [
                for (var i = 0; i < _photos.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    flex: i == 0 ? 135 : 100,
                    child: Semantics(
                      button: true,
                      label: 'Abrir galería, foto ${i + 1}',
                      child: Material(
                        color: PiloFamilyTheme.soft,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('family-gallery-photo-$i'),
                          onTap: widget.onOpen,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                _photos[i],
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                              if (i == 2)
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    margin: const EdgeInsets.all(7),
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Color(0xB3101513),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Material(
            color: PiloFamilyTheme.soft,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: widget.onOpen,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    if (loading)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.photo_library_outlined,
                        color: PiloFamilyTheme.accentText,
                        size: 22,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        loading
                            ? 'Cargando fotos…'
                            : failed
                            ? 'Abre la galería para cargar las fotos.'
                            : _exhausted
                            ? 'Las fotos de la gira aparecerán aquí.'
                            : 'Explora las fotos de la gira.',
                        style: fonts.bodySmall?.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
