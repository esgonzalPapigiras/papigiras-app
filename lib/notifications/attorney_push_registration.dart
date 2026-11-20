import 'dart:async';

abstract interface class PushTokenSource {
  Stream<String> get refreshedTokens;
  Future<void> prepare();
  Future<String?> getToken();
  Future<void> deleteToken();
}

/// A subscription belongs to one authenticated attorney session. Completion of
/// native APNs/FCM work after logout must never register a different account.
class AttorneyPushRegistration {
  AttorneyPushRegistration(this.source, {required this.onError});

  final PushTokenSource source;
  final void Function(Object, StackTrace) onError;
  StreamSubscription<String>? _subscription;
  Future<void> _revocation = Future<void>.value();
  int _revision = 0;

  Future<void> start({
    required bool Function() sessionIsCurrent,
    required Future<void> Function(String token) register,
  }) async {
    final revision = ++_revision;
    final previous = _subscription;
    _subscription = null;
    await previous?.cancel();
    await _revocation;
    bool current() => revision == _revision && sessionIsCurrent();
    if (!current()) return;

    Future<void> send(String token) async {
      if (!current() || token.isEmpty) return;
      await register(token);
    }

    // Permission/APNs readiness precedes all token registration, including a
    // cached token refresh emitted while the native permission dialog is open.
    await source.prepare();
    if (!current()) return;
    final subscription = source.refreshedTokens.listen(
      (token) async {
        try {
          await send(token);
        } catch (error, stack) {
          if (current()) onError(error, stack);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (current()) onError(error, stack);
      },
    );
    _subscription = subscription;
    try {
      final token = await source.getToken();
      if (!current()) return;
      if (token == null || token.isEmpty) {
        throw StateError('No se recibió un token de notificaciones.');
      }
      await send(token);
    } catch (_) {
      // Only this attempt owns this listener. A newer session may already have
      // installed another one while the old native request was finishing.
      if (revision == _revision) _subscription = null;
      await subscription.cancel();
      rethrow;
    }
  }

  Future<void> stop({bool revokeDeviceToken = true}) {
    ++_revision; // Synchronously invalidate callbacks before any awaited work.
    final previous = _subscription;
    _subscription = null;
    final cancellation = previous?.cancel() ?? Future<void>.value();
    if (revokeDeviceToken) {
      // New login waits for deletion: an old logout must not delete its token.
      _revocation = _revocation
          .then((_) => source.deleteToken())
          .catchError(
            (Object error, StackTrace stack) => onError(error, stack),
          );
    }
    return Future.wait<void>([cancellation, _revocation]).then((_) {});
  }
}
