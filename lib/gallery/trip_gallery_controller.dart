import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import '../dto/DetailHitoList.dart';
import '../dto/binnacle.dart';
import '../lab/media_data.dart';
import '../maps/trip_map_data.dart';
import '../provider/coordinatorProvider.dart';

/// Only identities and recorded dates are retained for the whole collection.
/// Photo bytes are read through the existing authenticated hito endpoint.
class TripGalleryPhoto {
  const TripGalleryPhoto(
    this.hitoId,
    this.imageIndex,
    this.date, {
    this.title = '',
    this.photoId,
  });
  final int hitoId, imageIndex;
  final int? photoId;
  final DateTime? date;
  final String title;
  String get key =>
      photoId == null ? '$hitoId:$imageIndex' : '$hitoId:photo-$photoId';
}

class TripGalleryDay {
  TripGalleryDay(this.date, this.photos);
  final DateTime? date;
  final List<TripGalleryPhoto> photos;
  String title(String departure) {
    final start = galleryCalendarDate(departure);
    if (date == null) return 'Sin fecha';
    if (start == null || date!.isBefore(start)) return galleryDateLabel(date!);
    return 'Día ${date!.difference(start).inDays + 1}';
  }
}

// Keep the date as recorded: a phone's timezone must not change a trip day.
DateTime? galleryCalendarDate(String value) {
  final parsed = parseTripMapDate(value, '00:00');
  return parsed == null
      ? null
      : DateTime.utc(parsed.year, parsed.month, parsed.day);
}

String galleryDateLabel(DateTime date, {bool includeYear = true}) {
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
  final day = '${date.day} ${months[date.month - 1]}';
  return includeYear ? '$day ${date.year}' : '$day.';
}

class TripGalleryController extends ChangeNotifier {
  TripGalleryController({required this.tourId, CoordinatorProviders? provider})
    : _provider = provider ?? CoordinatorProviders(),
      _ownsProvider = provider == null;
  final int tourId;
  final CoordinatorProviders _provider;
  final bool _ownsProvider;
  List<ConsolidatedTourSalesDTO> _rows = [];
  final _rowsByDate = <DateTime, List<ConsolidatedTourSalesDTO>>{};
  final _photosByHito = <int, List<TripGalleryPhoto>>{};
  final _unavailableByHito = <int, int>{};
  final _failedHitos = <DateTime?, int>{};
  final _details = LinkedHashMap<int, DetailHitoList>();
  final _pendingDetails = <int, Future<DetailHitoList>>{};
  final _thumbnails = LinkedHashMap<String, Uint8List>();
  final _pendingThumbnails = <String, Future<Uint8List?>>{};
  Future<void> _queue = Future<void>.value();
  int _cursor = 0, _generation = 0, _thumbnailBytes = 0;
  bool _disposed = false, loading = false, initialized = false;
  String? _listError;
  String? get error => errorForDate(null);
  String? errorForDate(DateTime? day) =>
      _listError ??
      (_failedHitos.containsKey(day)
          ? 'Algunas fotos no se pudieron cargar.'
          : null);

  Future<void> retry({DateTime? date}) => _listError != null || !initialized
      ? refresh(date: date)
      : loadMore(date: date);

  static const batchSize = 4;
  static const thumbnailBudget = 16 * 1024 * 1024;
  static const detailBudget = 24 * 1024 * 1024;

  List<DateTime> get dates => List.unmodifiable(_rowsByDate.keys);

  Iterable<ConsolidatedTourSalesDTO> _visibleRows(DateTime? day) =>
      day == null ? _rows.take(_cursor) : _rowsByDate[day] ?? const [];

  List<TripGalleryPhoto> photosForDate(DateTime? day) => [
    for (final row in _visibleRows(day))
      ...?_photosByHito[row.binnacleDetailId],
  ];

  int unavailableImagesForDate(DateTime? day) => _visibleRows(day).fold(
    0,
    (total, row) => total + (_unavailableByHito[row.binnacleDetailId] ?? 0),
  );
  int get unavailableImages => unavailableImagesForDate(null);
  List<TripGalleryPhoto> get photos => List.unmodifiable(photosForDate(null));
  bool get hasMore => initialized && _cursor < _rows.length;
  bool hasMoreOnDate(DateTime day) =>
      initialized && (_rowsByDate[day]?.any(_needsDetail) ?? false);

  bool _needsDetail(ConsolidatedTourSalesDTO row) =>
      !_photosByHito.containsKey(row.binnacleDetailId);

  void _advanceCursor() {
    // Keep Todos in chronological order even if a later date was opened first.
    while (_cursor < _rows.length && !_needsDetail(_rows[_cursor])) {
      _cursor++;
    }
  }

  List<TripGalleryDay> get days => daysForDate(null);

  List<TripGalleryDay> daysForDate(DateTime? date) {
    final result = <TripGalleryDay>[];
    for (final photo in photosForDate(date)) {
      if (result.isEmpty || result.last.date != photo.date) {
        result.add(TripGalleryDay(photo.date, []));
      }
      result.last.photos.add(photo);
    }
    return result;
  }

  Future<void> refresh({DateTime? date}) async {
    if (_disposed || loading) return;
    final generation = ++_generation;
    loading = true;
    _listError = null;
    _pendingDetails.clear();
    _pendingThumbnails.clear();
    notifyListeners();
    try {
      final rows = await _provider.getBinnacle(tourId.toString());
      if (!_current(generation)) return;
      final unique = <int, ConsolidatedTourSalesDTO>{};
      for (final row in rows) {
        unique.putIfAbsent(row.binnacleDetailId, () => row);
      }
      _rows = unique.values.toList()
        ..sort((a, b) {
          final ad = galleryCalendarDate(a.binnacleFecha);
          final bd = galleryCalendarDate(b.binnacleFecha);
          if (ad == null && bd != null) return 1;
          if (ad != null && bd == null) return -1;
          final date = ad?.compareTo(bd!) ?? 0;
          if (date != 0) return date;
          final at = parseTripMapDate(a.binnacleFecha, a.binnacleHora);
          final bt = parseTripMapDate(b.binnacleFecha, b.binnacleHora);
          if (at == null && bt != null) return 1;
          if (at != null && bt == null) return -1;
          final time = at?.compareTo(bt!) ?? 0;
          return time != 0
              ? time
              : a.binnacleDetailId.compareTo(b.binnacleDetailId);
        });
      _rowsByDate.clear();
      for (final row in _rows) {
        final date = galleryCalendarDate(row.binnacleFecha);
        if (date != null) (_rowsByDate[date] ??= []).add(row);
      }
      _photosByHito.clear();
      _unavailableByHito.clear();
      _failedHitos.clear();
      _details.clear();
      _thumbnails.clear();
      _thumbnailBytes = 0;
      _cursor = 0;
      initialized = true;
    } catch (_) {
      if (_current(generation)) {
        _listError = 'No se pudo cargar la galería.';
      }
    } finally {
      if (_current(generation)) {
        loading = false;
        notifyListeners();
      }
    }
    if (_current(generation) && _listError == null) await loadMore(date: date);
  }

  Future<void> loadMore({DateTime? date}) async {
    if (_disposed || loading || _listError != null) return;
    final candidates = date == null
        ? _rows.skip(_cursor)
        : _rowsByDate[date] ?? const <ConsolidatedTourSalesDTO>[];
    final batch = candidates.where(_needsDetail).take(batchSize).toList();
    if (batch.isEmpty) return;
    final generation = _generation;
    loading = true;
    _failedHitos.remove(date);
    notifyListeners();
    for (final row in batch) {
      final id = row.binnacleDetailId;
      try {
        final detail = await _detail(id);
        if (!_current(generation)) return;
        final day = date ?? galleryCalendarDate(row.binnacleFecha);
        final title = detail.titulo?.trim() ?? '';
        _photosByHito[id] = [
          for (var i = 0; i < detail.images.length; i++)
            TripGalleryPhoto(
              id,
              i,
              day,
              photoId: detail.photoIdAt(i),
              title: title.isEmpty ? row.binnacleTitulo.trim() : title,
            ),
        ];
        _unavailableByHito[id] = detail.missingImageCount;
        _failedHitos.removeWhere((_, failedId) => failedId == id);
        _advanceCursor();
        notifyListeners();
      } catch (_) {
        if (_current(generation)) _failedHitos[date] = id;
        break;
      }
    }
    if (_current(generation)) {
      loading = false;
      notifyListeners();
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  Future<DetailHitoList> _detail(int id) {
    if (_disposed) return Future.error(StateError('Gallery closed'));
    final cached = _details.remove(id);
    if (cached != null) {
      _details[id] = cached;
      return Future.value(cached);
    }
    final pending = _pendingDetails[id];
    if (pending != null) return pending;
    final generation = _generation;
    // Serial requests bound peak network/JSON memory; simultaneous tiles coalesce.
    final task = _queue.then((_) async {
      if (!_current(generation)) throw StateError('Gallery changed');
      final detail = await _provider.getHitoComplete(
        id.toString(),
        tourId.toString(),
      );
      if (!_current(generation)) throw StateError('Gallery changed');
      _details[id] = detail;
      int size() => _details.values.fold(
        0,
        (sum, d) => sum + d.images.fold<int>(0, (n, s) => n + s.length),
      );
      while (_details.length > 1 &&
          (_details.length > 2 || size() > detailBudget)) {
        _details.remove(_details.keys.first);
      }
      // One oversized hito is the irreducible unit of the existing API.
      return detail;
    });
    _queue = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pendingDetails[id] = task;
    task.then<void>(
      (_) {
        if (identical(_pendingDetails[id], task)) _pendingDetails.remove(id);
      },
      onError: (Object _, StackTrace __) {
        if (identical(_pendingDetails[id], task)) _pendingDetails.remove(id);
      },
    );
    return task;
  }

  Future<Uint8List?> fullImage(TripGalleryPhoto photo) async {
    final detail = await _detail(photo.hitoId);
    // A refreshed detail may reorder/remove photos. A known server identity
    // must never fall back to the old index and display another photo's likes.
    final index = photo.photoId == null
        ? photo.imageIndex
        : detail.imageIds.indexOf(photo.photoId);
    if (_disposed || index < 0 || index >= detail.images.length) return null;
    final encoded = detail.images[index];
    return encoded.length > 128 * 1024
        ? compute(LocalImageData.decode, encoded)
        : LocalImageData.decode(encoded);
  }

  Future<Uint8List?> thumbnail(TripGalleryPhoto photo) {
    final cached = _thumbnails.remove(photo.key);
    if (cached != null) {
      _thumbnails[photo.key] = cached;
      return Future.value(cached);
    }
    return _pendingThumbnails.putIfAbsent(photo.key, () {
      final generation = _generation;
      final task = _makeThumbnail(photo, generation);
      task.then<void>(
        (_) {
          if (identical(_pendingThumbnails[photo.key], task))
            _pendingThumbnails.remove(photo.key);
        },
        onError: (Object _, StackTrace __) {
          if (identical(_pendingThumbnails[photo.key], task))
            _pendingThumbnails.remove(photo.key);
        },
      );
      return task;
    });
  }

  Future<Uint8List?> _makeThumbnail(
    TripGalleryPhoto photo,
    int generation,
  ) async {
    final bytes = await fullImage(photo);
    if (bytes == null || !_current(generation)) return null;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 600,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null || !_current(generation)) return null;
        final result = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (result.lengthInBytes <= thumbnailBudget) {
          _thumbnails[photo.key] = result;
          _thumbnailBytes += result.lengthInBytes;
          while (_thumbnailBytes > thumbnailBudget) {
            _thumbnailBytes -= _thumbnails
                .remove(_thumbnails.keys.first)!
                .lengthInBytes;
          }
        }
        return result;
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _photosByHito.clear();
    _unavailableByHito.clear();
    _rowsByDate.clear();
    _rows = [];
    _details.clear();
    _thumbnails.clear();
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }
}
