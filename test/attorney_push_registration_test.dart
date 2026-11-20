import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/notifications/attorney_push_registration.dart';

class Tokens implements PushTokenSource {
  final events = StreamController<String>.broadcast(sync: true);
  Completer<void>? apns;
  Completer<void>? deletion;
  int reads = 0, deletes = 0;
  @override
  Stream<String> get refreshedTokens => events.stream;
  @override
  Future<void> prepare() async {
    await apns?.future;
  }

  @override
  Future<String?> getToken() async {
    reads++;
    return 'device-token';
  }

  @override
  Future<void> deleteToken() async {
    deletes++;
    await deletion?.future;
  }
}

void main() {
  late Tokens tokens;
  late AttorneyPushRegistration registration;
  late List<Object> errors;
  setUp(() {
    tokens = Tokens();
    errors = [];
    registration = AttorneyPushRegistration(
      tokens,
      onError: (error, _) => errors.add(error),
    );
  });
  tearDown(() async {
    await registration.stop(revokeDeviceToken: false);
    await tokens.events.close();
  });

  test(
    'initial and refreshed tokens register for the current attorney',
    () async {
      final sent = <String>[];
      await registration.start(
        sessionIsCurrent: () => true,
        register: (token) async => sent.add(token),
      );
      tokens.events.add('refreshed-token');
      await Future<void>.delayed(Duration.zero);
      expect(sent, ['device-token', 'refreshed-token']);
      expect(errors, isEmpty);
    },
  );

  test('logout while waiting for APNs never uploads the late token', () async {
    tokens.apns = Completer<void>();
    final sent = <String>[];
    final start = registration.start(
      sessionIsCurrent: () => true,
      register: (token) async => sent.add(token),
    );
    await Future<void>.delayed(Duration.zero);
    await registration.stop();
    tokens.apns!.complete();
    await start;
    expect(tokens.reads, 0);
    expect(tokens.deletes, 1);
    expect(sent, isEmpty);
  });

  test(
    'permission failure leaves no refresh listener and a later retry works',
    () async {
      tokens.apns = Completer<void>();
      final sent = <String>[];
      final start = registration.start(
        sessionIsCurrent: () => true,
        register: (token) async => sent.add(token),
      );
      final failure = expectLater(start, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      tokens.events.add('not-authorized');
      tokens.apns!.completeError(StateError('Permission denied'));
      await failure;
      tokens.events.add('still-not-authorized');
      await Future<void>.delayed(Duration.zero);
      expect(sent, isEmpty);
      expect(tokens.events.hasListener, isFalse);
      tokens.apns = null;
      await registration.start(
        sessionIsCurrent: () => true,
        register: (token) async => sent.add(token),
      );
      expect(sent, ['device-token']);
    },
  );

  test('failed initial server registration releases its listener', () async {
    await expectLater(
      registration.start(
        sessionIsCurrent: () => true,
        register: (_) async => throw StateError('Unavailable'),
      ),
      throwsStateError,
    );
    expect(tokens.events.hasListener, isFalse);
  });

  test('changed session rejects refresh even before explicit stop', () async {
    var current = true;
    final sent = <String>[];
    await registration.start(
      sessionIsCurrent: () => current,
      register: (token) async => sent.add(token),
    );
    current = false;
    tokens.events.add('wrong-session-token');
    await Future<void>.delayed(Duration.zero);
    expect(sent, ['device-token']);
  });

  test(
    'new login waits for old token revocation before reading a fresh token',
    () async {
      tokens.deletion = Completer<void>();
      final stop = registration.stop();
      final sent = <String>[];
      final start = registration.start(
        sessionIsCurrent: () => true,
        register: (token) async => sent.add(token),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tokens.reads, 0);
      tokens.deletion!.complete();
      await stop;
      await start;
      expect(sent, ['device-token']);
    },
  );
}
