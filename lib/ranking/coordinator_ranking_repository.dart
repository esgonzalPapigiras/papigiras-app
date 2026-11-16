import 'dart:convert';
import 'dart:typed_data';
import '../lab/api_http.dart';
import '../lab/preferences.dart';
import '../lab/session.dart';

int _number(Object? value, {int minimum = 0}) {
  if (value is! int || value < minimum) {
    throw const FormatException('Respuesta del ranking inválida.');
  }
  return value;
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Respuesta del ranking inválida.');
  }
  return value;
}

String _text(Object? value) {
  if (value is! String) {
    throw const FormatException('Respuesta del ranking inválida.');
  }
  return value.trim();
}

class CoordinatorRankingRule {
  const CoordinatorRankingRule({
    required this.version,
    required this.hitoPoints,
    required this.photoPoints,
    required this.likePoints,
  });
  final String version;
  final int hitoPoints, photoPoints, likePoints;
  factory CoordinatorRankingRule.fromJson(Map<String, dynamic> json) =>
      CoordinatorRankingRule(
        version: _text(json['version']),
        hitoPoints: _number(json['hitoPoints']),
        photoPoints: _number(json['photoPoints']),
        likePoints: _number(json['likePoints']),
      );

  bool matches(CoordinatorRankingRule other) =>
      version == other.version &&
      hitoPoints == other.hitoPoints &&
      photoPoints == other.photoPoints &&
      likePoints == other.likePoints;
}

/// Scores and the one best trip are chosen by the server, never summed here.
class CoordinatorRankingEntry {
  const CoordinatorRankingEntry({
    required this.rank,
    required this.coordinatorId,
    required this.firstName,
    required this.lastName,
    required this.photoAvailable,
    required this.bestTourId,
    required this.hitoCount,
    required this.photoCount,
    required this.likeCount,
    required this.score,
  });
  final int rank, coordinatorId, bestTourId;
  final String firstName, lastName;
  final bool photoAvailable;
  final int hitoCount, photoCount, likeCount, score;
  String get displayName => '$firstName $lastName'.trim();
  factory CoordinatorRankingEntry.fromJson(Map<String, dynamic> json) {
    if (json['photoAvailable'] is! bool) {
      throw const FormatException('Respuesta del ranking inválida.');
    }
    return CoordinatorRankingEntry(
      rank: _number(json['rank'], minimum: 1),
      coordinatorId: _number(json['coordinatorId'], minimum: 1),
      firstName: _text(json['firstName']),
      lastName: _text(json['lastName']),
      photoAvailable: json['photoAvailable'] as bool,
      bestTourId: _number(json['bestTourId'], minimum: 1),
      hitoCount: _number(json['hitoCount']),
      photoCount: _number(json['photoCount']),
      likeCount: _number(json['likeCount']),
      score: _number(json['score']),
    );
  }
}

class CoordinatorRankingPage {
  const CoordinatorRankingPage({
    required this.season,
    required this.availableSeasons,
    required this.generatedAt,
    required this.rule,
    required this.totalParticipants,
    required this.currentCoordinatorId,
    required this.myEntry,
    required this.entries,
    required this.limit,
    required this.offset,
    required this.hasMore,
    this.unattributedHitoCount = 0,
    int? nextOffset,
  }) : _nextOffset = nextOffset;
  final int season, totalParticipants, currentCoordinatorId, limit, offset;
  final int unattributedHitoCount;
  final List<int> availableSeasons;
  final DateTime generatedAt;
  final CoordinatorRankingRule rule;
  final CoordinatorRankingEntry? myEntry;
  final List<CoordinatorRankingEntry> entries;
  final bool hasMore;
  final int? _nextOffset;
  int get nextOffset => _nextOffset ?? offset + entries.length;

  factory CoordinatorRankingPage.fromJson(Map<String, dynamic> json) {
    if (json['availableSeasons'] is! List ||
        json['entries'] is! List ||
        json['hasMore'] is! bool) {
      throw const FormatException('Respuesta del ranking incompleta.');
    }
    final generated = DateTime.tryParse(_text(json['generatedAt']));
    if (generated == null) {
      throw const FormatException('Fecha del ranking inválida.');
    }
    final entries = (json['entries'] as List)
        .map((item) => CoordinatorRankingEntry.fromJson(_object(item)))
        .toList(growable: false);
    final limit = _number(json['limit'], minimum: 1);
    final offset = _number(json['offset']);
    final total = _number(json['totalParticipants']);
    final currentId = _number(json['currentCoordinatorId'], minimum: 1);
    final mine = json['myEntry'] == null
        ? null
        : CoordinatorRankingEntry.fromJson(_object(json['myEntry']));
    if (limit > 100 ||
        entries.length > limit ||
        entries.length > total ||
        entries.map((e) => e.coordinatorId).toSet().length != entries.length ||
        entries.indexed.any((item) => item.$2.rank != offset + item.$1 + 1) ||
        (json['hasMore'] == true && entries.isEmpty) ||
        (mine != null && mine.coordinatorId != currentId)) {
      throw const FormatException('Página del ranking inválida.');
    }
    return CoordinatorRankingPage(
      season: _number(json['season'], minimum: 1),
      availableSeasons: List.unmodifiable(
        (json['availableSeasons'] as List).map(
          (year) => _number(year, minimum: 1),
        ),
      ),
      generatedAt: generated,
      rule: CoordinatorRankingRule.fromJson(_object(json['rule'])),
      totalParticipants: total,
      currentCoordinatorId: currentId,
      myEntry: mine,
      entries: List.unmodifiable(entries),
      limit: limit,
      offset: offset,
      hasMore: json['hasMore'] as bool,
      unattributedHitoCount: _number(json['unattributedHitoCount']),
    );
  }

  /// A ranking can change between requests. Never silently merge duplicates or
  /// renumber people: the UI must reload when a detected change invalidates it.
  CoordinatorRankingPage mergeNext(CoordinatorRankingPage next) {
    if (next.season != season ||
        next.currentCoordinatorId != currentCoordinatorId ||
        !rule.matches(next.rule) ||
        next.offset != nextOffset ||
        !hasMore) {
      throw const FormatException('Las páginas del ranking no coinciden.');
    }
    final ids = entries.map((entry) => entry.coordinatorId).toSet();
    if (next.totalParticipants != totalParticipants ||
        !_sameStanding(myEntry, next.myEntry) ||
        next.entries.any((entry) => ids.contains(entry.coordinatorId)) ||
        next.entries.indexed.any(
          (item) => item.$2.rank != next.offset + item.$1 + 1,
        )) {
      throw const FormatException(
        'El ranking se actualizó. Recarga para ver las posiciones actuales.',
      );
    }
    return CoordinatorRankingPage(
      season: season,
      availableSeasons: next.availableSeasons,
      generatedAt: next.generatedAt,
      rule: next.rule,
      totalParticipants: next.totalParticipants,
      currentCoordinatorId: currentCoordinatorId,
      myEntry: next.myEntry,
      entries: List.unmodifiable([...entries, ...next.entries]),
      limit: next.limit,
      offset: offset,
      hasMore: next.hasMore,
      unattributedHitoCount: next.unattributedHitoCount,
      nextOffset: next.nextOffset,
    );
  }

  static bool _sameStanding(
    CoordinatorRankingEntry? first,
    CoordinatorRankingEntry? second,
  ) => first == null || second == null
      ? first == null && second == null
      : first.coordinatorId == second.coordinatorId &&
            first.rank == second.rank &&
            first.bestTourId == second.bestTourId &&
            first.hitoCount == second.hitoCount &&
            first.photoCount == second.photoCount &&
            first.likeCount == second.likeCount &&
            first.score == second.score;
}

abstract class CoordinatorRankingRepository {
  Future<CoordinatorRankingPage> load({
    required int season,
    int limit = 50,
    int offset = 0,
  });
  Future<Uint8List?> loadPicture({
    required int season,
    required int coordinatorId,
    bool refresh = false,
  });
}

/// In-memory, season-scoped photos. An instance cannot cross a sign-in change,
/// even when legacy code replaces the token without changing its generation.
class HttpCoordinatorRankingRepository implements CoordinatorRankingRepository {
  HttpCoordinatorRankingRepository({LabApiClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? (() => LabApiClient());
  final LabApiClient Function() _clientFactory;
  final int _generation = LabSession.generation;
  String? _token;
  int? _coordinatorId;
  final _pictures = <(int, int), Future<Uint8List?>>{};

  Future<String> _authorize() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final expiry = DateTime.tryParse(prefs.getString('tokenExpiry') ?? '');
    int? id;
    try {
      final data = jsonDecode(prefs.getString('coordinatorData') ?? '');
      if (data is Map && data['coordinatorId'] is int) {
        id = data['coordinatorId'] as int;
      }
    } catch (_) {
      // A malformed session is denied, never inferred from a selected trip.
    }
    if (_generation != LabSession.generation ||
        token.isEmpty ||
        (_token != null && _token != token) ||
        id == null ||
        id <= 0 ||
        (_coordinatorId != null && _coordinatorId != id) ||
        prefs.getBool('isLoggedIn') != true ||
        prefs.getString('userRole') != 'coordinator' ||
        prefs.getString('labSessionRevision') != LabSession.revision ||
        expiry == null ||
        !expiry.isAfter(DateTime.now())) {
      _pictures.clear();
      throw const LabApiException(401);
    }
    _token = token;
    _coordinatorId = id;
    return token;
  }

  @override
  Future<CoordinatorRankingPage> load({
    required int season,
    int limit = 50,
    int offset = 0,
  }) async {
    if (season <= 0 || limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError('Consulta del ranking inválida.');
    }
    final token = await _authorize();
    final client = _clientFactory();
    try {
      final response = await client.get(
        LabApi.uri('/app/services/coordinator/ranking', {
          'season': '$season',
          'limit': '$limit',
          'offset': '$offset',
        }),
        headers: {'authorization': token, 'accept': 'application/json'},
      );
      await _authorize();
      final result = CoordinatorRankingPage.fromJson(
        _object(jsonDecode(utf8.decode(response.bodyBytes))),
      );
      if (result.season != season ||
          result.limit != limit ||
          result.offset != offset ||
          result.currentCoordinatorId != _coordinatorId) {
        throw const FormatException('Respuesta del ranking no coincide.');
      }
      return result;
    } finally {
      client.close();
    }
  }

  @override
  Future<Uint8List?> loadPicture({
    required int season,
    required int coordinatorId,
    bool refresh = false,
  }) async {
    if (season <= 0 || coordinatorId <= 0) {
      throw ArgumentError('Foto del ranking inválida.');
    }
    final token = await _authorize();
    final key = (season, coordinatorId);
    if (refresh) _pictures.remove(key);
    final pending = _pictures.putIfAbsent(
      key,
      () => _readPicture(season, coordinatorId, token),
    );
    try {
      final result = await pending;
      await _authorize();
      return result;
    } catch (_) {
      if (identical(_pictures[key], pending)) _pictures.remove(key);
      rethrow;
    }
  }

  Future<Uint8List?> _readPicture(int season, int id, String token) async {
    const maxBytes = 8 * 1024 * 1024;
    final client = _clientFactory();
    try {
      final response = await client.getStream(
        LabApi.uri('/app/services/coordinator/ranking/$id/picture', {
          'season': '$season',
        }),
        headers: {'authorization': token, 'accept': 'image/jpeg, image/png'},
      );
      if (response.statusCode == 204) {
        await response.stream.drain<void>();
        return null;
      }
      final type = response.headers['content-type']?.split(';').first.trim();
      if (!const {'image/jpeg', 'image/png'}.contains(type) ||
          (response.contentLength ?? 0) > maxBytes) {
        await response.stream.listen((_) {}).cancel();
        throw const FormatException('Foto del ranking inválida.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Foto del ranking demasiado grande.');
        }
        bytes.add(chunk);
      }
      final result = bytes.takeBytes();
      final jpeg =
          result.length >= 3 &&
          result[0] == 0xff &&
          result[1] == 0xd8 &&
          result[2] == 0xff;
      const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
      final png =
          result.length >= 8 &&
          Iterable.generate(8).every((i) => result[i] == pngSignature[i]);
      if ((type == 'image/jpeg' && !jpeg) || (type == 'image/png' && !png)) {
        throw const FormatException('Foto del ranking inválida.');
      }
      return result;
    } finally {
      client.close();
    }
  }
}
