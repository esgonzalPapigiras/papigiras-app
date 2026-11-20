import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/runtime/api_destination.dart';

void main() {
  test('connected requests stay on the selected HTTPS API origin', () {
    final api = ApiDestination('https://api.example.test/');
    final uri = api.uri('/app/services/coordinator/me', {'id': '1'});
    expect(
      uri.toString(),
      'https://api.example.test/app/services/coordinator/me?id=1',
    );
    expect(api.permits('POST', uri), isTrue);
    for (final target in [
      uri.replace(host: 'api.example.test.evil.test'),
      uri.replace(host: 'other.example.test'),
      uri.replace(scheme: 'http'),
      uri.replace(port: 8443),
      uri.replace(userInfo: 'user:password'),
      uri.replace(fragment: 'fragment'),
      uri.replace(path: '/api/admin'),
      uri.replace(path: '/app/services/%252e%252e/admin'),
      uri.replace(path: '/app/services/..\\admin'),
    ]) {
      expect(api.permits('GET', target), isFalse, reason: '$target');
    }
    expect(api.permits('DELETE', uri), isFalse);
    expect(() => api.uri('/api/admin'), throwsFormatException);
  });

  test(
    'invalid configured origin fails instead of selecting another server',
    () {
      for (final url in [
        '',
        'http://api.example.test',
        'https://',
        'https://user:password@api.example.test',
        'https://api.example.test/base',
        'https://api.example.test?token=secret',
        'https://api.example.test#fragment',
        'https://api.example.test:8443',
        ' https://api.example.test',
        'https://api.example.test ',
      ]) {
        expect(() => ApiDestination(url), throwsFormatException, reason: url);
      }
    },
  );
}
