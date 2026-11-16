import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/maps/trip_map_nearby_navigation.dart';

ConsolidatedTourSalesDTO row(int id, String lat, String lon) =>
    ConsolidatedTourSalesDTO.fromJson({
      'binnacleDetailId': id,
      'binnacleTitulo': 'Hito ficticio $id',
      'binnacleLatitud': lat,
      'binnacleLongitud': lon,
      'binnacleFecha': '2026-11-${id == 1 ? 12 : 11}',
      'binnacleHora': '10:00',
    });

void main() {
  late TripMapNearbyNavigation walk;
  late TripMapData data;
  setUp(() {
    data = TripMapData.from([
      row(1, '-33.45', '-70.65'),
      row(2, '-33.451', '-70.651'),
      row(3, '-33.452', '-70.652'),
      row(4, '-33.45001', '-70.65001'), // closest, but outside the viewport
      row(5, 'invalid', '-70.65'),
    ]);
    walk = TripMapNearbyNavigation()..sync(data, 1);
    walk.updateViewport(
      visibleIds: [1, 2, 3, 5],
      center: const LatLng(-33.45, -70.65),
    );
  });
  test(
    'nearest visible coordinate, not date, ID order or invisible neighbor',
    () {
      expect(walk.next(), 2);
      walk.sync(data, 2);
      expect(walk.next(), 3);
      expect(walk.next(), isNull);
    },
  );
  test(
    'programmatic camera move retains path and back retraces without loops',
    () {
      walk.next();
      walk.updateViewport(
        visibleIds: [1, 2, 3],
        center: data.entryById(2)!.position!,
      );
      expect(walk.next(), 3);
      expect(walk.previous(), 2);
      expect(walk.previous(), 1);
      expect(walk.previous(), isNull);
      expect(walk.next(), 2);
    },
  );
  test(
    'manual pan begins a fresh neighborhood; outside selection uses map center',
    () {
      walk.next();
      walk.updateViewport(
        visibleIds: [1, 3],
        center: data.entryById(3)!.position!,
        userMoved: true,
      );
      expect(walk.previous(), isNull);
      expect(walk.next(), 3);
    },
  );
  test('offscreen historical entries cannot be selected', () {
    walk.next();
    walk.next();
    walk.updateViewport(visibleIds: [3], center: data.entryById(3)!.position!);
    expect(walk.previous(), isNull);
    expect(walk.next(), isNull);
  });
  test(
    'explicit pin selection resets history and chooses its closest neighbor',
    () {
      walk.next();
      walk.sync(data, 3);
      expect(walk.previous(), isNull);
      expect(walk.next(), 2);
    },
  );
  test('coincident pins keep stable identities and visit each once', () {
    final coincident = TripMapData.from([
      row(3, '0', '0'),
      row(1, '0', '0'),
      row(2, '0', '0'),
    ]);
    walk.sync(coincident, 3);
    walk.updateViewport(visibleIds: [3, 2, 1], center: const LatLng(0, 0));
    expect(walk.next(), 1);
    expect(walk.next(), 2);
    expect(walk.next(), isNull);
  });
  test('empty, invalid and removed points never produce a target', () {
    walk.updateViewport(visibleIds: [5, 999], center: const LatLng(0, 0));
    expect(walk.next(), isNull);
    walk.sync(TripMapData.from([]), null);
    expect(walk.previous(), isNull);
    expect(walk.next(), isNull);
  });
}
