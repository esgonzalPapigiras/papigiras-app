import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';

ConsolidatedTourSalesDTO hito(
  int id, {
  String date = '2026-11-03',
  String time = '09:00',
  String latitude = '-33.45',
  String longitude = '-70.66',
}) => ConsolidatedTourSalesDTO(
  binnacleDetailId: id,
  binnacleTitulo: 'Hito ficticio $id',
  binnacleDescripcion: 'Descripción LAB',
  binnacleUbicacion: 'Destino ficticio',
  binnacleNotaCierre: '',
  binnacleLatitud: latitude,
  binnacleLongitud: longitude,
  binnacleHora: time,
  binnacleFecha: date,
  author: null,
  canModify: false,
);

void main() {
  group('orden temporal y selección', () {
    test('ordena ISO y día/mes/año con horas, no IDs ni texto', () {
      final source = [
        hito(2, date: '2026-11-03', time: '15:30'),
        hito(900, date: '31/10/2026', time: '21:00'),
        hito(10, date: '03/11/2026', time: '09:15'),
      ];
      final data = TripMapData.from(source);
      expect(data.entries.map((e) => e.id), [900, 10, 2]);
      expect(data.entries.map((e) => e.ordinal), [1, 2, 3]);
      expect(data.latestId, 2);
      expect(data.latestMappedId, 2);
      expect(source.first.binnacleDetailId, 2);
    });

    test('desempata por ID, conservando selección tras insertar hitos', () {
      final before = TripMapData.from([hito(7), hito(2)]);
      expect(before.entries.map((e) => e.id), [2, 7]);
      expect(before.latestId, 7);
      final after = TripMapData.from([
        hito(8, time: '12:00'),
        hito(7),
        hito(2),
        hito(1, date: '2026-11-02'),
      ]);
      expect(after.entryById(7)!.ordinal, 3);
      expect(after.preferredSelectionId(7), 7);
      expect(after.preferredSelectionId(99), 8);
      expect(after.entryById(99), isNull);
    });

    test('fecha imposible no se normaliza ni se vuelve el último por ID', () {
      final data = TripMapData.from([
        hito(999, date: '2026-02-31'),
        hito(2),
        hito(998, date: 'sin fecha'),
      ]);
      expect(data.unknownDateCount, 2);
      expect(data.entryById(999)!.unknownDate, isTrue);
      expect(data.latestId, 2);
      expect(data.entries.last.id, 2);
      final unknown = TripMapData.from([hito(99, date: '')]);
      expect(unknown.latestId, isNull);
      expect(unknown.latestMappedId, isNull);
      expect(unknown.preferredSelectionId(null), 99);
    });

    test(
      'conserva hito más reciente sin ubicación y selecciona uno ubicable',
      () {
        final data = TripMapData.from([
          hito(1),
          hito(2, time: '16:00', latitude: ''),
        ]);
        expect(data.entries.length, 2);
        expect(data.mappedEntries.map((e) => e.id), [1]);
        expect(data.unmappedCount, 1);
        expect(data.latestId, 2);
        expect(data.latestMappedId, 1);
        expect(data.preferredSelectionId(null), 1);
        expect(data.preferredSelectionId(2), 2);
      },
    );

    test('vacío y registros sin ubicación no inventan un centro', () {
      final empty = TripMapData.from([]);
      expect(empty.preferredSelectionId(null), isNull);
      expect(empty.latestId, isNull);
      expect(empty.mappedEntries, isEmpty);
      final missing = TripMapData.from([hito(1, latitude: '')]);
      expect(missing.mappedEntries, isEmpty);
      expect(missing.preferredSelectionId(null), 1);
      expect(() => missing.entries.clear(), throwsUnsupportedError);
    });
  });

  group('parseo estricto', () {
    test(
      'acepta año bisiesto, fecha ISO, hora separada y timestamp con offset',
      () {
        expect(
          parseTripMapDate('29/02/2024', '9:05'),
          DateTime.utc(2024, 2, 29, 9, 5),
        );
        expect(parseTripMapDate('2026-11-03', ''), DateTime.utc(2026, 11, 3));
        expect(
          parseTripMapDate('2026-11-03T12:30:10.123Z', ''),
          DateTime.utc(2026, 11, 3, 12, 30, 10, 123),
        );
        expect(
          parseTripMapDate('2026-11-03T09:30:00-03:00', ''),
          DateTime.utc(2026, 11, 3, 12, 30),
        );
        expect(
          parseTripMapDate('2026-11-03T00:00:00Z', '15:40'),
          DateTime.utc(2026, 11, 3, 15, 40),
        );
      },
    );

    test('rechaza fechas y horas fuera de rango', () {
      for (final date in [
        '29/02/2025',
        '31/04/2026',
        '2026-00-01',
        '2026-13-01',
        '2026-11-00',
        '0000-01-01',
      ]) {
        expect(parseTripMapDate(date, '09:00'), isNull, reason: date);
      }
      for (final time in ['24:00', '12:60', '12:30:60', 'texto']) {
        expect(parseTripMapDate('2026-11-03', time), isNull, reason: time);
      }
      expect(parseTripMapDate('2026-11-03T24:00:00Z', ''), isNull);
      expect(parseTripMapDate('2026-11-03T12:00:00+03:70', ''), isNull);
    });

    test('valida coordenadas finitas, rangos y espacios sin corregirlas', () {
      final point = parseTripMapPosition(' -33.4500 ', '-70.6600 ');
      expect(point!.latitude, -33.45);
      expect(point.longitude, -70.66);
      expect(parseTripMapPosition('0', '0'), isNotNull);
      expect(parseTripMapPosition('90', '-180'), isNotNull);
      for (final latitude in [
        '',
        'NaN',
        'Infinity',
        '-Infinity',
        '91',
        '-91',
        'texto',
      ]) {
        expect(parseTripMapPosition(latitude, '0'), isNull, reason: latitude);
      }
      for (final longitude in ['181', '-181', 'NaN', 'Infinity', 'texto']) {
        expect(parseTripMapPosition('0', longitude), isNull, reason: longitude);
      }
    });
  });

  group('agrupación de puntos en pantalla', () {
    test('coincidentes se agrupan sin desplazar coordenadas reales', () {
      final data = TripMapData.from([hito(2, time: '12:00'), hito(1)]);
      final groups = groupTripMapEntries(data.mappedEntries, {
        1: const math.Point(100.0, 100.0),
        2: const math.Point(100.0, 100.0),
      });
      expect(groups.length, 1);
      expect(groups.single.isCluster, isTrue);
      expect(groups.single.entries.map((e) => e.id), [1, 2]);
      expect(groups.single.anchor.id, 2);
      expect(groups.single.position, same(data.entryById(2)!.position));
    });

    test('el zoom separa puntos y no depende del orden del array', () {
      final data = TripMapData.from([hito(1), hito(2), hito(3)]);
      final near = groupTripMapEntries(data.mappedEntries.reversed, {
        1: const math.Point(10.0, 10.0),
        2: const math.Point(45.0, 10.0),
        3: const math.Point(150.0, 10.0),
      });
      expect(near.map((g) => g.count), [2, 1]);
      final far = groupTripMapEntries(data.mappedEntries, {
        1: const math.Point(10.0, 10.0),
        2: const math.Point(80.0, 10.0),
        3: const math.Point(180.0, 10.0),
      });
      expect(far.map((g) => g.count), [1, 1, 1]);
    });

    test(
      'no pierde hitos al formar un grupo transitivo y omite proyección inválida',
      () {
        final data = TripMapData.from([hito(1), hito(2), hito(3), hito(4)]);
        final groups = groupTripMapEntries(data.entries, {
          1: const math.Point(0.0, 0.0),
          2: const math.Point(40.0, 0.0),
          3: const math.Point(80.0, 0.0),
          4: const math.Point(double.nan, 0.0),
        });
        expect(groups.single.entries.map((e) => e.id), [1, 2, 3]);
        expect(
          () => groupTripMapEntries(data.entries, {}, minSeparation: -1),
          throwsArgumentError,
        );
      },
    );
  });
}
