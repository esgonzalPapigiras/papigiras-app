import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/maps/trip_binnacle_timeline.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class AuthorProvider extends CoordinatorProviders {
  int calls = 0;
  bool hasAuthor = true, hasPhoto = true;
  @override
  Future<List<ConsolidatedTourSalesDTO>> getBinnacle(String tour) async => [
    for (var i = 0; i < 2; i++)
      ConsolidatedTourSalesDTO(
        binnacleDetailId: 910003 + i,
        binnacleTitulo: 'Visita de prueba $i',
        binnacleDescripcion: 'Descripción ficticia',
        binnacleUbicacion: 'Santiago LAB',
        binnacleNotaCierre: '',
        binnacleLatitud: '-33.4',
        binnacleLongitud: '-70.6',
        binnacleHora: '12:0$i',
        binnacleFecha: '2026-10-27',
        canModify: true,
        author: hasAuthor
            ? const HitoAuthor(
                coordinatorId: 910001,
                name: 'Alex Demostración',
                lastname: 'LAB',
              )
            : null,
      ),
  ];
  @override
  Future<DetailHitoList> getHitoComplete(String id, String tour) async =>
      DetailHitoList();
  @override
  Future<Uint8List?> getHitoAuthorPicture(int id, int tour) async {
    expect(tour, 910001);
    expect(id, anyOf(910003, 910004));
    calls++;
    return hasPhoto ? TileProvider.transparentImage : null;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> show(
    WidgetTester tester,
    AuthorProvider provider, {
    double width = 393,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: TripBinnacleTimeline(
            tourId: 910001,
            provider: provider,
            onOpenDetail: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'photo and name in footer use the actual author and share one download',
    (tester) async {
      final provider = AuthorProvider();
      await show(tester, provider);
      expect(provider.calls, 1);
      expect(find.text('Autor: Alex Demostración LAB'), findsNothing);
      expect(find.text('Alex Demostración LAB'), findsNWidgets(2));
      expect(find.byType(ClipOval), findsNWidgets(2));
      expect(find.byType(Image), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing author is historical and does not borrow the logged-in profile',
    (tester) async {
      final provider = AuthorProvider()..hasAuthor = false;
      await show(tester, provider);
      expect(provider.calls, 0);
      expect(find.text('Registro histórico'), findsNWidgets(2));
      expect(find.byIcon(Icons.person_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing photo keeps real name and controls at320 and large text',
    (tester) async {
      final provider = AuthorProvider()..hasPhoto = false;
      await show(tester, provider, width: 320, scale: 1.6);
      expect(find.text('Alex Demostración LAB'), findsNWidgets(2));
      expect(find.byIcon(Icons.person_rounded), findsNWidgets(2));
      expect(find.byTooltip('Ampliar hito'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
