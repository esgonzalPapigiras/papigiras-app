import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/likes/photo_likes_widgets.dart';

/// Readable content shared by role-specific detail screens. The caller owns
/// loading, permissions and any actions; this widget only presents the record.
class TripHitoContent extends StatelessWidget {
  const TripHitoContent({
    super.key,
    required this.detail,
    this.actions,
    this.voicePlayer,
    this.familyStyle = false,
    this.tourId,
    this.hitoId,
  });

  final DetailHitoList detail;
  final int? tourId, hitoId;
  final Widget? actions;
  final Widget? voicePlayer;
  final bool familyStyle;

  Color get _ink => familyStyle ? PiloFamilyTheme.ink : tripInk;
  Color get _muted => familyStyle ? PiloFamilyTheme.secondary : tripMuted;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: familyStyle ? PiloFamilyTheme.paper : tripSurface,
    child: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: CustomScrollView(
            key: const PageStorageKey('trip-hito-content'),
            cacheExtent: 200,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                sliver: SliverToBoxAdapter(child: _header()),
              ),
              if (voicePlayer != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  sliver: SliverToBoxAdapter(child: voicePlayer!),
                ),
              if (detail.images.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  sliver: SliverToBoxAdapter(child: _photo(context, 0)),
                ),
              if (detail.descripcion?.trim().isNotEmpty == true)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      detail.descripcion!.trim(),
                      key: const ValueKey('trip-content-description'),
                      style: TextStyle(color: _ink, fontSize: 16, height: 1.55),
                    ),
                  ),
                ),
              if (detail.images.length > 1)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _photo(context, index + 1),
                      ),
                      childCount: detail.images.length - 1,
                      addAutomaticKeepAlives: false,
                    ),
                  ),
                ),
              if (detail.notaCierre?.trim().isNotEmpty == true)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nota del coordinador',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          detail.notaCierre!.trim(),
                          key: const ValueKey('trip-content-note'),
                          style: TextStyle(
                            color: _ink,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header() {
    final title = detail.titulo?.trim() ?? '';
    final location = _location();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title.isEmpty ? 'Hito sin título' : title,
            key: const ValueKey('trip-content-title'),
            style: familyStyle
                ? PiloFamilyTheme.display(39)
                : const TextStyle(
                    color: tripInk,
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _moment(),
          key: const ValueKey('trip-content-moment'),
          style: TextStyle(
            color: familyStyle ? PiloFamilyTheme.accentText : tripTeal,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: _muted,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  key: const ValueKey('trip-content-location'),
                  style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ),
        ],
        if (detail.missingImageCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            detail.missingImageCount == 1
                ? 'Una foto no está disponible.'
                : '${detail.missingImageCount} fotos no están disponibles.',
            key: const ValueKey('trip-content-missing-photos'),
            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
        ],
        if (tourId != null && hitoId != null) ...[
          const SizedBox(height: 10),
          HitoLikeCount(tourId: tourId!, hitoId: hitoId!),
        ],
        if (actions != null) ...[const SizedBox(height: 12), actions!],
      ],
    );
  }

  Widget _photo(BuildContext context, int index) {
    final photoId = detail.photoIdAt(index);
    return Material(
      color: familyStyle ? PiloFamilyTheme.soft : tripPaper,
      borderRadius: BorderRadius.circular(familyStyle ? 26 : 18),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              label: 'Abrir foto ${index + 1} de ${detail.images.length}',
              child: InkWell(
                key: ValueKey('trip-content-photo-$index'),
                onTap: () => openTripPhotos(
                  context,
                  detail.images,
                  initialIndex: index,
                  tourId: tourId,
                  hitoId: hitoId,
                  imageIds: detail.imageIds,
                ),
                child: TripPhoto(
                  encoded: detail.images[index],
                  fit: BoxFit.cover,
                  cacheWidth: 1400,
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _ink.withValues(alpha: .75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (tourId != null && hitoId != null && photoId != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: PhotoLikeButton(
                  tourId: tourId!,
                  hitoId: hitoId!,
                  photoId: photoId,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _location() {
    final value = detail.ubicacion?.trim() ?? '';
    if (RegExp(
      r'PlatformException|MissingPluginException|geocod(?:ing|er).*?(?:error|exception)|error.*?geocod',
      caseSensitive: false,
    ).hasMatch(value)) {
      // This detail contract has no coordinates, so it cannot assert a valid
      // map position when a historical geocoder's error is stored as text.
      return 'Ubicación no disponible';
    }
    return value;
  }

  String _moment() {
    final rawDate = detail.fecha?.trim() ?? '';
    // Validate only the recorded calendar date without converting time zones
    // or synthesizing a midnight time for date-only records.
    final date = parseTripMapDate(rawDate, '00:00');
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
    final day = date == null
        ? 'Fecha sin confirmar'
        : '${date.day} ${months[date.month - 1]} ${date.year}';
    final explicitClock = detail.hora?.trim() ?? '';
    final isoClock =
        RegExp(r'[T ](\d{2}:\d{2}(?::\d{2})?)').firstMatch(rawDate)?.group(1) ??
        '';
    final rawClock = explicitClock.isNotEmpty ? explicitClock : isoClock;
    final clock = parseTripMapDate('2000-01-01', rawClock);
    if (rawClock.isEmpty || clock == null) return day;
    return '$day · ${clock.hour.toString().padLeft(2, '0')}:${clock.minute.toString().padLeft(2, '0')}';
  }
}
