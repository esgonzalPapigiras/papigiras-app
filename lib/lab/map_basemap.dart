import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vector;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as renderer;
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';

/// A reviewed vector basemap inside the existing FlutterMap camera.
/// Styles and sprites are local; only allowlisted public map tiles leave LAB.
class LabMapBasemap extends StatefulWidget {
  const LabMapBasemap({super.key});

  static final _sharedLoads = <bool, Future<_LoadedMap>>{};
  static final LabPublicMapClient _client = LabPublicMapClient();

  static Future<_LoadedMap> _load(bool pilo) async {
    try {
      final values = await Future.wait<Object>([
        rootBundle.loadString(
          pilo ? 'assets/maps/pilo.json' : 'assets/maps/positron.json',
        ),
        rootBundle.loadString('assets/maps/ofm-sprites.json'),
        rootBundle.load('assets/maps/ofm-sprites.png'),
        LabMapTiles.readOpenMapVersion(_client),
      ]);
      final version = values[3] as String;
      final health = ValueNotifier<bool>(false);
      final bytes = values[2] as ByteData;
      final atlas = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      final style = vector.Style(
        name: pilo ? 'Papigiras Pilo' : 'Papigiras Positron',
        theme: renderer.ThemeReader().read(
          jsonDecode(values[0] as String) as Map<String, dynamic>,
        ),
        sprites: vector.SpriteStyle(
          atlasProvider: () async => atlas,
          index: renderer.SpriteIndexReader().read(
            jsonDecode(values[1] as String) as Map<String, dynamic>,
          ),
        ),
        providers: vector.TileProviders({
          'openmaptiles': LabOpenMapTileProvider.vector(
            version: version,
            client: _client,
            unavailable: health,
          ),
        }),
      );
      return _LoadedMap(style, health);
    } catch (_) {
      _sharedLoads.remove(pilo);
      rethrow;
    }
  }

  static Future<_LoadedMap> _shared(bool pilo) =>
      _sharedLoads.putIfAbsent(pilo, () => _load(pilo));

  @override
  State<LabMapBasemap> createState() => _LabMapBasemapState();
}

class _LabMapBasemapState extends State<LabMapBasemap> {
  Future<_LoadedMap>? _future;

  bool? _pilo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pilo = PiloFamilyTheme.isActive(context);
    if (_pilo == pilo) return;
    _pilo = pilo;
    if (!LabMapTiles.usesTestProvider) _future = LabMapBasemap._shared(pilo);
  }

  void _retry() {
    final pilo = _pilo ?? false;
    LabMapBasemap._sharedLoads.remove(pilo);
    setState(() => _future = LabMapBasemap._shared(pilo));
  }

  @override
  Widget build(BuildContext context) {
    if (LabMapTiles.usesTestProvider) {
      return TileLayer(
        urlTemplate: LabMapTiles.satellite,
        tileProvider: LabMapTiles.provider(),
      );
    }
    return FutureBuilder<_LoadedMap>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _MapNotice(onRetry: _retry);
        if (!snapshot.hasData) {
          return IgnorePointer(
            child: Center(
              child: Semantics(
                label: 'Cargando mapa de calles',
                child: const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
        final map = snapshot.requireData;
        return Stack(
          children: [
            vector.VectorTileLayer(
              key: ValueKey(map.style),
              theme: map.style.theme,
              sprites: map.style.sprites,
              tileProviders: map.style.providers,
              tileOffset: vector.TileOffset.mapbox,
              concurrency: 2,
              // Raw vector cache is measured in bytes; parsed cache below counts tiles.
              memoryTileCacheMaxSize: 24 * 1024 * 1024,
              memoryTileDataCacheMaxSize: 12,
              fileCacheMaximumSizeInBytes: 32 * 1024 * 1024,
              maximumZoom: 19,
            ),
            ValueListenableBuilder<bool>(
              valueListenable: map.unavailable,
              builder: (context, unavailable, _) => unavailable
                  ? _MapNotice(onRetry: _retry)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _MapNotice extends StatelessWidget {
  const _MapNotice({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 18,
                    color: Colors.black54,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Mapa no disponible',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LoadedMap {
  const _LoadedMap(this.style, this.unavailable);
  final vector.Style style;
  final ValueNotifier<bool> unavailable;
}

/// Avoid the package's general HTTP provider: each request passes through the
/// same bounded, credential-free map capability as the TileJSON request.
class LabOpenMapTileProvider extends vector.VectorTileProvider {
  LabOpenMapTileProvider.vector({
    required String version,
    required LabPublicMapClient client,
    ValueNotifier<bool>? unavailable,
  }) : _version = version,
       _client = client,
       _unavailable = unavailable,
       type = vector.TileProviderType.vector;

  final String _version;
  final LabPublicMapClient _client;
  final ValueNotifier<bool>? _unavailable;

  @override
  final vector.TileProviderType type;

  @override
  int get minimumZoom => 0;

  @override
  int get maximumZoom => 14;

  @override
  Future<Uint8List> provide(vector.TileIdentity tile) async {
    if (!tile.isValid() || tile.z > maximumZoom) {
      throw vector.ProviderException(
        message: 'Tesela fuera de los límites permitidos',
        statusCode: 400,
        retryable: vector.Retryable.none,
      );
    }
    try {
      final uri = LabMapTiles.vectorTile(_version, tile.z, tile.x, tile.y);
      final response = await _client.get(uri);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw vector.ProviderException(
          message: 'No se pudo cargar la cartografía',
          statusCode: response.statusCode,
          retryable: vector.Retryable.none,
        );
      }
      _unavailable?.value = false;
      return response.bodyBytes;
    } catch (_) {
      _unavailable?.value = true;
      rethrow;
    }
  }
}
