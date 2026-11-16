import 'dart:io';
import '../voice/voice_note_metadata.dart';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_bus_controller.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

/// Shared by the compact map and its expanded route. It owns no map camera,
/// so selecting an event and opening its detail do not recreate the data load.
class TripMapController extends ChangeNotifier {
  TripMapController({required this.tourCode, CoordinatorProviders? provider})
    : _provider = provider ?? CoordinatorProviders(),
      _ownsProvider = provider == null;

  final int tourCode;
  TripBusController? _bus;
  final _visibleMapOwners = <Object>{};

  /// Both map sizes share one reader and one polling timer.
  TripBusController get bus =>
      _bus ??= TripBusController(tourId: tourCode, provider: _provider);

  void setMapVisible(Object owner, bool visible) {
    if (_disposed) return;
    if (visible) {
      _visibleMapOwners.add(owner);
    } else {
      _visibleMapOwners.remove(owner);
    }
    if (_visibleMapOwners.isNotEmpty) {
      bus.setVisible(true);
    } else {
      _bus?.setVisible(false);
    }
  }

  final CoordinatorProviders _provider;
  final bool _ownsProvider;
  final _authorPictures = LinkedHashMap<int, Future<Uint8List?>>();
  final _details = LinkedHashMap<int, Future<DetailHitoList>>();
  static const _detailCacheLimit = 3;

  TripMapData? _data;
  bool _loading = false;
  String? _error;
  int? _selectedId;
  bool _selectionCleared = false;
  int _selectionRevision = 0;
  bool _recenterOnSelection = true;
  int _refreshGeneration = 0;
  bool _disposed = false;

  TripMapData? get data => _data;
  bool get loading => _loading;
  String? get error => _error;
  int? get selectedId => _selectedId;

  /// Explicit selections only; refresh preserves the card presentation state.
  int get selectionRevision => _selectionRevision;
  bool get recenterOnSelection => _recenterOnSelection;
  TripMapEntry? get selected =>
      _selectedId == null ? null : _data?.entryById(_selectedId!);

  int get _selectedIndex =>
      _data?.entries.indexWhere((entry) => entry.id == _selectedId) ?? -1;

  bool get canPrevious => _selectedIndex > 0;
  bool get canNext {
    final index = _selectedIndex;
    return index >= 0 && index + 1 < (_data?.entries.length ?? 0);
  }

  /// Fetches the existing tour bitacora. The last successful data remains
  /// available after an error, accompanied by [error], never replaced by demos.
  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_refreshGeneration;
    _loading = true;
    _error = null;
    _details.clear();
    _authorPictures.clear();
    notifyListeners();
    try {
      final rows = await _provider.getBinnacle(tourCode.toString());
      if (_disposed || generation != _refreshGeneration) return;
      final updated = TripMapData.from(rows);
      _data = updated;
      if (!_selectionCleared) {
        _selectedId = updated.preferredSelectionId(_selectedId);
      }
    } catch (_) {
      if (_disposed || generation != _refreshGeneration) return;
      _error = 'No pudimos actualizar los hitos. Inténtalo de nuevo.';
    } finally {
      if (!_disposed && generation == _refreshGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void select(int id, {bool recenter = true}) {
    if (_disposed || _data?.entryById(id) == null) {
      return;
    }
    _selectionCleared = false;
    _selectedId = id;
    _recenterOnSelection = recenter;
    ++_selectionRevision;
    notifyListeners();
  }

  /// Keep the map clear until another pin or list item is selected.
  void clearSelection() {
    if (_disposed || _selectedId == null) return;
    _selectionCleared = true;
    _selectedId = null;
    notifyListeners();
  }

  /// Traverses all events, including those without coordinates. Their cards
  /// remain accessible even when the map has no marker for them.
  void previous() {
    if (!_disposed && canPrevious) {
      select(_data!.entries[_selectedIndex - 1].id);
    }
  }

  void next() {
    if (!_disposed && canNext) {
      select(_data!.entries[_selectedIndex + 1].id);
    }
  }

  /// Loads only requested details. Sharing the Future avoids another download
  /// when a thumbnail opens the detail route. Errors remain cached until retry;
  /// rebuilding a failed card therefore does not cause an automatic retry loop.
  Future<DetailHitoList> detail(int id, {bool retry = false}) {
    if (_disposed) {
      return Future.error(StateError('El mapa ya está cerrado.'));
    }
    if (_data?.entryById(id) == null) {
      return Future.error(ArgumentError.value(id, 'id', 'Hito no disponible.'));
    }
    final cached = _details.remove(id);
    if (!retry && cached != null) {
      _details[id] = cached;
      return cached;
    }
    final requested = Future<DetailHitoList>.sync(
      () => _provider.getHitoComplete(id.toString(), tourCode.toString()),
    );
    _details[id] = requested;
    while (_details.length > _detailCacheLimit) {
      _details.remove(_details.keys.first);
    }
    return requested;
  }

  Future<Uint8List?> authorPicture(TripMapEntry entry) {
    final author = entry.source.author;
    if (author == null) return Future.value();
    final cached = _authorPictures.remove(author.coordinatorId);
    final result = cached ?? _provider.getHitoAuthorPicture(entry.id, tourCode);
    result.ignore();
    _authorPictures[author.coordinatorId] = result;
    while (_authorPictures.length > 6) {
      _authorPictures.remove(_authorPictures.keys.first);
    }
    return result;
  }

  Future<File> voice(int hitoId, VoiceNoteMetadata metadata) =>
      _provider.readHitoVoice(hitoId, tourCode, metadata);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_refreshGeneration;
    _details.clear();
    _authorPictures.clear();
    _visibleMapOwners.clear();
    _bus?.dispose();
    _data = null;
    _selectedId = null;
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }
}
