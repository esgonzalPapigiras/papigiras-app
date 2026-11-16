import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_family_gallery_preview.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/maps/trip_map_controller.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';

const picture =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC';

TripMapData rows(int count) => TripMapData.from([
  for (var i = 0; i < count; i++)
    ConsolidatedTourSalesDTO(
      binnacleDetailId: 910011 + i,
      binnacleTitulo: 'Recuerdo de ejemplo',
      binnacleDescripcion: '',
      binnacleUbicacion: '',
      binnacleNotaCierre: '',
      binnacleLatitud: '',
      binnacleLongitud: '',
      binnacleHora: '12:00',
      binnacleFecha: '2026-11-${10 + i}',
      author: null,
      canModify: false,
    ),
]);

class PreviewController extends TripMapController {
  PreviewController(this.value) : super(tourCode: 910001);
  TripMapData value;
  final requested = <int>[];
  List<String> images = const [];
  Completer<DetailHitoList>? pending;
  bool fail = false;
  @override
  TripMapData get data => value;
  @override
  Future<DetailHitoList> detail(int id, {bool retry = false}) async {
    requested.add(id);
    if (pending != null) return pending!.future;
    if (fail) throw StateError('Fixture');
    return DetailHitoList(images: images);
  }

  void notifySelection() => notifyListeners();
}

Widget screen(PreviewController controller, {VoidCallback? onOpen}) =>
    MaterialApp(
      theme: PiloFamilyTheme.theme(ThemeData()),
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: PiloFamilyGalleryPreview(
            controller: controller,
            onOpen: onOpen ?? () {},
          ),
        ),
      ),
    );

Future<void> settleImages(WidgetTester tester) async {
  // ui.instantiateImageCodec/PNG thumbnail work runs outside fake async.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump();
}

void main() {
  testWidgets('uses three real photos and both gallery actions', (
    tester,
  ) async {
    final c = PreviewController(rows(2))
      ..images = [picture, picture, picture, picture];
    addTearDown(c.dispose);
    var opens = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(screen(c, onOpen: () => opens++));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await settleImages(tester);
    expect(find.byType(Image), findsNWidgets(3));
    expect(c.requested, [910012]);
    expect(find.text('+24'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('family-gallery-photo-0')));
    await tester.tap(find.byKey(const ValueKey('family-gallery-open')));
    expect(opens, 2);
    c.notifySelection();
    await tester.pump();
    expect(c.requested, [910012]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bounds reads and does not claim entire gallery is empty', (
    tester,
  ) async {
    final c = PreviewController(rows(9));
    addTearDown(c.dispose);
    await tester.pumpWidget(screen(c));
    await tester.pumpAndSettle();
    expect(c.requested.length, 6);
    expect(find.text('Explora las fotos de la gira.'), findsOneWidget);
    expect(find.text('Las fotos de la gira aparecerán aquí.'), findsNothing);
  });

  testWidgets('no-data and failed image states are honest and reachable', (
    tester,
  ) async {
    final c = PreviewController(rows(0));
    addTearDown(c.dispose);
    await tester.pumpWidget(screen(c));
    // Empty initial data is considered completely checked.
    await tester.pumpAndSettle();
    expect(find.text('Las fotos de la gira aparecerán aquí.'), findsOneWidget);
    final broken = PreviewController(rows(1))..images = ['bad'];
    addTearDown(broken.dispose);
    await tester.pumpWidget(screen(broken));
    await tester.pumpAndSettle();
    expect(find.text('Abre la galería para cargar las fotos.'), findsOneWidget);
    expect(find.byKey(const ValueKey('family-gallery-open')), findsOneWidget);
  });

  testWidgets('retired controller results never leak to new trip', (
    tester,
  ) async {
    final old = PreviewController(rows(1))
      ..pending = Completer<DetailHitoList>();
    final next = PreviewController(rows(0));
    addTearDown(old.dispose);
    addTearDown(next.dispose);
    await tester.pumpWidget(screen(old));
    expect(find.text('Cargando fotos…'), findsOneWidget);
    await tester.pumpWidget(screen(next));
    old.pending!.complete(DetailHitoList(images: [picture]));
    await settleImages(tester);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Las fotos de la gira aparecerán aquí.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-flight result after closing home is ignored', (tester) async {
    final c = PreviewController(rows(1))..pending = Completer<DetailHitoList>();
    addTearDown(c.dispose);
    await tester.pumpWidget(screen(c));
    await tester.pumpWidget(const SizedBox.shrink());
    c.pending!.complete(DetailHitoList(images: [picture]));
    await settleImages(tester);
    expect(tester.takeException(), isNull);
  });
}
