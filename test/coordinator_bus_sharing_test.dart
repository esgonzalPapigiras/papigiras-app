import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/lab/synthetic_location.dart';
import 'package:papigiras_app/maps/trip_bus_controller.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/pages/attorney/TraceMapFullScreen.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/location_callback.dart';
import 'package:provider/provider.dart';

import 'support/map_tiles.dart';
import 'trip_map_nearby_navigation_test.dart' show row;

class _Provider extends CoordinatorProviders {
  List<PositionCoordinator> rows = [];
  Future<List<PositionCoordinator>> Function()? read;
  int calls = 0;
  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourId) async => [
    row(910021, '-33.45', '-70.65'),
  ];
  @override
  Future<List<PositionCoordinator>> uniqueID(String tourId) {
    calls++;
    return read?.call() ?? Future.value(rows);
  }
}

// Only publishes local state to the route; it never writes coordinates.
class _MapLocationService extends LocationService {
  bool sharing = false;
  CoordinatorLocationReceipt? receipt;

  @override
  int? get activeTourId => 910001;
  @override
  bool get isTracking => sharing;
  @override
  CoordinatorLocationReceipt? get confirmedPosition => receipt;

  void report(bool enabled) {
    sharing = enabled;
    receipt = enabled
        ? CoordinatorLocationReceipt(
            tourId: 910001,
            latitude: -33.445,
            longitude: -70.645,
            recordedAt: DateTime.now().toUtc(),
          )
        : null;
    notifyListeners();
  }
}

PositionCoordinator _point(int coordinator, {double latitude = -33.45}) =>
    PositionCoordinator(
      coordinatorId: coordinator,
      coordinatorName: 'Coordinador ficticio',
      coordinatorLastname: 'LAB',
      latitude: latitude,
      longitude: -70.65,
      recordedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 10)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Provider provider;
  late TripBusController bus;
  late LocationService service;
  late LabSyntheticLocation source;
  late SharedPreferences prefs;
  late void Function() sync;
  final sent = <Uri>[];
  Future<http.Response> Function()? response;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', 'coordinator');
    await prefs.setString('token', 'fictional-local-test-token');
    await prefs.setInt('selectedTourId', 910001);
    source = LabSyntheticLocation();
    service = LocationService(source: source);
    provider = _Provider()..rows = [_point(910001)];
    bus = TripBusController(tourId: 910001, provider: provider);
    sent.clear();
    response = null;
    locationClientForTests = LabApiClient(
      transport: MockClient((request) {
        sent.add(request.url);
        return response?.call() ?? Future.value(http.Response('', 200));
      }),
    );
    sync = () {
      if (service.activeTourId != bus.tourId) return;
      bus.setLocalSharing(
        coordinatorId: 910001,
        enabled: service.isTracking,
        confirmed: service.confirmedPosition,
      );
    };
    service.addListener(sync);
  });

  tearDown(() {
    service.removeListener(sync);
    service.dispose();
    source.dispose();
    bus.dispose();
    provider.dispose();
    locationClientForTests?.close();
    locationClientForTests = null;
  });

  void scenario(String name, Future<void> Function() body) {
    // These service tests use real asynchronous HTTP streams. A widget test's
    // fake clock would keep those streams pending while awaiting the request.
    test(name, () async {
      await service.initializeForCoordinatorSession();
      bus.setVisible(true);
      await Future<void>.delayed(Duration.zero);
      await body();
    });
  }

  scenario(
    'ON applies exact accepted report immediately without polling',
    () async {
      expect(bus.isRecent, isFalse);
      expect(provider.calls, 1);
      await service.setSharingEnabled(true);
      expect(sent, hasLength(1));
      expect(bus.isRecent, isTrue);
      expect(provider.calls, 1);
      final posted = sent.single.queryParameters;
      expect(
        bus.position!.coordinate.latitude,
        double.parse(posted['latitud']!),
      );
      expect(
        bus.position!.coordinate.longitude,
        double.parse(posted['longitud']!),
      );
      expect(bus.position!.recordedAt, DateTime.parse(posted['recordedAt']!));
      expect(service.confirmedPosition?.tourId, 910001);
    },
  );

  scenario(
    'OFF is synchronous and polling cannot move the own frozen bus',
    () async {
      await service.setSharingEnabled(true);
      final last = bus.position;
      final stopping = service.setSharingEnabled(false);
      expect(bus.isRecent, isFalse);
      expect(bus.position, same(last));
      await stopping;
      provider.rows = [_point(910001, latitude: -33.46)];
      await bus.refresh();
      expect(bus.position, same(last));
      expect(bus.isRecent, isFalse);
      expect(service.confirmedPosition, isNull);
    },
  );

  scenario('slow ON stays offline until acknowledged', () async {
    final pending = Completer<http.Response>();
    response = () => pending.future;
    final enabling = service.setSharingEnabled(true);
    await Future<void>.delayed(Duration.zero);
    expect(service.isTracking, isTrue);
    expect(service.isChangingMode, isFalse);
    expect(bus.isRecent, isFalse);
    expect(service.confirmedPosition, isNull);
    pending.complete(http.Response('', 200));
    await enabling;
    expect(bus.isRecent, isTrue);
  });

  scenario('OFF during slow ON rejects its late success', () async {
    final previous = bus.position;
    final pending = Completer<http.Response>();
    response = () => pending.future;
    final enabling = service.setSharingEnabled(true);
    await Future<void>.delayed(Duration.zero);
    expect(sent, hasLength(1));
    await service.setSharingEnabled(false);
    pending.complete(http.Response('', 200));
    await enabling;
    expect(bus.isRecent, isFalse);
    expect(bus.position, same(previous));
    expect(service.confirmedPosition, isNull);
  });

  scenario('failed ON does not revive an older recent own report', () async {
    response = () async => http.Response('', 503);
    await service.setSharingEnabled(true);
    expect(service.lastError, isNotNull);
    expect(service.confirmedPosition, isNull);
    expect(bus.isRecent, isFalse);
    await bus.refresh();
    expect(bus.isRecent, isFalse);
  });

  scenario('own OFF does not turn a different coordinator offline', () async {
    provider.rows = [_point(910002)];
    await bus.refresh();
    expect(bus.position?.coordinatorId, 910002);
    expect(bus.isRecent, isTrue);
    await service.setSharingEnabled(false);
    expect(bus.position?.coordinatorId, 910002);
    expect(bus.isRecent, isTrue);
  });

  scenario('old GET failure cannot undo a newer accepted ON', () async {
    final pendingRead = Completer<List<PositionCoordinator>>();
    provider.read = () => pendingRead.future;
    final refresh = bus.refresh();
    await service.setSharingEnabled(true);
    expect(bus.isRecent, isTrue);
    pendingRead.completeError(StateError('Synthetic delayed read failure'));
    await refresh;
    expect(bus.isRecent, isTrue);
    expect(bus.error, isNull);
  });

  scenario('old GET snapshot cannot move a newer accepted ON', () async {
    final pendingRead = Completer<List<PositionCoordinator>>();
    provider.read = () => pendingRead.future;
    final refresh = bus.refresh();
    await service.setSharingEnabled(true);
    final accepted = bus.position;
    pendingRead.complete([_point(910001, latitude: -33.46)]);
    await refresh;
    expect(bus.position, same(accepted));
    expect(bus.isRecent, isTrue);
  });

  scenario(
    'tour change during POST never applies its acknowledgement',
    () async {
      final pending = Completer<http.Response>();
      response = () => pending.future;
      final enabling = service.setSharingEnabled(true);
      await Future<void>.delayed(Duration.zero);
      await prefs.setInt('selectedTourId', 910002);
      bus.setTour(910002);
      await Future<void>.delayed(Duration.zero);
      final current = bus.position;
      pending.complete(http.Response('', 200));
      await enabling;
      expect(service.confirmedPosition, isNull);
      expect(bus.position, same(current));
    },
  );

  scenario('logout during POST cannot resurrect its bus or receipt', () async {
    final pending = Completer<http.Response>();
    response = () => pending.future;
    final enabling = service.setSharingEnabled(true);
    await Future<void>.delayed(Duration.zero);
    await LabSession.clear(prefs);
    pending.complete(http.Response('', 200));
    await enabling;
    expect(service.activeTourId, isNull);
    expect(service.confirmedPosition, isNull);
    expect(bus.position, isNull);
    expect(bus.isRecent, isFalse);
  });

  for (final isCoordinator in [true, false]) {
    testWidgets(
      isCoordinator
          ? 'standalone coordinator map follows confirmed ON and immediate OFF'
          : 'family map ignores local coordinator sharing changes',
      (tester) async {
        final previousHttp = HttpOverrides.current;
        HttpOverrides.global = LabOfflineHttpOverrides();
        LabMapTiles.testProvider = TestMapTileProvider.new;
        final location = _MapLocationService();
        final map = TripMapController(tourCode: 910001, provider: provider);
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          location.dispose();
          map.dispose();
          LabMapTiles.testProvider = null;
          HttpOverrides.global = previousHttp;
        });
        await map.refresh();
        await tester.pumpWidget(
          ChangeNotifierProvider<LocationService>.value(
            value: location,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: TraceMapFullScreen(
                tourCode: 910001,
                controller: map,
                edgeToEdge: true,
                coordinatorId: isCoordinator ? 910001 : null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final remotePosition = map.bus.position;
        expect(remotePosition, isNotNull);
        expect(map.bus.isRecent, !isCoordinator);

        location.report(true);
        await tester.pump();
        expect(map.bus.isRecent, isTrue);
        if (isCoordinator) {
          expect(map.bus.position!.coordinate.latitude, -33.445);
          expect(map.bus.position!.recordedAt, location.receipt!.recordedAt);
        } else {
          expect(map.bus.position, same(remotePosition));
        }
        final acceptedPosition = map.bus.position;
        location.report(false);
        expect(map.bus.isRecent, !isCoordinator);
        expect(map.bus.position, same(acceptedPosition));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
