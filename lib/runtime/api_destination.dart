/// One HTTPS API origin fixed at build time. No credentials, paths, redirects,
/// runtime URL overrides or fallback to another environment are accepted.
class ApiDestination {
  ApiDestination(String value) : origin = _parse(value);

  final Uri origin;

  static Uri _parse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        value != value.trim() ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !RegExp(r'^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$').hasMatch(uri.host) ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Configura un origen HTTPS válido para Papigiras.',
      );
    }
    return uri.replace(path: '');
  }

  Uri uri(String path, [Map<String, String>? query]) {
    final result = origin.replace(path: path, queryParameters: query);
    if (!permits('GET', result)) {
      throw const FormatException('Ruta de API no autorizada.');
    }
    return result;
  }

  bool permits(String method, Uri target) =>
      const {'GET', 'POST'}.contains(method) &&
      target.scheme == origin.scheme &&
      target.host == origin.host &&
      target.port == origin.port &&
      target.userInfo.isEmpty &&
      !target.hasFragment &&
      target.path.startsWith('/app/services/') &&
      !target.pathSegments.any(
        (part) =>
            part == '.' ||
            part == '..' ||
            part.contains('\\') ||
            part.contains('%'),
      );
}

abstract final class AppEnvironment {
  // Empty retains the executable Pilo reference for isolated regression tests.
  // Connected phone builds explicitly supply the official API's HTTPS origin.
  static const apiUrl = String.fromEnvironment('PAPIGIRAS_API_URL');
  static bool get connected => apiUrl.isNotEmpty;
  static final ApiDestination? destination = connected
      ? ApiDestination(apiUrl)
      : null;
}
