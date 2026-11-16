import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorTourSelection.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/listPassenger.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/page_navigation.dart';

import 'support/map_tiles.dart';

void main() {
  testWidgets(
    'selection retains the existing detail, saved context and dashboard flow',
    (tester) async {
      LabMode.useFixturesForTests(true);
      LabFixtures.reset();
      LabMapTiles.testProvider = TestMapTileProvider.new;
      addTearDown(() => LabMapTiles.testProvider = null);
      SharedPreferences.setMockInitialValues({});
      addTearDown(() => LabMode.useFixturesForTests(false));
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocationService(),
          child: MaterialApp(
            theme: ThemeData(pageTransitionsTheme: papiPageTransitions),
            home: const CoordinatorTourSelectionScreen(
              coordinator: LabFixtures.coordinator,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(formatSchoolName(LabFixtures.tour.clientName)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TravelCoordinatorDashboard), findsOneWidget);
      expect(find.byType(CoordinatorTourSelectionScreen), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('selectedTourId'), LabFixtures.tour.tourId);
      final login =
          jsonDecode(prefs.getString('loginData')!) as Map<String, dynamic>;
      final dashboard = tester.widget<TravelCoordinatorDashboard>(
        find.byType(TravelCoordinatorDashboard),
      );
      expect(dashboard.login.tourSalesId, LabFixtures.tour.tourId);
      expect(login, dashboard.login.toJson());
      expect(find.byKey(const ValueKey('home-action-medical')), findsNothing);
      final roster = find.byKey(const ValueKey('home-passenger-list'));
      await tester.ensureVisible(roster);
      await tester.pumpAndSettle();
      await tester.tap(roster);
      await tester.pumpAndSettle();
      expect(find.byType(ListPassengerCoordScreen), findsOneWidget);
      // Pilo groups PDF viewing/sharing under the passenger medical action.
      final medical = find.byKey(const ValueKey('roster-medical-1'));
      expect(medical, findsOneWidget);
      expect(tester.widget<TextButton>(medical).onPressed, isNotNull);
      expect(find.text('Ficha médica'), findsWidgets);
      final rosterScreen = tester.widget<ListPassengerCoordScreen>(
        find.byType(ListPassengerCoordScreen),
      );
      expect(rosterScreen.login.tourSalesId, dashboard.login.tourSalesId);
      Navigator.of(tester.element(find.byType(ListPassengerCoordScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(TravelCoordinatorDashboard), findsOneWidget);
      expect(jsonDecode(prefs.getString('loginData')!), login);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
