import 'dart:async';
import 'package:flutter/foundation.dart';
import '../lab/session.dart';
import 'photo_likes_repository.dart';

/// One shared state per tour/session. A pending reaction never edits another
/// photo, and a late GET cannot undo a newer interaction.
class PhotoLikesStore extends ChangeNotifier {
  final int tourId;
  final PhotoLikesRepository repository;
  final int Function() _sessionGeneration;
  late final int _generation = _sessionGeneration();
  final _photos = <int, PhotoLikeState>{};
  final _totals = <int, int>{};
  final _pending = <int, bool>{};
  bool _canLike = false, _loaded = false, _disposed = false;
  bool _requiresReauthentication = false;
  Object? _error;
  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();
  int _revision = 0;
  DateTime? _loadedAt;
  PhotoLikesStore({
    required this.tourId,
    required this.repository,
    int Function()? sessionGeneration,
  }) : _sessionGeneration = sessionGeneration ?? (() => LabSession.generation) {
    _generation;
  }
  bool get current => !_disposed && _generation == _sessionGeneration();
  bool get canLike => current && _canLike;
  bool get requiresReauthentication =>
      current && _loaded && !_canLike && _requiresReauthentication;
  bool get loaded => current && _loaded;
  bool get loading => current && _loading != null;
  Object? get error => current ? _error : null;
  bool isBusy(int photoId) => current && _pending.containsKey(photoId);
  PhotoLikeState? photo(int id) {
    if (!current) return null;
    final value = _photos[id];
    return value == null
        ? null
        : _pending.containsKey(id)
        ? value.withLiked(_pending[id]!)
        : value;
  }

  int? totalForHito(int hitoId) {
    if (!current || !_loaded || !_totals.containsKey(hitoId)) return null;
    var total = _totals[hitoId]!;
    for (final id in _pending.keys) {
      final base = _photos[id];
      if (base?.hitoId == hitoId)
        total += photo(id)!.likeCount - base!.likeCount;
    }
    return total.clamp(0, 2147483647);
  }

  void _emit() {
    if (current) notifyListeners();
  }

  Future<void> load({bool force = false}) {
    if (!current) return Future<void>.value();
    if (_loading != null) return _loading!;
    // Multiple photos mount together. Refresh on revisiting after 30 seconds;
    // callers may force a refresh without issuing one request per image.
    if (!force &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(seconds: 30)) {
      return Future<void>.value();
    }
    final revision = _revision;
    final done = Completer<void>();
    _loading = done.future;
    _error = null;
    _emit();
    () async {
      try {
        final result = await repository.load(tourId);
        if (!current || revision != _revision || _pending.isNotEmpty) return;
        final ids = <int>{};
        for (final value in result.photos) {
          if (value.photoId <= 0 ||
              value.hitoId <= 0 ||
              value.likeCount < 0 ||
              !ids.add(value.photoId)) {
            throw const FormatException('Identidades de fotos inválidas');
          }
        }
        _photos
          ..clear()
          ..addEntries(result.photos.map((p) => MapEntry(p.photoId, p)));
        _totals
          ..clear()
          ..addAll(result.hitoTotals);
        _canLike = result.canLike;
        _requiresReauthentication = result.requiresReauthentication;
        _loaded = true;
        _loadedAt = DateTime.now();
      } catch (e) {
        if (current && revision == _revision) _error = e;
      } finally {
        _loading = null;
        _emit();
        done.complete();
      }
    }();
    return done.future;
  }

  Future<bool> toggle(int photoId, int hitoId) {
    final before = photo(photoId);
    if (!canLike ||
        before == null ||
        before.hitoId != hitoId ||
        isBusy(photoId))
      return Future.value(false);
    final target = !before.likedByMe;
    _pending[photoId] = target;
    _revision++;
    _error = null;
    _emit();
    final done = Completer<bool>();
    _writes = _writes.then((_) async {
      if (!current) {
        _pending.remove(photoId);
        done.complete(false);
        return;
      }
      var success = false;
      try {
        final result = await repository.setLiked(
          tourId: tourId,
          hitoId: hitoId,
          photoId: photoId,
          liked: target,
        );
        if (!current) return;
        if (result.photo.photoId != photoId ||
            result.photo.hitoId != hitoId ||
            result.photo.likedByMe != target ||
            result.photo.likeCount < 0 ||
            result.hitoLikeCount < 0)
          throw const FormatException('Reacción no confirmada');
        _photos[photoId] = result.photo;
        _totals[hitoId] = result.hitoLikeCount;
        success = true;
      } catch (e) {
        if (current) _error = e;
      } finally {
        _revision++;
        _pending.remove(photoId);
        _emit();
        done.complete(success);
      }
    });
    return done.future;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
