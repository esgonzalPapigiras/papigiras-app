import 'dart:convert';
import '../dto/json_fields.dart';
import 'api_http.dart';

class LocalProfile {
  const LocalProfile({
    required this.id,
    required this.label,
    required this.detail,
  });
  final int id;
  final String label;
  final String detail;
  factory LocalProfile.fromJson(Map<String, dynamic> value) => LocalProfile(
    id: JsonFields.id(value['profileId']),
    label: JsonFields.text(value['label'], 'Perfil sin nombre'),
    detail: JsonFields.text(value['detail']),
  );
}

class LocalProfilePage {
  const LocalProfilePage({
    required this.items,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });
  final List<LocalProfile> items;
  final int offset;
  final int limit;
  final bool hasMore;
  factory LocalProfilePage.fromJson(Map<String, dynamic> value) =>
      LocalProfilePage(
        items: JsonFields.records(
          value['items'],
        ).map(LocalProfile.fromJson).toList(),
        offset: JsonFields.integer(value['offset']),
        limit: JsonFields.integer(value['limit'], 25),
        hasMore: JsonFields.boolean(value['hasMore']),
      );
}

/// The operator secret/token and catalog remain in memory for this selector only.
class LocalAccessClient {
  LocalAccessClient({LabApiClient? client})
    : _client = client ?? LabApiClient();
  final LabApiClient _client;
  String? _operatorToken;
  static const roles = {'coordinator', 'passenger', 'attorney'};

  Map<String, dynamic> _object(List<int> bytes) {
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    throw const FormatException(
      'La API local devolvió una respuesta inválida.',
    );
  }

  Future<void> unlock(String password) async {
    _operatorToken = null;
    final response = await _client.post(
      LabApi.uri('/app/services/lab/operator/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    final token = JsonFields.text(_object(response.bodyBytes)['token']);
    if (!token.startsWith('Bearer ') || token.length <= 7) {
      throw const FormatException('La API local no entregó un acceso válido.');
    }
    _operatorToken = token;
  }

  Map<String, String> get _headers {
    if (_operatorToken == null)
      throw const FormatException('Ingresa nuevamente la clave local.');
    return {
      'Authorization': _operatorToken!,
      'Content-Type': 'application/json',
    };
  }

  void _checkRole(String role) {
    if (!roles.contains(role))
      throw const FormatException('Rol local inválido.');
  }

  Future<LocalProfilePage> profiles(
    String role, {
    String query = '',
    int offset = 0,
  }) async {
    _checkRole(role);
    if (offset < 0 || query.length > 100)
      throw const FormatException('Búsqueda local inválida.');
    final response = await _client.get(
      LabApi.uri('/app/services/lab/profiles', {
        'role': role,
        'query': query,
        'offset': '$offset',
        'limit': '25',
      }),
      headers: _headers,
    );
    return LocalProfilePage.fromJson(_object(response.bodyBytes));
  }

  Future<Map<String, dynamic>> session(String role, int profileId) async {
    _checkRole(role);
    if (profileId <= 0) throw const FormatException('Perfil local inválido.');
    final response = await _client.post(
      LabApi.uri('/app/services/lab/session'),
      headers: _headers,
      body: jsonEncode({'role': role, 'profileId': profileId}),
    );
    return _object(response.bodyBytes);
  }

  void close() {
    _operatorToken = null;
    _client.close();
  }
}
