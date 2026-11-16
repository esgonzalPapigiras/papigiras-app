import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/api_http.dart';

void main() {
  const selected = int.fromEnvironment(
    'PAPIGIRAS_LOCAL_API_PORT',
    defaultValue: 8084,
  );
  test('QA compile-time port stays loopback and rejects other origins', () {
    if (!const {8084, 18084}.contains(selected)) {
      expect(() => LabApi.uri('/app/services/health'), throwsStateError);
      expect(
        LabApi.permits(
          'GET',
          Uri.parse('http://127.0.0.1:$selected/app/services/health'),
        ),
        isFalse,
      );
      return;
    }
    final uri = LabApi.uri('/app/services/health');
    expect(uri.host, '127.0.0.1');
    expect(uri.port, selected);
    expect(LabApi.permits('GET', uri), isTrue);
    for (final host in ['localhost', 'example.invalid']) {
      expect(LabApi.permits('GET', uri.replace(host: host)), isFalse);
    }
    for (final port in [80, 8084, 18084, 18085]) {
      expect(LabApi.permits('GET', uri.replace(port: port)), port == selected);
    }
    expect(LabApi.permits('GET', uri.replace(path: '/admin')), isFalse);
    expect(LabApi.permits('DELETE', uri), isFalse);
  });
}
