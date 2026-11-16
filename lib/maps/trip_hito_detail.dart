import '../voice/trip_voice_player.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/likes/photo_likes_widgets.dart';

class TripHitoDetail extends StatefulWidget {
  const TripHitoDetail({
    super.key,
    required this.controller,
    required this.entry,
    this.pilo = false,
  });
  final TripMapController controller;
  final TripMapEntry entry;
  final bool pilo;
  @override
  State<TripHitoDetail> createState() => _TripHitoDetailState();
}

class _TripHitoDetailState extends State<TripHitoDetail> {
  late Future<DetailHitoList> _detail;
  @override
  void initState() {
    super.initState();
    _detail = widget.controller.detail(widget.entry.id);
  }

  String _text(String? detail, String original) =>
      detail?.trim().isNotEmpty == true ? detail!.trim() : original;

  @override
  Widget build(BuildContext context) {
    final screen = _buildDetail(context);
    return widget.pilo
        ? Theme(data: PiloFamilyTheme.theme(Theme.of(context)), child: screen)
        : screen;
  }

  Widget _photo(BuildContext context, DetailHitoList detail, int index) {
    final photoId = detail.photoIdAt(index);
    return Material(
      color: tripPaper,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              label: 'Abrir foto ${index + 1} de ${detail.images.length}',
              child: InkWell(
                onTap: () => openTripPhotos(
                  context,
                  detail.images,
                  initialIndex: index,
                  tourId: widget.controller.tourCode,
                  hitoId: widget.entry.id,
                  imageIds: detail.imageIds,
                ),
                child: TripPhoto(
                  encoded: detail.images[index],
                  cacheWidth: 900,
                ),
              ),
            ),
            const Positioned(
              right: 12,
              top: 12,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: tripBackground,
                    child: Icon(Icons.open_in_full, color: tripInk, size: 18),
                  ),
                ),
              ),
            ),
            if (photoId != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: PhotoLikeButton(
                  tourId: widget.controller.tourCode,
                  hitoId: widget.entry.id,
                  photoId: photoId,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context) => Scaffold(
    backgroundColor: widget.pilo ? PiloFamilyTheme.paper : tripBackground,
    appBar: AppBar(
      backgroundColor: widget.pilo ? PiloFamilyTheme.paper : tripBackground,
      foregroundColor: tripInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'Bitácora del viaje',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
      leading: IconButton(
        tooltip: 'Volver al mapa',
        style: widget.pilo
            ? IconButton.styleFrom(backgroundColor: PiloFamilyTheme.soft)
            : null,
        icon: Icon(widget.pilo ? Icons.arrow_back_rounded : Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: FutureBuilder<DetailHitoList>(
        future: _detail,
        builder: (context, snapshot) {
          final entry = widget.entry;
          final detail = snapshot.data;
          final photos = detail?.images ?? const <String>[];
          final author = entry.source.author?.fullName ?? '';
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            children: [
              Text(
                '${entry.unknownDate ? 'Hito' : 'Hito ${entry.ordinal}'} · ${tripMoment(entry, fullDate: true)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tripTeal,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _text(detail?.titulo, entry.source.binnacleTitulo),
                style: widget.pilo
                    ? PiloFamilyTheme.display(36)
                    : const TextStyle(
                        fontSize: 28,
                        fontFamily: 'Avenir Next',
                        fontFamilyFallback: [
                          'Avenir',
                          'Trebuchet MS',
                          'Arial',
                          'Roboto',
                        ],
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: tripInk,
                      ),
              ),
              const SizedBox(height: 10),
              HitoLikeCount(
                tourId: widget.controller.tourCode,
                hitoId: entry.id,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, color: tripMuted, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _text(detail?.ubicacion, entry.source.binnacleUbicacion),
                      style: const TextStyle(color: tripMuted, height: 1.4),
                    ),
                  ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting ||
                  snapshot.hasError ||
                  photos.isNotEmpty)
                const SizedBox(height: 24),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(color: tripTeal),
                  ),
                ),
              if (snapshot.hasError)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.pilo ? PiloFamilyTheme.soft : tripPaper,
                    borderRadius: BorderRadius.circular(widget.pilo ? 24 : 14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No pudimos cargar el detalle completo. Conservamos el resumen del hito.',
                        style: TextStyle(color: tripMuted),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _detail = widget.controller.detail(
                            entry.id,
                            retry: true,
                          ),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              if ((detail?.voiceNote ?? entry.source.voiceNote) != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TripVoicePlayer(
                    key: ValueKey(
                      'voice-${entry.id}-${(detail?.voiceNote ?? entry.source.voiceNote)!.id}',
                    ),
                    duration:
                        (detail?.voiceNote ?? entry.source.voiceNote)!.duration,
                    loadFile: () => widget.controller.voice(
                      entry.id,
                      (detail?.voiceNote ?? entry.source.voiceNote)!,
                    ),
                  ),
                ),
              if (photos.isNotEmpty)
                for (var index = 0; index < photos.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _photo(context, detail!, index),
                  ),
              const SizedBox(height: 24),
              Text(
                _text(detail?.descripcion, entry.source.binnacleDescripcion),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.65,
                  color: tripInk,
                ),
              ),
              if (_text(
                detail?.notaCierre,
                entry.source.binnacleNotaCierre,
              ).isNotEmpty) ...[
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.pilo ? PiloFamilyTheme.soft : tripPaper,
                    borderRadius: BorderRadius.circular(widget.pilo ? 24 : 16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nota del coordinador',
                        style: TextStyle(
                          fontSize: 14,
                          color: tripMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _text(
                          detail?.notaCierre,
                          entry.source.binnacleNotaCierre,
                        ),
                        style: const TextStyle(color: tripInk, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
              if (author.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Publicado por $author',
                    style: const TextStyle(color: tripMuted, fontSize: 14),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
