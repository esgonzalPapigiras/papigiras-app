import 'dart:math' as math;

import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/binnacle.dart';

/// Counts from the existing read-only contracts, scoped to a single author.
/// Null means an exact total cannot be established; it must not display as 0.
class PiloCoordinatorActivity {
  const PiloCoordinatorActivity({
    required this.hitoCount,
    required this.photoCount,
  });

  const PiloCoordinatorActivity.unavailable()
    : hitoCount = null,
      photoCount = null;

  final int? hitoCount;
  final int? photoCount;
}

/// [hitos] must be the full successful getBinnacle([tourId]) response, not a
/// viewport/date subset. Reuse the map response so opening home does not repeat
/// its query. Only details authored by [coordinatorId] are requested.
///
/// The API has no lightweight photo-count endpoint. Details are therefore read
/// with bounded concurrency, counted and released; image bodies are not cached
/// here. Refresh the result after publishing/editing/deleting and tour changes.
/// [isCurrent] stops scheduling remaining detail reads when a refresh or a tour
/// change makes this computation obsolete. Requests already running may finish.
Future<PiloCoordinatorActivity> loadPiloCoordinatorActivity({
  required int tourId,
  required int coordinatorId,
  required Iterable<ConsolidatedTourSalesDTO> hitos,
  required Future<DetailHitoList> Function(String hitoId, String tourId)
  loadDetail,
  int maxConcurrent = 2,
  bool Function()? isCurrent,
}) async {
  if (tourId <= 0 || coordinatorId <= 0 || maxConcurrent <= 0) {
    throw ArgumentError(
      'La gira, el coordinador y la concurrencia deben ser válidos.',
    );
  }

  final authors = <int, int>{};
  for (final hito in hitos) {
    final id = hito.binnacleDetailId;
    final author = hito.author?.coordinatorId;
    // A legacy/malformed author cannot safely be attributed to the session.
    // canModify is a permission, never proof of authorship.
    if (id <= 0 || author == null || author <= 0) {
      return const PiloCoordinatorActivity.unavailable();
    }
    final previous = authors[id];
    if (previous != null && previous != author) {
      return const PiloCoordinatorActivity.unavailable();
    }
    authors[id] = author;
  }

  final ownIds = authors.entries
      .where((entry) => entry.value == coordinatorId)
      .map((entry) => entry.key)
      .toList(growable: false);
  var next = 0;
  var photos = 0;
  var photoError = false;
  Future<void> countNext() async {
    while (next < ownIds.length && (isCurrent?.call() ?? true)) {
      final id = ownIds[next++];
      try {
        final detail = await loadDetail(id.toString(), tourId.toString());
        // Missing archived image objects still have a recorded photo reference.
        photos += detail.images.length + math.max(0, detail.missingImageCount);
      } catch (_) {
        photoError = true;
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < math.min(maxConcurrent, ownIds.length); i++)
      countNext(),
  ]);
  if (!(isCurrent?.call() ?? true)) {
    return const PiloCoordinatorActivity.unavailable();
  }
  return PiloCoordinatorActivity(
    hitoCount: ownIds.length,
    photoCount: photoError ? null : photos,
  );
}
