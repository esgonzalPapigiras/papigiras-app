import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'trip_map_data.dart';

/// A viewport-scoped walk, not the chronological order of the bitacora.
/// Forward chooses the nearest unvisited visible pin; back retraces that walk.
/// Programmatic recentering preserves history so adjacent pins never ping-pong.
class TripMapNearbyNavigation {
  TripMapData? _data;
  int? _selectedId;
  Set<int> _visible = {};
  LatLng? _center;
  final _history = <int>[];
  int _cursor = -1;
  static const _distance = Distance(roundResult: false);

  void sync(TripMapData data, int? selectedId) {
    if (_data != data || _selectedId != selectedId) {
      _data = data;
      _selectedId = selectedId;
      _resetHistory();
    }
  }

  /// Only a deliberate map pan/zoom starts a new neighborhood. Opening the
  /// card or centering it can resize the map without discarding the way back.
  bool updateViewport({
    required Iterable<int> visibleIds,
    required LatLng center,
    bool userMoved = false,
  }) {
    final before = (previousId, nextId);
    final updated = visibleIds.toSet();
    final changed = !setEquals(_visible, updated);
    _visible = updated;
    _center = center;
    if (userMoved) _resetHistory();
    return changed || before != (previousId, nextId);
  }

  void _resetHistory() {
    _history.clear();
    if (_selectedId != null) _history.add(_selectedId!);
    _cursor = _history.length - 1;
  }

  int? get _previousIndex {
    for (var i = _cursor - 1; i >= 0; i--) {
      if (_visible.contains(_history[i])) return i;
    }
    return null;
  }

  int? get previousId {
    final index = _previousIndex;
    return index == null ? null : _history[index];
  }

  int? get _forwardIndex {
    for (var i = _cursor + 1; i < _history.length; i++) {
      if (_visible.contains(_history[i])) return i;
    }
    return null;
  }

  int? get nextId {
    final forward = _forwardIndex;
    if (forward != null) return _history[forward];
    final selected = _data?.entryById(_selectedId ?? -1);
    final origin = _visible.contains(_selectedId)
        ? selected?.position ?? _center
        : _center;
    if (origin == null) return null;
    final visited = _history.toSet();
    int? nearest;
    var nearestDistance = double.infinity;
    for (final entry in _data?.mappedEntries ?? const <TripMapEntry>[]) {
      if (!_visible.contains(entry.id) || visited.contains(entry.id)) continue;
      final distance = _distance(origin, entry.position!);
      if (distance < nearestDistance ||
          (distance == nearestDistance && entry.id < (nearest ?? entry.id))) {
        nearest = entry.id;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  int? next() {
    final next = nextId;
    if (next == null) return null;
    final forward = _forwardIndex;
    if (forward != null) {
      _cursor = forward;
    } else {
      _history.add(next);
      _cursor = _history.length - 1;
    }
    _selectedId = next;
    return next;
  }

  int? previous() {
    final index = _previousIndex;
    if (index == null) return null;
    _cursor = index;
    _selectedId = _history[index];
    return _selectedId;
  }
}
