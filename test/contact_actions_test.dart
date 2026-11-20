import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/runtime/contact_actions.dart';

void main() {
  test(
    'opens a prepared native conversation with encoded message and digits',
    () async {
      final calls = <Uri>[];
      final contact = WhatsAppContact(
        connected: true,
        launch: (uri) async {
          calls.add(uri);
          return true;
        },
      );
      expect(
        await contact.open('+56 (9) 1234-5678', 'Hola & adiós? + #'),
        isTrue,
      );
      expect(calls, hasLength(1));
      expect(calls.single.scheme, 'whatsapp');
      expect(calls.single.host, 'send');
      expect(calls.single.queryParameters, {
        'phone': '56912345678',
        'text': 'Hola & adiós? + #',
      });
      expect(calls.single.query, contains('%20'));
    },
  );

  test(
    'native refusal and exception both fall back to exact HTTPS destination',
    () async {
      for (final throws in [false, true]) {
        final calls = <Uri>[];
        final contact = WhatsAppContact(
          connected: true,
          launch: (uri) async {
            calls.add(uri);
            if (calls.length == 1) {
              if (throws) throw PlatformException(code: 'unsupported');
              return false;
            }
            return true;
          },
        );
        expect(await contact.open('+56912345678', 'Necesito ayuda'), isTrue);
        expect(calls, hasLength(2));
        expect(calls.last.scheme, 'https');
        expect(calls.last.host, 'wa.me');
        expect(calls.last.path, '/56912345678');
        expect(calls.last.queryParameters['text'], 'Necesito ayuda');
      }
    },
  );

  test(
    'failure is reported and invalid phone values never launch anything',
    () async {
      final calls = <Uri>[];
      final contact = WhatsAppContact(
        connected: true,
        launch: (uri) async {
          calls.add(uri);
          return false;
        },
      );
      for (final phone in [
        '',
        'LAB-CONTACTO',
        'https://evil.test',
        '+56912345678&text=other',
        '123',
        '0' * 12,
      ]) {
        expect(await contact.open(phone, 'Hola'), isFalse);
      }
      expect(calls, isEmpty);
      expect(await contact.open('+56912345678', 'Hola'), isFalse);
      expect(calls, hasLength(2));
    },
  );

  test('isolated reference never opens an external application', () async {
    final contact = WhatsAppContact(
      connected: false,
      launch: (_) async {
        fail('LAB must not call the native launcher');
      },
    );
    expect(await contact.open(agencyPhone, 'Hola'), isTrue);
  });
}
