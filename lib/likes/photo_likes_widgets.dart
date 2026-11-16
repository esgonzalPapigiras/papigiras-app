import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/pilo_family_theme.dart';
import '../lab/mode.dart';
import '../lab/session.dart';
import 'photo_likes_repository.dart';
import 'photo_likes_store.dart';
import 'photo_likes_reauthentication.dart';

/// Used by the existing pull-to-refresh controls in gallery and bitácora.
Future<void> refreshPhotoLikes(BuildContext context, int tourId) async {
  await _Stores.of(context, tourId)?.load(force: true);
}

class PhotoLikesScope extends InheritedWidget {
  final PhotoLikesStore store;
  const PhotoLikesScope({super.key, required this.store, required super.child});
  @override
  bool updateShouldNotify(PhotoLikesScope oldWidget) =>
      oldWidget.store != store;
}

abstract final class _Stores {
  static int generation = -1;
  static final stores = <int, PhotoLikesStore>{};
  static PhotoLikesStore? of(BuildContext context, int tourId) {
    final injected = context
        .dependOnInheritedWidgetOfExactType<PhotoLikesScope>()
        ?.store;
    if (injected != null) return injected.tourId == tourId ? injected : null;
    if (LabMode.fixturesForTests || tourId <= 0) return null;
    if (generation != LabSession.generation) {
      // Old widgets may still be finishing a route animation; their store
      // rejects every operation through its captured session generation.
      stores.clear();
      generation = LabSession.generation;
    }
    return stores.putIfAbsent(
      tourId,
      () => PhotoLikesStore(
        tourId: tourId,
        repository: HttpPhotoLikesRepository(),
      ),
    );
  }
}

class _LikeBuilder extends StatefulWidget {
  final int tourId;
  final Widget Function(BuildContext, PhotoLikesStore) builder;
  const _LikeBuilder({required this.tourId, required this.builder});
  @override
  State<_LikeBuilder> createState() => _LikeBuilderState();
}

class _LikeBuilderState extends State<_LikeBuilder> {
  PhotoLikesStore? _store;
  @override
  void initState() {
    super.initState();
    LabSession.changed.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted) return;
    setState(_bind);
  }

  @override
  void dispose() {
    LabSession.changed.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(_LikeBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tourId != widget.tourId) _bind();
  }

  void _bind() {
    final store = _Stores.of(context, widget.tourId);
    if (_store == store) return;
    _store = store;
    // Loading outside build keeps shared ChangeNotifier subscribers safe.
    scheduleMicrotask(() {
      if (mounted && _store == store) store?.load();
    });
  }

  @override
  Widget build(BuildContext context) => _store == null
      ? const SizedBox.shrink()
      : ListenableBuilder(
          listenable: _store!,
          builder: (context, _) => widget.builder(context, _store!),
        );
}

/// Interactive only when the server grants attorney capability. Coordinators
/// see exactly the same persisted photo count, without a reaction action.
class PhotoLikeButton extends StatelessWidget {
  final int tourId, hitoId, photoId;
  final bool overlay;
  const PhotoLikeButton({
    super.key,
    required this.tourId,
    required this.hitoId,
    required this.photoId,
    this.overlay = true,
  });
  @override
  Widget build(BuildContext context) => _LikeBuilder(
    tourId: tourId,
    builder: (context, store) {
      final photo = store.photo(photoId);
      if (photo != null && photo.hitoId != hitoId)
        return const SizedBox.shrink();
      final liked = photo?.likedByMe == true;
      final count = photo?.likeCount;
      final busy = store.isBusy(photoId);
      final canReact = photo != null && store.canLike && !busy;
      final retry = photo == null && store.error != null;
      final renew = photo != null && store.requiresReauthentication;
      final actionable = canReact || retry || renew;
      final label = retry
          ? 'Reintentar likes de esta foto'
          : renew
          ? 'Activa tus Me gusta. ${count ?? 0} me gusta en esta foto'
          : canReact
          ? '${liked ? 'Quitar Me gusta' : 'Me gusta'}. ${count ?? 0} me gusta en esta foto'
          : count == null
          ? 'Cargando likes de esta foto'
          : '$count me gusta en esta foto';
      Future<void> react() async {
        if (retry) {
          await store.load(force: true);
          return;
        }
        var activeStore = store;
        if (renew) {
          final renewed = await reauthenticatePhotoLikes(
            context,
            tourId: tourId,
          );
          if (!renewed || !context.mounted) return;
          final refreshed = _Stores.of(context, tourId);
          if (refreshed == null) return;
          await refreshed.load(force: true);
          if (!context.mounted || !refreshed.current) return;
          activeStore = refreshed;
          // Another device may have reacted while this session was old.
          // Preserve the intent of this tap rather than blindly toggling twice.
          if (activeStore.canLike &&
              activeStore.photo(photoId)?.likedByMe == !liked)
            return;
        }
        final success = await activeStore.toggle(photoId, hitoId);
        if (!context.mounted) return;
        if (success) {
          if (!MediaQuery.disableAnimationsOf(context))
            HapticFeedback.selectionClick();
        } else if (activeStore.current) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo guardar tu Me gusta. Inténtalo de nuevo.',
              ),
            ),
          );
        }
      }

      return Semantics(
        key: ValueKey('photo-like-$photoId'),
        container: true,
        label: label,
        button: actionable,
        toggled: store.canLike ? liked : null,
        onTap: actionable ? react : null,
        child: ExcludeSemantics(
          child: Tooltip(
            message: label,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const StadiumBorder(),
                // Keep this hit target while a write is pending, so a rapid
                // second tap never opens the photo/hito underneath it.
                onTap: actionable
                    ? react
                    : busy
                    ? () {}
                    : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 44,
                    maxWidth: 74,
                  ),
                  child: Padding(
                    // A light 32 px capsule inside a comfortable 44 px target.
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: overlay
                            ? Colors.white.withValues(alpha: .97)
                            : PiloFamilyTheme.soft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                scale: liked ? 1.08 : 1,
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 160),
                                child: Icon(
                                  retry
                                      ? Icons.refresh_rounded
                                      : liked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 19,
                                  color: liked
                                      ? PiloFamilyTheme.accentText
                                      : PiloFamilyTheme.ink,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                count?.toString() ?? '—',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: PiloFamilyTheme.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// This is a read-only aggregate of photo reactions, never a second like.
class HitoLikeCount extends StatelessWidget {
  final int tourId, hitoId;
  const HitoLikeCount({super.key, required this.tourId, required this.hitoId});
  @override
  Widget build(BuildContext context) => _LikeBuilder(
    tourId: tourId,
    builder: (context, store) {
      final total = store.totalForHito(hitoId);
      return Semantics(
        key: ValueKey('hito-like-$hitoId'),
        container: true,
        label: total == null
            ? 'Likes de las fotos del hito no disponibles'
            : '$total me gusta en las fotos de este hito',
        child: ExcludeSemantics(
          child: Tooltip(
            message: 'Total de Me gusta de las fotos',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 17,
                    color: total != null && total > 0
                        ? PiloFamilyTheme.accentText
                        : PiloFamilyTheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    total?.toString() ?? '—',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PiloFamilyTheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
