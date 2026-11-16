import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/lab/map_basemap.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as renderer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const version = '20261101_080013_pt';
  final metadata = {
    'minzoom': 0,
    'maxzoom': 14,
    'tiles': ['https://tiles.openfreemap.org/planet/$version/{z}/{x}/{y}.pbf'],
  };

  test('only reviewed OFM metadata and bounded tile paths are allowed', () {
    for (final url in [
      LabMapTiles.openMapMetadata,
      LabMapTiles.vectorTile(version, 13, 2488, 4904).toString(),
      LabMapTiles.vectorTile(version, 0, 0, 0).toString(),
    ]) {
      expect(LabMapTiles.permits('GET', Uri.parse(url)), isTrue);
    }
    for (final url in [
      'https://tiles.openfreemap.org.evil.invalid/planet',
      'http://tiles.openfreemap.org/planet',
      'https://tiles.openfreemap.org:444/planet',
      'https://user:fictional@tiles.openfreemap.org/planet',
      'https://tiles.openfreemap.org/planet?key=fictional',
      'https://tiles.openfreemap.org/planet#fragment',
      'https://tiles.openfreemap.org/planet/',
      'https://tiles.openfreemap.org/styles/positron',
      'https://tiles.openfreemap.org/fonts/Roboto/0-255.pbf',
      'https://tiles.openfreemap.org/sprites/ofm_f384/ofm.png',
      'https://tiles.openfreemap.org/planet/latest/13/2488/4904.pbf',
      'https://tiles.openfreemap.org/planet/$version/15/2488/4904.pbf',
      'https://tiles.openfreemap.org/planet/$version/0/1/0.pbf',
      'https://tiles.openfreemap.org/planet/$version/13/-1/4904.pbf',
      'https://tiles.openfreemap.org/natural_earth/ne2sr/7/1/1.png',
      'https://tiles.openfreemap.org/natural_earth/ne2sr/0/1/0.png',
    ]) {
      expect(LabMapTiles.permits('GET', Uri.parse(url)), isFalse, reason: url);
    }
    for (final method in ['POST', 'PUT', 'DELETE', 'HEAD', 'get']) {
      expect(
        LabMapTiles.permits(method, Uri.parse(LabMapTiles.openMapMetadata)),
        isFalse,
      );
    }
    for (final template in LabMapTiles.templates) {
      final uri = Uri.parse(
        template
            .replaceAll('{z}', '13')
            .replaceAll('{x}', '2488')
            .replaceAll('{y}', '4904'),
      );
      expect(LabMapTiles.permits('GET', uri), isTrue);
    }
  });

  test('remote TileJSON cannot change origin, path family, query or zoom', () {
    expect(LabMapTiles.openMapVersion(metadata), version);
    for (final bad in [
      {...metadata, 'maxzoom': 22},
      {...metadata, 'minzoom': -1},
      {...metadata, 'tiles': []},
      {
        ...metadata,
        'tiles': ['https://example.invalid/{z}/{x}/{y}.pbf'],
      },
      {
        ...metadata,
        'tiles': [metadata['tiles'], metadata['tiles']],
      },
      {
        ...metadata,
        'tiles': [
          'https://tiles.openfreemap.org/planet/$version/{z}/{x}/{y}.pbf?key=fictional',
        ],
      },
    ]) {
      expect(() => LabMapTiles.openMapVersion(bad), throwsFormatException);
    }
  });

  test('transport strips body, session headers and redirects', () async {
    var calls = 0;
    final client = LabPublicMapClient(
      transport: MockClient((request) async {
        calls++;
        expect(request.method, 'GET');
        expect(request.headers.keys.map((key) => key.toLowerCase()).toSet(), {
          'user-agent',
        });
        expect(request.headers['user-agent'], contains('Papigiras-LAB'));
        expect(request.body, isEmpty);
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 0);
        return http.Response(
          '',
          302,
          headers: {'location': 'https://example.invalid/private'},
        );
      }),
    );
    addTearDown(client.close);
    final request = http.Request('GET', Uri.parse(LabMapTiles.openMapMetadata))
      ..headers['Authorization'] = 'fictional-session'
      ..headers['Cookie'] = 'fictional-cookie'
      ..body = 'not forwarded';
    expect(
      (await http.Response.fromStream(await client.send(request))).statusCode,
      302,
    );
    await expectLater(
      client.post(Uri.parse(LabMapTiles.openMapMetadata)),
      throwsA(isA<SocketException>()),
    );
    expect(calls, 1);
  });

  test(
    'metadata payload is bounded and client remains usable after rejection',
    () async {
      var oversized = true;
      final client = LabPublicMapClient(
        transport: MockClient(
          (_) async =>
              http.Response(oversized ? 'x' * (257 * 1024) : '{}', 200),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.get(Uri.parse(LabMapTiles.openMapMetadata)),
        throwsFormatException,
      );
      oversized = false;
      expect(
        (await client.get(Uri.parse(LabMapTiles.openMapMetadata))).body,
        '{}',
      );
    },
  );

  test('at most four map downloads run concurrently', () async {
    final gate = Completer<void>();
    var calls = 0;
    final client = LabPublicMapClient(
      transport: MockClient((_) async {
        calls++;
        await gate.future;
        return http.Response('ok', 200);
      }),
    );
    addTearDown(client.close);
    final requests = List.generate(
      5,
      (_) => client.get(Uri.parse(LabMapTiles.openMapMetadata)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 4);
    gate.complete();
    await Future.wait(requests);
    expect(calls, 5);
  });

  test(
    'custom vector provider uses bounded transport and rejects invalid tiles',
    () async {
      var calls = 0;
      final client = LabPublicMapClient(
        transport: MockClient((request) async {
          calls++;
          expect(request.url, LabMapTiles.vectorTile(version, 13, 2488, 4904));
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      addTearDown(client.close);
      final provider = LabOpenMapTileProvider.vector(
        version: version,
        client: client,
      );
      expect(await provider.provide(vector.TileIdentity(13, 2488, 4904)), [
        1,
        2,
        3,
      ]);
      await expectLater(
        provider.provide(vector.TileIdentity(15, 1, 1)),
        throwsA(isA<vector.ProviderException>()),
      );
      await expectLater(
        provider.provide(vector.TileIdentity(0, 1, 0)),
        throwsA(isA<vector.ProviderException>()),
      );
      expect(calls, 1);
    },
  );

  test(
    'local map styles and sprites parse without any network resource URL',
    () async {
      for (final name in ['positron', 'pilo']) {
        final raw = await rootBundle.loadString('assets/maps/$name.json');
        expect(raw, isNot(contains('https://')));
        expect(raw, isNot(contains('http://')));
        final style = jsonDecode(raw) as Map<String, dynamic>;
        expect(style.containsKey('glyphs'), isFalse);
        expect(style.containsKey('sprite'), isFalse);
        final theme = renderer.ThemeReader().read(style);
        expect(theme.tileSources.toSet(), {'openmaptiles'});
      }
      final sprites = renderer.SpriteIndexReader().read(
        jsonDecode(await rootBundle.loadString('assets/maps/ofm-sprites.json'))
            as Map<String, dynamic>,
      );
      expect(sprites.spriteByName, isNotEmpty);
      expect(
        (await rootBundle.load('assets/maps/ofm-sprites.png')).lengthInBytes,
        greaterThan(0),
      );
    },
  );
}
