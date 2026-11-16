import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/dto/binnacle.dart';

/// One hito with presentation-only numbering; [id] remains its stable identity.
class TripMapEntry {
  const TripMapEntry({
    required this.source,
    required this.ordinal,
    required this.position,
    required this.occurredAt,
  });

  final ConsolidatedTourSalesDTO source;
  final int ordinal;
  final LatLng? position;

  /// Ordering key, not an inferred time zone for the journey.
  /// Dates without an explicit offset retain their wall-clock components in UTC
  /// so sorting is independent of the device's time zone and DST normalization.
  final DateTime? occurredAt;

  int get id => source.binnacleDetailId;
  bool get unknownDate => occurredAt == null;
  bool get hasLocation => position != null;
}

class TripMapData {
  TripMapData._(this.entries)
    : mappedEntries = List.unmodifiable(
        entries.where((entry) => entry.hasLocation),
      );

  factory TripMapData.from(Iterable<ConsolidatedTourSalesDTO> source) {
    final parsed = source.map((dto) {
      return TripMapEntry(
        source: dto,
        ordinal: 0,
        position: parseTripMapPosition(
          dto.binnacleLatitud,
          dto.binnacleLongitud,
        ),
        occurredAt: parseTripMapDate(dto.binnacleFecha, dto.binnacleHora),
      );
    }).toList();
    parsed.sort((a, b) {
      final first = a.occurredAt;
      final second = b.occurredAt;
      // Keep undated entries accessible before the dated sequence. They must
      // be labelled "Fecha sin confirmar", never presented as the oldest/latest.
      if (first == null && second != null) return -1;
      if (first != null && second == null) return 1;
      final dateComparison = first?.compareTo(second!) ?? 0;
      return dateComparison != 0 ? dateComparison : a.id.compareTo(b.id);
    });
    return TripMapData._(
      List.unmodifiable([
        for (var index = 0; index < parsed.length; index++)
          TripMapEntry(
            source: parsed[index].source,
            ordinal: index + 1,
            position: parsed[index].position,
            occurredAt: parsed[index].occurredAt,
          ),
      ]),
    );
  }

  /// Includes entries with missing coordinates or unparseable dates.
  final List<TripMapEntry> entries;
  final List<TripMapEntry> mappedEntries;

  int get unmappedCount => entries.length - mappedEntries.length;
  int get unknownDateCount =>
      entries.where((entry) => entry.unknownDate).length;

  /// Null when no event has a valid date; an ID alone cannot establish recency.
  int? get latestId => _latestDatedId(entries);
  int? get latestMappedId => _latestDatedId(mappedEntries);

  TripMapEntry? entryById(int id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Keeps selection by ID after insertion, deletion or a date correction.
  /// If dates are unknown, a fallback selects a card without labelling it latest.
  int? preferredSelectionId(int? previousId) {
    if (previousId != null && entryById(previousId) != null) return previousId;
    return latestMappedId ??
        (mappedEntries.isNotEmpty ? mappedEntries.last.id : null) ??
        latestId ??
        (entries.isNotEmpty ? entries.last.id : null);
  }

  static int? _latestDatedId(List<TripMapEntry> values) {
    for (final entry in values.reversed) {
      if (!entry.unknownDate) return entry.id;
    }
    return null;
  }
}

LatLng? parseTripMapPosition(String latitude, String longitude) {
  final lat = double.tryParse(latitude.trim());
  final lon = double.tryParse(longitude.trim());
  if (lat == null ||
      lon == null ||
      !lat.isFinite ||
      !lon.isFinite ||
      lat < -90 ||
      lat > 90 ||
      lon < -180 ||
      lon > 180) {
    return null;
  }
  return LatLng(lat, lon);
}

/// Strictly parses the formats in the existing hito contract and LAB fixtures.
/// The separate event-time field wins when present. Impossible dates/times do
/// not roll into a different day, unlike DateTime.parse's permissive behavior.
DateTime? parseTripMapDate(String date, String time) {
  final rawDate = date.trim();
  final iso = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?(Z|[+-]\d{2}:?\d{2})?)?$',
    caseSensitive: false,
  ).firstMatch(rawDate);
  final dayFirst = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(rawDate);
  if (iso == null && dayFirst == null) return null;
  final year = int.parse(iso?.group(1) ?? dayFirst!.group(3)!);
  final month = int.parse(iso?.group(2) ?? dayFirst!.group(2)!);
  final day = int.parse(iso?.group(3) ?? dayFirst!.group(1)!);
  if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
    return null;
  }
  if (day > DateTime.utc(year, month + 1, 0).day) return null;

  var hour = 0;
  var minute = 0;
  var second = 0;
  var micros = 0;
  String? offset;
  final rawTime = time.trim();
  if (rawTime.isNotEmpty) {
    final clock = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(rawTime);
    if (clock == null) return null;
    hour = int.parse(clock.group(1)!);
    minute = int.parse(clock.group(2)!);
    second = int.parse(clock.group(3) ?? '0');
  } else if (iso?.group(4) != null) {
    hour = int.parse(iso!.group(4)!);
    minute = int.parse(iso.group(5)!);
    second = int.parse(iso.group(6) ?? '0');
    micros = int.parse((iso.group(7) ?? '').padRight(6, '0'));
    offset = iso.group(8)?.toUpperCase();
  }
  if (hour > 23 || minute > 59 || second > 59) return null;
  var result = DateTime.utc(year, month, day, hour, minute, second, 0, micros);
  if (offset != null && offset != 'Z') {
    final digits = offset.substring(1).replaceAll(':', '');
    final offsetHours = int.parse(digits.substring(0, 2));
    final offsetMinutes = int.parse(digits.substring(2));
    if (offsetHours > 23 || offsetMinutes > 59) return null;
    final minutes = offsetHours * 60 + offsetMinutes;
    result = result.subtract(
      Duration(minutes: offset.startsWith('+') ? minutes : -minutes),
    );
  }
  return result;
}

/// A marker or connected group of markers that overlap at the current zoom.
/// Its anchor is an actual hito, never an invented geographic midpoint.
class TripMapCluster {
  TripMapCluster(Iterable<TripMapEntry> entries)
    : entries = List.unmodifiable(entries);

  final List<TripMapEntry> entries;
  int get count => entries.length;
  bool get isCluster => count > 1;
  TripMapEntry get anchor => entries.last;
  LatLng get position => anchor.position!;
}

/// Groups projected screen positions, so zooming separates nearby points.
/// Coordinates are preserved; missing/invalid projections are not plotted.
List<TripMapCluster> groupTripMapEntries(
  Iterable<TripMapEntry> entries,
  Map<int, math.Point<double>> projectedPositions, {
  double minSeparation = 48,
}) {
  if (!minSeparation.isFinite || minSeparation < 0) {
    throw ArgumentError.value(minSeparation, 'minSeparation');
  }
  final visible = entries.where((entry) {
    final pixel = projectedPositions[entry.id];
    return entry.hasLocation &&
        pixel != null &&
        pixel.x.isFinite &&
        pixel.y.isFinite;
  }).toList()..sort((a, b) => a.ordinal.compareTo(b.ordinal));
  final parents = List.generate(visible.length, (index) => index);
  int root(int value) {
    while (parents[value] != value) {
      parents[value] = parents[parents[value]];
      value = parents[value];
    }
    return value;
  }

  final thresholdSquared = minSeparation * minSeparation;
  for (var i = 0; i < visible.length; i++) {
    final first = projectedPositions[visible[i].id]!;
    for (var j = i + 1; j < visible.length; j++) {
      final second = projectedPositions[visible[j].id]!;
      final dx = first.x - second.x;
      final dy = first.y - second.y;
      if (dx * dx + dy * dy <= thresholdSquared) {
        parents[root(j)] = root(i);
      }
    }
  }
  final groups = <int, List<TripMapEntry>>{};
  for (var i = 0; i < visible.length; i++) {
    groups.putIfAbsent(root(i), () => []).add(visible[i]);
  }
  return List.unmodifiable(groups.values.map(TripMapCluster.new));
}
