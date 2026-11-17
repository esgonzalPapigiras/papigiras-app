import 'session.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

abstract final class LabApi {
  // Delivery QA has its own synthetic server. No runtime host override is
  // allowed, and a build configured for another port fails closed.
  static const localPort = int.fromEnvironment(
    'PAPIGIRAS_LOCAL_API_PORT',
    defaultValue: 8084,
  );
  // Temporary beta: one exact HTTPS hostname fixed at build time. Empty keeps LAB local.
  static const previewHost = String.fromEnvironment('PAPIGIRAS_PREVIEW_HOST');
  static bool get isRemotePreview => previewHost.isNotEmpty;
  static bool get _validPreviewHost => RegExp(
    r'^[a-z0-9]+(?:-[a-z0-9]+){2,7}\.trycloudflare\.com$',
  ).hasMatch(previewHost);
  static bool get _validPort => const {8084, 18084}.contains(localPort);

  static Uri uri(String path, [Map<String, String>? query]) {
    if (isRemotePreview) {
      if (!_validPreviewHost)
        throw StateError('Destino de pruebas no autorizado');
      return Uri.https(previewHost, path, query);
    }
    if (!_validPort) throw StateError('Puerto local de QA no autorizado');
    return Uri.http('127.0.0.1:$localPort', path, query);
  }

  static bool permits(String method, Uri uri) =>
      (isRemotePreview
          ? _validPreviewHost &&
                uri.scheme == 'https' &&
                uri.host == previewHost &&
                uri.port == 443
          : _validPort &&
                uri.scheme == 'http' &&
                uri.host == '127.0.0.1' &&
                uri.port == localPort) &&
      const {'GET', 'POST'}.contains(method) &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      uri.path.startsWith('/app/services/') &&
      !uri.pathSegments.any(
        (segment) =>
            segment == '..' ||
            segment == '.' ||
            segment.contains('\\') ||
            segment.contains('%'),
      );
}

class LabApiException implements Exception {
  final int statusCode;
  const LabApiException(this.statusCode);
  @override
  String toString() =>
      'Servidor LAB: solicitud rechazada ($statusCode). '
      'Revisa la sesión y los datos del servidor local.';
}

class _LocalApiTransport extends HttpOverrides {}

/// This capability bypasses the global deny-all guard only for the selected LAB or temporary beta API.
/// It never redirects, retries another server, or substitutes fixture data.
class LabApiClient extends http.BaseClient {
  final http.Client _transport;

  /// Only the composing-hito client defers navigation while reauthenticating.
  /// Unauthorized credentials are still revoked and never retried here.
  final bool notifyOnUnauthorized;
  LabApiClient({http.Client? transport, this.notifyOnUnauthorized = true})
    : _transport =
          transport ?? IOClient(_LocalApiTransport().createHttpClient(null));

  /// Bounded consumers can stream local bytes without constructing a separate
  /// transport. All destinations, headers, redirects and session checks still
  /// go through send's existing isolation rules.
  Future<http.StreamedResponse> getStream(
    Uri uri, {
    Map<String, String> headers = const {},
  }) => send(http.Request('GET', uri)..headers.addAll(headers));

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!LabApi.permits(request.method, request.url)) {
      throw const SocketException(
        'LAB: solo se permite la API seleccionada al compilar',
      );
    }
    request.followRedirects = false;
    request.maxRedirects = 0;
    request.headers.removeWhere(
      (key, _) => !const {
        'authorization',
        'content-type',
        'accept',
      }.contains(key.toLowerCase()),
    );
    // Bodyless JSON POSTs can be rejected by an HTTPS intermediary even when
    // the local API accepts them. Keep a concrete payload and length on the wire.
    if (request is http.Request &&
        request.method == 'POST' &&
        request.bodyBytes.isEmpty &&
        request.headers['content-type']
                ?.split(';')
                .first
                .trim()
                .toLowerCase() ==
            'application/json') {
      request.body = '{}';
    }
    final requestGeneration = LabSession.generation;
    try {
      final response = await _transport
          .send(request)
          .timeout(Duration(seconds: LabApi.isRemotePreview ? 120 : 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // The local server can return 403 for an absent credential. A 403
        // with a credential remains a permission error, not a session expiry.
        final missingCredential =
            (request.headers['authorization'] ?? '').isEmpty;
        if (response.statusCode == 401 ||
            (response.statusCode == 403 && missingCredential)) {
          await LabSession.invalidateIfCurrent(
            request.headers['authorization'],
            notify: notifyOnUnauthorized,
            expectedGeneration: requestGeneration,
          );
        }
        await response.stream.drain<void>().timeout(
          const Duration(seconds: 12),
        );
        throw LabApiException(response.statusCode);
      }
      return http.StreamedResponse(
        response.stream.timeout(const Duration(seconds: 20)),
        response.statusCode,
        contentLength: response.contentLength,
        request: request,
        headers: response.headers,
        isRedirect: false,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on SocketException {
      throw Exception(
        LabApi.isRemotePreview
            ? 'La conexión de pruebas no está disponible. Comprueba Internet e indica a Camilo que revise el servidor.'
            : 'El servidor Papigiras LAB no está disponible. Inicia el servidor local en tu Mac y vuelve a intentarlo.',
      );
    } on TimeoutException {
      throw Exception(
        'El servidor Papigiras LAB no respondió a tiempo. No se usaron datos de demostración.',
      );
    }
  }

  @override
  void close() => _transport.close();
}
