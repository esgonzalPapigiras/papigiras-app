import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/api_http.dart';

void main() {
  test('remote preview requires an exact approved HTTPS origin', () {
    if (!LabApi.isRemotePreview) return;
    final uri = LabApi.uri('/app/services/get/create-hito', {
      'tourId': '910001',
    });
    expect(uri.scheme, 'https');
    expect(uri.host, LabApi.previewHost);
    expect(LabApi.permits('GET', uri), isTrue);
    for (final bad in [
      uri.replace(host: '127.0.0.1'),
      uri.replace(host: 'other-preview-host.trycloudflare.com'),
      uri.replace(host: '${uri.host}.evil.invalid'),
      uri.replace(scheme: 'http'),
      uri.replace(port: 8443),
      uri.replace(userInfo: 'x'),
      uri.replace(fragment: 'x'),
      uri.replace(path: '/api/admin'),
      uri.replace(path: '/app/services/%252e%252e/x'),
    ]) {
      expect(LabApi.permits('GET', bad), isFalse, reason: '$bad');
    }
    expect(LabApi.permits('DELETE', uri), isFalse);
  });
}
