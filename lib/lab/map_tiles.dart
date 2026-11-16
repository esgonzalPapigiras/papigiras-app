import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Public cartography explicitly authorized for the independent LAB.
/// Production credentials and user headers never cross this capability.
abstract final class LabMapTiles {
  static const satellite =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const labels =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';
  static const navigation =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Navigation_Charts/MapServer/tile/{z}/{y}/{x}';
  static const transportation =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}';
  static const templates = [satellite, labels, navigation, transportation];

  static const openMapHost = 'tiles.openfreemap.org';
  static const openMapMetadata = 'https://tiles.openfreemap.org/planet';
  static const attributionDetails =
      '''Cartografía: OpenFreeMap (estilo Positron)
OpenFreeMap: https://openfreemap.org/
© OpenMapTiles: https://www.openmaptiles.org/
Datos OpenStreetMap bajo ODbL 1.0: https://opendatacommons.org/licenses/odbl/1-0/
Datos © OpenStreetMap contributors: https://www.openstreetmap.org/copyright

Diseño Positron derivado de CartoDB Basemaps (Stamen y Paul Norman para CartoDB),
CC BY 3.0; Positron GL/OpenMapTiles, BSD-3-Clause y CC BY 4.0.
Adaptación LAB: fuentes locales Roboto; estilos y sprites incluidos en la app.

El fondo utiliza información pública de OpenStreetMap. La posición de los hitos
proviene de la bitácora de esta gira y no indica seguimiento GPS en vivo.
Estas direcciones son referencias; este diálogo no abre conexiones externas.''';

  @visibleForTesting
  static TileProvider Function()? testProvider;

  static bool get usesTestProvider => testProvider != null;

  static TileProvider provider() =>
      testProvider?.call() ??
      NetworkTileProvider(httpClient: LabPublicMapClient());

  static bool _xyz(int z, int x, int y, int maximumZoom) =>
      z >= 0 &&
      z <= maximumZoom &&
      x >= 0 &&
      y >= 0 &&
      x < (1 << z) &&
      y < (1 << z);

  static bool permits(String method, Uri uri) {
    if (method != 'GET' ||
        uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.contains('%')) {
      return false;
    }
    if (uri.host == openMapHost) {
      if (uri.path == '/planet') return true;
      final vector = RegExp(
        r'^/planet/\d{8}_\d{6}_pt/(\d{1,2})/(\d{1,5})/(\d{1,5})\.pbf$',
      ).firstMatch(uri.path);
      if (vector != null) {
        return _xyz(
          int.parse(vector[1]!),
          int.parse(vector[2]!),
          int.parse(vector[3]!),
          14,
        );
      }
      return false;
    }
    for (final template in templates) {
      final base = Uri.parse(template.split('/tile/').first);
      if (uri.host != base.host || !uri.path.startsWith('${base.path}/tile/')) {
        continue;
      }
      final suffix = uri.path.substring('${base.path}/tile/'.length);
      if (!RegExp(r'^\d{1,2}/\d{1,8}/\d{1,8}$').hasMatch(suffix)) return false;
      final xyz = suffix.split('/').map(int.parse).toList();
      return _xyz(xyz[0], xyz[1], xyz[2], 22);
    }
    return false;
  }

  /// Only the reviewed host, source family and zoom contract are accepted.
  /// Remote TileJSON cannot introduce another endpoint or credential.
  static String openMapVersion(Map<String, dynamic> metadata) {
    final tiles = metadata['tiles'];
    if (metadata['minzoom'] != 0 ||
        metadata['maxzoom'] != 14 ||
        tiles is! List ||
        tiles.length != 1 ||
        tiles.single is! String) {
      throw const FormatException('Fuente cartográfica no reconocida');
    }
    final match = RegExp(
      r'^https://tiles\.openfreemap\.org/planet/(\d{8}_\d{6}_pt)/\{z\}/\{x\}/\{y\}\.pbf$',
    ).firstMatch(tiles.single as String);
    if (match == null) {
      throw const FormatException('Destino cartográfico no autorizado');
    }
    return match[1]!;
  }

  static Future<String> readOpenMapVersion(LabPublicMapClient client) async {
    final response = await client.get(Uri.parse(openMapMetadata));
    if (response.statusCode != 200) {
      throw const FormatException('No se pudo obtener la base cartográfica');
    }
    final metadata = jsonDecode(utf8.decode(response.bodyBytes));
    if (metadata is! Map<String, dynamic>) {
      throw const FormatException('Respuesta cartográfica no reconocida');
    }
    return openMapVersion(metadata);
  }

  static Uri vectorTile(String version, int z, int x, int y) {
    if (!RegExp(r'^\d{8}_\d{6}_pt$').hasMatch(version) || !_xyz(z, x, y, 14)) {
      throw ArgumentError('Tesela vectorial inválida');
    }
    return Uri(
      scheme: 'https',
      host: openMapHost,
      path: '/planet/$version/$z/$x/$y.pbf',
    );
  }
}

class _PublicTileTransport extends HttpOverrides {}

/// The only external transport used by maps. GET-only, four concurrent
/// responses, bounded payloads, no cookies/tokens/body/redirect forwarding.
class LabPublicMapClient extends http.BaseClient {
  final http.Client _transport;
  final Queue<Completer<void>> _waiting = Queue();
  int _active = 0;
  bool _closed = false;

  LabPublicMapClient({http.Client? transport})
    : _transport =
          transport ?? IOClient(_PublicTileTransport().createHttpClient(null));

  Future<void> _acquire() async {
    if (_closed) throw const SocketException('Cliente cartográfico cerrado');
    if (_active < 4) {
      _active++;
    } else {
      final waiter = Completer<void>();
      _waiting.add(waiter);
      await waiter.future;
    }
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _active--;
    }
  }

  Stream<List<int>> _body(Stream<List<int>> body, int maximumBytes) async* {
    var bytes = 0;
    try {
      await for (final chunk in body.timeout(const Duration(seconds: 20))) {
        bytes += chunk.length;
        if (bytes > maximumBytes) {
          throw const FormatException(
            'Respuesta cartográfica demasiado grande',
          );
        }
        yield chunk;
      }
    } finally {
      _release();
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!LabMapTiles.permits(request.method, request.url)) {
      throw const SocketException('LAB: destino cartográfico no autorizado');
    }
    await _acquire();
    var streamOwnsSlot = false;
    try {
      final safe = http.Request('GET', request.url)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers['User-Agent'] = 'Papigiras-LAB/0.1 (Flutter map preview)';
      final response = await _transport
          .send(safe)
          .timeout(const Duration(seconds: 15));
      streamOwnsSlot = true;
      final limit = request.url.path == '/planet'
          ? 256 * 1024
          : 8 * 1024 * 1024;
      return http.StreamedResponse(
        _body(response.stream, limit),
        response.statusCode,
        contentLength: response.contentLength,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        request: safe,
      );
    } finally {
      if (!streamOwnsSlot) _release();
    }
  }

  @override
  void close() {
    _closed = true;
    for (final waiter in _waiting) {
      waiter.completeError(
        const SocketException('Cliente cartográfico cerrado'),
      );
    }
    _waiting.clear();
    _transport.close();
  }
}
