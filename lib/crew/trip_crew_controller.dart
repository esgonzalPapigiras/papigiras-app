import 'package:flutter/foundation.dart';
import '../dto/tourTripulation.dart';
import 'crew_coordinator.dart';
import '../provider/coordinatorProvider.dart';

class TripCrewController extends ChangeNotifier {
  TripCrewController({required this.tourId, CoordinatorProviders? provider})
    : _provider = provider ?? CoordinatorProviders(),
      _ownsProvider = provider == null;
  final int tourId;
  final CoordinatorProviders _provider;
  final bool _ownsProvider;
  bool _disposed = false;
  int _generation = 0;
  bool loading = false;
  bool initialized = false;
  bool crewError = false;
  bool transportError = false;
  List<TourTripulation> buses = [];
  List<TourTripulation> drivers = [];
  List<CrewCoordinator> coordinators = [];
  final Map<int, Future<Uint8List?>> _photos = {};

  Future<Uint8List?> photo(int id) => _photos.putIfAbsent(
    id,
    () => _provider.getCrewCoordinatorPicture(tourId, id),
  );

  Future<void> refresh() async {
    if (_disposed || loading) return;
    final generation = ++_generation;
    loading = true;
    crewError = false;
    transportError = false;
    _photos.clear();
    notifyListeners();
    bool current() => !_disposed && generation == _generation;
    await Future.wait([
      () async {
        try {
          final rows = await _provider.getTripulation('$tourId');
          if (!current()) return;
          if (rows.any((row) => row.tourSalesId != tourId)) {
            throw const FormatException('Tripulación ajena a la gira.');
          }
          final uniqueBuses = <List<String>>[];
          final uniquePeople = <List<String>>[];
          buses = [];
          drivers = [];
          for (final row in rows) {
            final bus = [
              row.tourTripulationBusPatent,
              row.tourTripulationBusBrand,
              row.tourTripulationBusModel,
              row.tourTripulationBusYear,
              row.tourTripulationBusEnterprise,
            ].map((s) => s.trim()).toList();
            if (bus.any((s) => s.isNotEmpty) &&
                !uniqueBuses.any((key) => listEquals(key, bus))) {
              uniqueBuses.add(bus);
              buses.add(row);
            }
            final person = [
              row.tourTripulationIdentificationId.trim(),
              row.tourTripulationNameId.trim(),
              '${row.tourTripulationTypeId}',
            ];
            if (row.tourTripulationTypeId != 32 &&
                person.take(2).any((s) => s.isNotEmpty) &&
                !uniquePeople.any((key) => listEquals(key, person))) {
              uniquePeople.add(person);
              drivers.add(row);
            }
          }
        } catch (_) {
          if (current()) transportError = true;
        }
      }(),
      () async {
        try {
          final members = await _provider.getCrewCoordinators(tourId);
          if (current()) coordinators = members;
        } catch (_) {
          if (current()) crewError = true;
        }
      }(),
    ]);
    if (!current()) return;
    initialized = true;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _photos.clear();
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }
}
