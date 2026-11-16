import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/location_callback.dart';

/// A recorded coordinator position, without personal fields from the response.
/// The endpoint does not identify a bus or acknowledge whether sharing is on.
class TripBusPosition {
  const TripBusPosition({
    required this.coordinatorId,
    required this.coordinate,
    required this.recordedAt,
    this.headingDegrees,
  });

  final int coordinatorId;
  final LatLng coordinate;
  final DateTime? recordedAt;

  /// Direction of travel clockwise from north, when successive fixes show motion.
  final double? headingDegrees;
}

/// Reads the existing positions endpoint only while a map is visible and the
/// app is in the foreground. It never enables sharing or accesses device GPS.
class TripBusController extends ChangeNotifier with WidgetsBindingObserver {
  TripBusController({
    required int tourId,
    CoordinatorProviders? provider,
    DateTime Function()? now,
    this.pollInterval = const Duration(seconds: 20),
  }) : assert(tourId > 0),
       assert(pollInterval > Duration.zero),
       _tourId = tourId,
       _provider = provider ?? CoordinatorProviders(),
       _ownsProvider = provider == null,
       _now = now ?? DateTime.now {
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  static const recentWindow = Duration(minutes: 2);
  static const _minimumHeadingDistanceMeters = 12.0;
  static const _gpsDistance = DistanceHaversine(roundResult: false);
  final Duration pollInterval;
  final CoordinatorProviders _provider;
  final bool _ownsProvider;
  final DateTime Function() _now;
  // LAB session boundary; production integration must bind to its own session
  // lifecycle. A recycled token cannot revive a reader from an earlier login.
  final int _sessionGeneration = LabSession.generation;
  bool _sessionRevoked = false;
  int _tourId;
  int _generation = 0;
  bool _visible = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _loading = false;
  bool _successfulRead = false;
  bool _hasCompletedRead = false;
  bool _reloadAfterRequest = false;
  String? _error;
  TripBusPosition? _position;
  TripBusPosition? _headingReference;
  int? _localCoordinatorId;
  bool _localSharingEnabled = false;
  CoordinatorLocationReceipt? _localReceipt;
  TripBusPosition? _localObservation;
  Timer? _pollTimer;
  Timer? _expiryTimer;
  Future<void>? _request;

  int get tourId => _tourId;
  bool get loading => _currentSession && _loading;
  bool get hasCompletedRead => _canRead && _hasCompletedRead;
  String? get error => _currentSession ? _error : null;
  TripBusPosition? get position => _currentSession ? _position : null;
  bool get _currentSession =>
      !_sessionRevoked && LabSession.generation == _sessionGeneration;
  bool get _canRead => !_disposed && _currentSession && _visible && _foreground;

  bool _guardSession() {
    if (_disposed) return false;
    if (_currentSession) return true;
    if (!_sessionRevoked) {
      _sessionRevoked = true;
      ++_generation;
      _position = null;
      _headingReference = null;
      _error = null;
      _loading = false;
      _successfulRead = false;
      _reloadAfterRequest = false;
      _pollTimer?.cancel();
      _expiryTimer?.cancel();
      notifyListeners();
    }
    return false;
  }

  /// Recency is evidence of a recorded update, not a remote sharing state.
  /// Future timestamps, failures and hidden/background maps never pulse.
  bool get isRecent {
    final recordedAt = _position?.recordedAt;
    if (_position?.coordinatorId == _localCoordinatorId &&
        (!_localSharingEnabled || _localReceipt == null))
      return false;
    if (!_canRead || !_successfulRead || recordedAt == null) return false;
    final age = _now().toUtc().difference(recordedAt);
    return !age.isNegative && age <= recentWindow;
  }

  /// Connect only the current coordinator's map to their local sharing choice.
  /// OFF is immediate; ON becomes recent only after the exact POST is accepted.
  /// Remote maps still use the existing endpoint's timestamp-based contract.
  void setLocalSharing({
    required int coordinatorId,
    required bool enabled,
    required CoordinatorLocationReceipt? confirmed,
  }) {
    if (!_guardSession() || coordinatorId <= 0) return;
    final accepted =
        enabled &&
            confirmed != null &&
            confirmed.tourId == _tourId &&
            confirmed.latitude.isFinite &&
            confirmed.longitude.isFinite &&
            confirmed.latitude.abs() <= 90 &&
            confirmed.longitude.abs() <= 180 &&
            !confirmed.recordedAt.toUtc().isAfter(_now().toUtc())
        ? confirmed
        : null;
    if (_localCoordinatorId == coordinatorId &&
        _localSharingEnabled == enabled &&
        identical(_localReceipt, accepted))
      return;

    if (_localCoordinatorId != coordinatorId) _localObservation = null;
    _localCoordinatorId = coordinatorId;
    _localSharingEnabled = enabled;
    _localReceipt = accepted;
    if (accepted == null) {
      // Freeze the last known own position; polling cannot move it after OFF.
      if (_position?.coordinatorId == coordinatorId) {
        _localObservation = _position;
      }
    } else {
      // Ignore a GET started before this POST acknowledgement; it can contain
      // an older snapshot or fail after the newly accepted report is displayed.
      ++_generation;
      final reported = TripBusPosition(
        coordinatorId: coordinatorId,
        coordinate: LatLng(accepted.latitude, accepted.longitude),
        recordedAt: accepted.recordedAt.toUtc(),
      );
      _localObservation = reported;
      final latest = _preferLocal(_position);
      _position = _withHeading(latest);
      if (_position?.coordinatorId == coordinatorId) {
        _localObservation = _position;
      }
      _successfulRead = true;
      _hasCompletedRead = true;
      _error = null;
    }
    _scheduleExpiry();
    notifyListeners();
  }

  TripBusPosition? _preferLocal(TripBusPosition? remote) {
    final local = _localObservation;
    if (local == null) return remote;
    if (remote == null) return local;
    if (remote.coordinatorId == _localCoordinatorId &&
        (!_localSharingEnabled || _localReceipt == null))
      return local;
    final localTime = local.recordedAt;
    final remoteTime = remote.recordedAt;
    if (localTime != null &&
        !localTime.isAfter(_now().toUtc()) &&
        (remoteTime == null ||
            remoteTime.isAfter(_now().toUtc()) ||
            localTime.isAfter(remoteTime)))
      return local;
    return remote;
  }

  /// A shared compact/expanded map owner controls visibility explicitly.
  /// Calling true again is idempotent and does not create another timer/load.
  void setVisible(bool visible) {
    if (!_guardSession() || visible == _visible) return;
    _visible = visible;
    _updateActivity();
  }

  /// Clears the old tour immediately; an in-flight response cannot restore it.
  /// The new request waits for the old one, so HTTP requests never overlap.
  void setTour(int tourId) {
    if (!_guardSession() || tourId <= 0 || tourId == _tourId) return;
    _tourId = tourId;
    ++_generation;
    _position = null;
    _headingReference = null;
    _localCoordinatorId = null;
    _localObservation = null;
    _localReceipt = null;
    _localSharingEnabled = false;
    _error = null;
    _successfulRead = false;
    _hasCompletedRead = false;
    _expiryTimer?.cancel();
    notifyListeners();
    if (_canRead) _requestLatest();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_guardSession()) return;
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _updateActivity();
  }

  void _updateActivity() {
    ++_generation;
    _successfulRead = false;
    _hasCompletedRead = false;
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    if (_canRead) {
      _pollTimer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
      _requestLatest();
    } else {
      _reloadAfterRequest = false;
      notifyListeners();
    }
  }

  void _requestLatest() {
    if (_request != null) {
      _reloadAfterRequest = true;
      notifyListeners();
    } else {
      unawaited(refresh());
    }
  }

  /// Manual refresh and timer ticks share a single in-flight request.
  Future<void> refresh() {
    if (!_guardSession() || !_canRead) return Future.value();
    final pending = _request;
    if (pending != null) return pending;
    final completed = Completer<void>();
    _request = completed.future;
    _loading = true;
    notifyListeners();
    unawaited(_load(_tourId, _generation, completed));
    return completed.future;
  }

  Future<void> _load(
    int tourId,
    int generation,
    Completer<void> completed,
  ) async {
    try {
      final rows = await _provider.uniqueID(tourId.toString());
      if (!_guardSession() || !_canRead || generation != _generation) return;
      final latest = _preferLocal(_latestValid(rows));
      _position = _withHeading(latest);
      if (_position?.coordinatorId == _localCoordinatorId &&
          _localObservation == null &&
          (!_localSharingEnabled || _localReceipt == null)) {
        _localObservation = _position;
      }
      // A repeated report can restore freshness after a failed refresh. A
      // rejected report cannot make the retained position appear recent.
      _successfulRead =
          latest?.recordedAt == _position?.recordedAt &&
          latest?.coordinatorId == _position?.coordinatorId;
      _hasCompletedRead = true;
      _error = null;
      _scheduleExpiry();
    } catch (_) {
      if (!_guardSession() || !_canRead || generation != _generation) return;
      _successfulRead = false;
      _hasCompletedRead = true;
      _error = 'No pudimos actualizar la ubicación. Inténtalo de nuevo.';
      _expiryTimer?.cancel();
    } finally {
      _request = null;
      _loading = false;
      completed.complete();
      if (_guardSession()) {
        final reload = _reloadAfterRequest;
        _reloadAfterRequest = false;
        if (reload && _canRead) {
          _requestLatest();
        } else {
          notifyListeners();
        }
      }
    }
  }

  TripBusPosition? _withHeading(TripBusPosition? next) {
    if (next == null) {
      _headingReference = null;
      return null;
    }

    final now = _now().toUtc();
    final previous = _position;
    final previousTime = previous?.recordedAt;
    final nextTime = next.recordedAt;
    final previousVerified =
        _headingReference != null &&
        previousTime != null &&
        !previousTime.isAfter(now);
    final nextVerified = nextTime != null && !nextTime.isAfter(now);

    // An undated, repeated or out-of-order fix must not move the last known
    // position or alter its heading.
    if (previousVerified &&
        (!nextVerified ||
            nextTime.isBefore(previousTime) ||
            (nextTime == previousTime &&
                next.coordinatorId == previous?.coordinatorId))) {
      return previous;
    }
    if (!nextVerified) {
      _headingReference = null;
      return next;
    }
    if (!previousVerified ||
        previous == null ||
        previous.coordinatorId != next.coordinatorId) {
      _headingReference = next;
      return next;
    }

    var heading = previous.headingDegrees;
    final reference = _headingReference ?? previous;
    // Keep the last known heading across gaps. Require two nearby reports in
    // time before drawing a new direction, rather than joining an entire gap.
    if (nextTime.difference(previousTime) > recentWindow) {
      _headingReference = next;
    } else if (_gpsDistance(reference.coordinate, next.coordinate) >=
        _minimumHeadingDistanceMeters) {
      heading =
          _gpsDistance.bearing(reference.coordinate, next.coordinate) % 360.0;
      _headingReference = next;
    }

    return TripBusPosition(
      coordinatorId: next.coordinatorId,
      coordinate: next.coordinate,
      recordedAt: nextTime,
      headingDegrees: heading,
    );
  }

  TripBusPosition? _latestValid(List<PositionCoordinator> rows) {
    final now = _now().toUtc();
    final candidates = rows
        .where(
          (row) =>
              row.coordinatorId > 0 &&
              row.latitude.isFinite &&
              row.longitude.isFinite &&
              row.latitude >= -90 &&
              row.latitude <= 90 &&
              row.longitude >= -180 &&
              row.longitude <= 180,
        )
        .map(
          (row) => TripBusPosition(
            coordinatorId: row.coordinatorId,
            coordinate: LatLng(row.latitude, row.longitude),
            recordedAt: row.recordedAt?.toUtc(),
          ),
        )
        .toList();
    // Prefer a verifiable recorded date to a future or missing date. A future
    // clock must not hide another coordinator's correctly dated recent update.
    int dateRank(TripBusPosition item) {
      final date = item.recordedAt;
      if (date == null) return 0;
      return date.isAfter(now) ? 1 : 2;
    }

    candidates.sort((a, b) {
      final rank = dateRank(b).compareTo(dateRank(a));
      if (rank != 0) return rank;
      final byDate = b.recordedAt?.compareTo(a.recordedAt!) ?? 0;
      return byDate != 0 ? byDate : a.coordinatorId.compareTo(b.coordinatorId);
    });
    return candidates.isEmpty ? null : candidates.first;
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    if (!isRecent) return;
    final remaining = _position!.recordedAt!
        .add(recentWindow)
        .difference(_now().toUtc());
    // Notify independently of polling, including when a slow request is still
    // pending. The inclusive freshness boundary expires one microsecond later.
    _expiryTimer = Timer(remaining + const Duration(microseconds: 1), () {
      if (_guardSession() && _canRead) notifyListeners();
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }
}
