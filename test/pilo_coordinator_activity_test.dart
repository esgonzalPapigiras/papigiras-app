import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_coordinator_activity.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/binnacle.dart';

ConsolidatedTourSalesDTO hito(int id, int? author, {bool canModify = true}) =>
    ConsolidatedTourSalesDTO(
      binnacleDetailId: id,
      binnacleTitulo: '',
      binnacleDescripcion: '',
      binnacleUbicacion: '',
      binnacleNotaCierre: '',
      binnacleLatitud: '',
      binnacleLongitud: '',
      binnacleHora: '',
      binnacleFecha: '',
      canModify: canModify,
      author: author == null
          ? null
          : HitoAuthor(coordinatorId: author, name: 'Ejemplo', lastname: 'LAB'),
    );

void main() {
  test(
    'counts the current author, deduplicates IDs and passes actual tour ID',
    () async {
      final requested = <(String, String)>[];
      final result = await loadPiloCoordinatorActivity(
        tourId: 910001,
        coordinatorId: 910001,
        hitos: [
          hito(910101, 910001),
          hito(910102, 910002),
          hito(910101, 910001),
          hito(910103, 910001, canModify: false),
        ],
        loadDetail: (id, tour) async {
          requested.add((id, tour));
          return DetailHitoList(
            images: id == '910101' ? ['fixture-a', 'fixture-b'] : [],
            missingImageCount: id == '910103' ? 1 : 0,
          );
        },
      );
      expect(result.hitoCount, 2);
      expect(result.photoCount, 3);
      expect(
        requested,
        unorderedEquals([('910101', '910001'), ('910103', '910001')]),
      );
    },
  );

  test(
    'a valid empty contribution is zero and does not fetch other authors',
    () async {
      for (final rows in [
        <ConsolidatedTourSalesDTO>[],
        [hito(910101, 910002)],
      ]) {
        final result = await loadPiloCoordinatorActivity(
          tourId: 910001,
          coordinatorId: 910001,
          hitos: rows,
          loadDetail: (_, _) =>
              throw StateError('No detail should be requested'),
        );
        expect(result.hitoCount, 0);
        expect(result.photoCount, 0);
      }
    },
  );

  test(
    'unknown or conflicting authors do not fabricate exact totals',
    () async {
      for (final rows in [
        [hito(910101, null)],
        [hito(910101, 0)],
        [hito(910101, 910001), hito(910102, null)],
        [hito(910101, 910001), hito(910101, 910002)],
        [hito(0, 910001)],
      ]) {
        var calls = 0;
        final result = await loadPiloCoordinatorActivity(
          tourId: 910001,
          coordinatorId: 910001,
          hitos: rows,
          loadDetail: (_, _) async {
            calls++;
            return DetailHitoList();
          },
        );
        expect(result.hitoCount, isNull);
        expect(result.photoCount, isNull);
        expect(calls, 0);
      }
    },
  );

  test(
    'a failed photo query preserves exact hito count but not partial photo total',
    () async {
      final result = await loadPiloCoordinatorActivity(
        tourId: 910001,
        coordinatorId: 910001,
        hitos: [hito(910101, 910001), hito(910102, 910001)],
        loadDetail: (id, _) async {
          if (id == '910102') throw StateError('Synthetic unavailable detail');
          return DetailHitoList(images: ['fixture']);
        },
      );
      expect(result.hitoCount, 2);
      expect(result.photoCount, isNull);
    },
  );

  test(
    'photo requests are bounded instead of downloading all details together',
    () async {
      final releases = <Completer<void>>[];
      var running = 0;
      var peak = 0;
      final future = loadPiloCoordinatorActivity(
        tourId: 910001,
        coordinatorId: 910001,
        hitos: [for (var i = 0; i < 5; i++) hito(910101 + i, 910001)],
        loadDetail: (_, _) async {
          running++;
          if (running > peak) peak = running;
          final release = Completer<void>();
          releases.add(release);
          await release.future;
          running--;
          return DetailHitoList(images: ['fixture']);
        },
      );
      expect(releases.length, 2);
      for (var i = 0; i < 5; i++) {
        releases[i].complete();
        await Future<void>.delayed(Duration.zero);
      }
      final result = await future;
      expect(peak, 2);
      expect(result.hitoCount, 5);
      expect(result.photoCount, 5);
    },
  );

  test('an obsolete home load stops scheduling further details', () async {
    var current = true;
    var calls = 0;
    final release = Completer<void>();
    final future = loadPiloCoordinatorActivity(
      tourId: 910001,
      coordinatorId: 910001,
      hitos: [for (var i = 0; i < 5; i++) hito(910101 + i, 910001)],
      isCurrent: () => current,
      loadDetail: (_, _) async {
        calls++;
        await release.future;
        return DetailHitoList(images: ['fixture']);
      },
    );
    expect(calls, 2);
    current = false;
    release.complete();
    final result = await future;
    expect(calls, 2);
    expect(result.hitoCount, isNull);
    expect(result.photoCount, isNull);
  });

  test(
    'a refresh recalculates deletions and added photos from the source',
    () async {
      final rows = [hito(910101, 910001), hito(910102, 910001)];
      var photoCount = 1;
      Future<PiloCoordinatorActivity> load() => loadPiloCoordinatorActivity(
        tourId: 910001,
        coordinatorId: 910001,
        hitos: rows,
        loadDetail: (_, _) async =>
            DetailHitoList(images: List.filled(photoCount, 'fixture')),
      );
      expect((await load()).photoCount, 2);
      rows.removeLast();
      photoCount = 3;
      final updated = await load();
      expect(updated.hitoCount, 1);
      expect(updated.photoCount, 3);
    },
  );
}
