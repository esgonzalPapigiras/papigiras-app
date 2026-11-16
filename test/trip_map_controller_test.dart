import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/PositionCoordinator.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class _MapProvider extends CoordinatorProviders {
  List<ConsolidatedTourSalesDTO> rows = [];
  Future<List<ConsolidatedTourSalesDTO>> Function()? onBinnacle;
  Future<DetailHitoList> Function(String)? onDetail;
  final tours = <String>[];
  final detailIds = <String>[];
  final detailTours = <String>[];
  var disposeCount = 0;
  final positionTours = <String>[];

  @override
  Future<List<PositionCoordinator>> uniqueID(String tourId) async {
    positionTours.add(tourId);
    return [];
  }

  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tourCode) {
    tours.add(tourCode);
    return onBinnacle?.call() ?? Future.value(rows);
  }

  @override
  Future<DetailHitoList> getHitoComplete(String hito, String tourId) {
    detailIds.add(hito);
    detailTours.add(tourId);
    return onDetail?.call(hito) ??
        Future.value(DetailHitoList(titulo: 'Detalle $hito', images: []));
  }

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

ConsolidatedTourSalesDTO _hito(int id, String hour, {bool located = true}) =>
    ConsolidatedTourSalesDTO(
      binnacleDetailId: id,
      binnacleTitulo: 'Hito $id',
      binnacleDescripcion: 'Dato ficticio',
      binnacleUbicacion: 'Lugar LAB',
      binnacleNotaCierre: '',
      binnacleLatitud: located ? '-33.44' : '',
      binnacleLongitud: located ? '-70.65' : '',
      binnacleHora: hour,
      binnacleFecha: '2026-11-03',
      author: null,
      canModify: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MapProvider provider;
  late TripMapController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = _MapProvider();
    controller = TripMapController(tourCode: 910001, provider: provider);
  });
  tearDown(() {
    controller.dispose();
    provider.dispose();
  });

  test(
    'selección por fecha y navegación incluyen hitos sin coordenadas',
    () async {
      provider.rows = [
        _hito(9, '09:00'),
        _hito(1, '18:30'),
        _hito(4, '12:30', located: false),
      ];
      expect(provider.tours, isEmpty);
      expect(controller.loading, isFalse);
      await controller.refresh();
      expect(provider.tours, ['910001']);
      expect(controller.selectedId, 1);
      expect(controller.selected?.ordinal, 3);
      expect(controller.canNext, isFalse);
      controller.previous();
      expect(controller.selectedId, 4);
      expect(controller.selected?.position, isNull);
      controller.previous();
      expect(controller.selectedId, 9);
      expect(controller.canPrevious, isFalse);
      controller.previous();
      controller.next();
      expect(controller.selectedId, 4);
      controller.select(99999);
      expect(controller.selectedId, 4);
    },
  );

  test(
    'repetir una selección válida notifica sin aceptar IDs inválidos ni dispose',
    () async {
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.select(1); // No data has loaded yet.
      expect(controller.selectionRevision, 0);
      expect(notifications, 0);
      provider.rows = [_hito(1, '09:00'), _hito(2, '12:00')];
      await controller.refresh();
      expect(controller.selectedId, 2);
      expect(controller.selectionRevision, 0);
      notifications = 0;
      final detail = controller.detail(2);
      await detail;
      controller.select(2);
      expect(controller.selectionRevision, 1);
      expect(notifications, 1);
      controller.select(2);
      expect(controller.selectionRevision, 2);
      expect(notifications, 2);
      expect(identical(detail, controller.detail(2)), isTrue);
      controller.select(1);
      expect(controller.selectionRevision, 3);
      expect(notifications, 3);
      controller.select(99999);
      expect(controller.selectedId, 1);
      expect(controller.selectionRevision, 3);
      expect(notifications, 3);
      controller.dispose();
      controller.select(1);
      expect(controller.selectionRevision, 3);
      expect(notifications, 3);
    },
  );

  test(
    'refrescar conserva ID y resuelve eliminación o bitácora vacía',
    () async {
      provider.rows = [_hito(1, '09:00'), _hito(2, '12:00')];
      await controller.refresh();
      controller.select(1);
      expect(controller.selectionRevision, 1);
      provider.rows = [_hito(1, '15:00'), _hito(2, '12:00'), _hito(3, '18:00')];
      await controller.refresh();
      expect(controller.selectedId, 1);
      expect(controller.selected?.ordinal, 2);
      expect(controller.selectionRevision, 1);
      provider.rows = [_hito(2, '12:00'), _hito(3, '18:00')];
      await controller.refresh();
      expect(controller.selectedId, 3);
      expect(controller.selectionRevision, 1);
      provider.rows = [];
      await controller.refresh();
      expect(controller.selectedId, isNull);
      expect(controller.selectionRevision, 1);
      expect(controller.selected, isNull);
      expect(controller.canPrevious, isFalse);
      expect(controller.canNext, isFalse);
    },
  );

  test(
    'un error conserva datos anteriores y un reintento limpia el error',
    () async {
      provider.rows = [_hito(1, '09:00')];
      await controller.refresh();
      provider.onBinnacle = () => Future.error(StateError('Error ficticio'));
      await controller.refresh();
      expect(controller.error, isNotNull);
      expect(controller.loading, isFalse);
      expect(controller.data?.entries.single.id, 1);
      provider.onBinnacle = null;
      provider.rows = [_hito(2, '12:00')];
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.selectedId, 2);
    },
  );

  test(
    'solo la última actualización puede cambiar datos, error y loading',
    () async {
      final first = Completer<List<ConsolidatedTourSalesDTO>>();
      final second = Completer<List<ConsolidatedTourSalesDTO>>();
      var request = 0;
      provider.onBinnacle = () => request++ == 0 ? first.future : second.future;
      final olderRequest = controller.refresh();
      final newerRequest = controller.refresh();
      first.completeError(StateError('Error obsoleto'));
      await olderRequest;
      expect(controller.loading, isTrue);
      expect(controller.error, isNull);
      second.complete([_hito(7, '16:00')]);
      await newerRequest;
      expect(controller.selectedId, 7);
      expect(controller.loading, isFalse);

      final stale = Completer<List<ConsolidatedTourSalesDTO>>();
      provider.onBinnacle = () => stale.future;
      final staleRequest = controller.refresh();
      provider.onBinnacle = null;
      provider.rows = [_hito(8, '18:00')];
      await controller.refresh();
      stale.complete([_hito(6, '09:00')]);
      await staleRequest;
      expect(controller.selectedId, 8);
    },
  );

  test(
    'detalle comparte Future y limita cache LRU a tres hitos por gira',
    () async {
      provider.rows = [for (var id = 1; id <= 4; id++) _hito(id, '0$id:00')];
      await controller.refresh();
      final first = controller.detail(1);
      expect(identical(first, controller.detail(1)), isTrue);
      await first;
      await controller.detail(2);
      await controller.detail(3);
      await controller.detail(1); // 2 becomes the least recently used entry.
      await controller.detail(4);
      await controller.detail(2);
      expect(provider.detailIds, ['1', '2', '3', '4', '2']);
      expect(provider.detailTours.every((tour) => tour == '910001'), isTrue);
      await controller.refresh();
      await controller.detail(1);
      expect(provider.detailIds.last, '1');
      expect(provider.detailIds.length, 6);
      await expectLater(controller.detail(12345), throwsArgumentError);
      expect(provider.detailIds.length, 6);
    },
  );

  test('detalle fallido permanece estable hasta reintento explícito', () async {
    provider.rows = [_hito(1, '09:00')];
    await controller.refresh();
    provider.onDetail = (_) => Future.error(StateError('Error ficticio'));
    final failed = controller.detail(1);
    await expectLater(failed, throwsStateError);
    expect(identical(failed, controller.detail(1)), isTrue);
    await expectLater(controller.detail(1), throwsStateError);
    expect(provider.detailIds, ['1']);
    provider.onDetail = null;
    final recovered = controller.detail(1, retry: true);
    expect(identical(failed, recovered), isFalse);
    expect((await recovered).titulo, 'Detalle 1');
    expect(provider.detailIds, ['1', '1']);
  });

  test(
    'dispose descarta respuestas tardías y conserva provider prestado',
    () async {
      final pending = Completer<List<ConsolidatedTourSalesDTO>>();
      provider.onBinnacle = () => pending.future;
      var notifications = 0;
      controller.addListener(() => notifications++);
      final refresh = controller.refresh();
      expect(notifications, 1);
      controller.dispose();
      expect(provider.disposeCount, 0);
      pending.complete([_hito(1, '09:00')]);
      await refresh;
      expect(notifications, 1);
      expect(controller.data, isNull);
      await expectLater(controller.detail(1), throwsStateError);
      await controller.refresh();
      expect(provider.tours, ['910001']);
    },
  );

  testWidgets(
    'dos mapas visibles comparten polling hasta retirar ambos propietarios',
    (tester) async {
      final first = Object();
      final second = Object();
      controller.setMapVisible(first, true);
      await tester.pump();
      final reader = controller.bus;
      expect(provider.positionTours, ['910001']);
      controller.setMapVisible(second, true);
      await tester.pump();
      expect(controller.bus, same(reader));
      expect(provider.positionTours, ['910001']);
      await tester.pump(const Duration(seconds: 20));
      expect(provider.positionTours, hasLength(2));
      controller.setMapVisible(first, false);
      await tester.pump(const Duration(seconds: 20));
      expect(provider.positionTours, hasLength(3));
      controller.setMapVisible(second, false);
      await tester.pump(const Duration(minutes: 1));
      expect(provider.positionTours, hasLength(3));
      controller.setMapVisible(second, true);
      await tester.pump();
      expect(provider.positionTours, hasLength(4));
      controller.dispose();
      await tester.pump(const Duration(minutes: 1));
      expect(provider.positionTours, hasLength(4));
      expect(tester.takeException(), isNull);
    },
  );
}
