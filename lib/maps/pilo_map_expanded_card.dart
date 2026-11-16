import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/likes/photo_likes_widgets.dart';
import 'package:papigiras_app/voice/trip_voice_player.dart';

/// Expanded content of one hito. The surrounding carousel owns navigation.
class PiloMapExpandedCard extends StatelessWidget {
  const PiloMapExpandedCard({
    super.key,
    required this.entry,
    required this.controller,
    required this.detail,
    required this.active,
  });

  final TripMapEntry entry;
  final TripMapController controller;
  final Future<DetailHitoList?>? detail;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, bounds) => FutureBuilder<DetailHitoList?>(
          future: detail,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final title = _text(data?.titulo, entry.source.binnacleTitulo);
            final description = _text(
              data?.descripcion,
              entry.source.binnacleDescripcion,
            );
            final note = _text(
              data?.notaCierre,
              entry.source.binnacleNotaCierre,
            );
            final voiceNote = data?.voiceNote ?? entry.source.voiceNote;
            final images = data?.images ?? const <String>[];
            final bodyStyle = text.bodyMedium?.copyWith(
              color: PiloFamilyTheme.ink,
              fontSize: 14,
              height: 1.4,
            );
            return SingleChildScrollView(
              key: ValueKey('pilo-map-expanded-body-${entry.id}'),
              primary: false,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title.isEmpty ? 'Hito' : title,
                    style: text.titleMedium?.copyWith(
                      color: PiloFamilyTheme.ink,
                      letterSpacing: -.3,
                      fontWeight: FontWeight.w700,
                      height: 1.16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tripMoment(entry),
                    style: text.bodySmall?.copyWith(
                      color: PiloFamilyTheme.secondary,
                    ),
                  ),
                  if (images.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    _ExpandedPhotos(
                      key: ObjectKey(images),
                      images: images,
                      tourId: controller.tourCode,
                      hitoId: entry.id,
                      imageIds: data?.imageIds ?? const [],
                      height: math.min(
                        172.0,
                        math.max(0.0, bounds.maxWidth - 24) * .56,
                      ),
                    ),
                  ],
                  if (voiceNote != null && active) ...[
                    const SizedBox(height: 8),
                    TripVoicePlayer(
                      key: ValueKey(
                        'pilo-map-expanded-voice-${entry.id}-${voiceNote.id}',
                      ),
                      duration: voiceNote.duration,
                      loadFile: () => controller.voice(entry.id, voiceNote),
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      description,
                      key: ValueKey(
                        'pilo-map-expanded-description-${entry.id}',
                      ),
                      style: bodyStyle,
                    ),
                  ],
                  if (note.isNotEmpty && note != description) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Nota del coordinador',
                      style: text.bodySmall?.copyWith(
                        color: PiloFamilyTheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(note, style: bodyStyle),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _text(String? detailText, String summary) {
    final value = detailText?.trim() ?? '';
    return value.isEmpty ? summary.trim() : value;
  }
}

class _ExpandedPhotos extends StatefulWidget {
  const _ExpandedPhotos({
    super.key,
    required this.images,
    required this.height,
    required this.tourId,
    required this.hitoId,
    required this.imageIds,
  });

  final List<String> images;
  final int tourId, hitoId;
  final List<int?> imageIds;
  final double height;

  @override
  State<_ExpandedPhotos> createState() => _ExpandedPhotosState();
}

class _ExpandedPhotosState extends State<_ExpandedPhotos> {
  final _pages = PageController(keepPage: false);
  int _current = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            key: const ValueKey('pilo-map-expanded-photos'),
            controller: _pages,
            physics: widget.images.length == 1
                ? const NeverScrollableScrollPhysics()
                : null,
            itemCount: widget.images.length,
            allowImplicitScrolling: true,
            onPageChanged: (index) => setState(() => _current = index),
            itemBuilder: (context, index) => Semantics(
              label: 'Abrir foto ${index + 1} de ${widget.images.length}',
              child: InkWell(
                onTap: () => openTripPhotos(
                  context,
                  widget.images,
                  initialIndex: index,
                  tourId: widget.tourId,
                  hitoId: widget.hitoId,
                  imageIds: widget.imageIds,
                ),
                child: TripPhoto(
                  encoded: widget.images[index],
                  cacheWidth: 840,
                ),
              ),
            ),
          ),
          if (_current < widget.imageIds.length &&
              (widget.imageIds[_current] ?? 0) > 0)
            Positioned(
              right: 8,
              bottom: 8,
              child: PhotoLikeButton(
                tourId: widget.tourId,
                hitoId: widget.hitoId,
                photoId: widget.imageIds[_current]!,
              ),
            ),
          if (widget.images.length > 1)
            Positioned(
              right: 8,
              top: 8,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: const ShapeDecoration(
                      color: Color(0xDB111312),
                      shape: StadiumBorder(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '${_current + 1}/${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
