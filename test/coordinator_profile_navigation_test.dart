import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/map_tiles.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/coordinator/coordinatorProfile.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';

import 'support/map_tiles.dart';

void main() {
  late TourSales tour;

  setUp(() async {
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    LabMapTiles.testProvider = TestMapTileProvider.new;
    await (await SharedPreferences.getInstance()).clear();
    tour = TourSales.fromCoordinatorTour(
      coordinator: LabFixtures.coordinator,
      tour: LabFixtures.tour,
    );
  });

  tearDown(() {
    LabMapTiles.testProvider = null;
    LabMode.useFixturesForTests(false);
  });

  Future<void> showDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // An empty mock session prevents the synthetic tracking service from
    // starting timers or transport; all displayed profile data are fixtures.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocationService(),
        child: MaterialApp(home: TravelCoordinatorDashboard(login: tour)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TravelCoordinatorDashboard), findsOneWidget);
    for (final tab in ['home', 'diary', 'gallery', 'documents']) {
      expect(find.byKey(ValueKey('family-tab-$tab')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  }

  Finder dashboardScaffold() => find.byWidgetPredicate(
    (widget) => widget is Scaffold && widget.endDrawer is CoordinatorEndDrawer,
  );

  String displayName() => formatStudentName(tour.tourTripulationNameId, null);

  Finder drawerText(String text) => find.descendant(
    of: find.byType(CoordinatorEndDrawer),
    matching: find.text(text),
  );

  Future<void> openTripDetails(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('coordinator-trip-details')));
    await tester.pumpAndSettle();
  }

  Future<void> openAccountMenu(WidgetTester tester) async {
    await openTripDetails(tester);
    final menu = find.byKey(const ValueKey('home-account-menu'));
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }

  Future<void> expectProfileAndReturn(
    WidgetTester tester,
    State<StatefulWidget> dashboardState,
    ScaffoldState scaffoldState,
  ) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CoordinatorProfileScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PiloSectionBar, 'Mi perfil'), findsOneWidget);
    expect(find.text('Cambiar contraseña'), findsOneWidget);
    expect(scaffoldState.isEndDrawerOpen, isFalse);
    // The destination retains its own photo editor, avoiding another profile
    // push when its avatar is used to edit the photo.
    final avatar = tester.widget<ProfilePhotoAvatar>(
      find.byType(ProfilePhotoAvatar),
    );
    expect(avatar.onOpenProfile, isNull);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.byType(CoordinatorProfileScreen), findsNothing);
    expect(find.byType(TravelCoordinatorDashboard), findsOneWidget);
    expect(
      identical(
        tester.state(find.byType(TravelCoordinatorDashboard)),
        dashboardState,
      ),
      isTrue,
    );
    expect(scaffoldState.isEndDrawerOpen, isFalse);
    expect(find.byTooltip('Abrir mi perfil'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  }

  for (final entry in ['nombre', 'RUT', 'foto', 'Mi perfil']) {
    testWidgets(
      'drawer $entry opens profile and returns to the same dashboard',
      (tester) async {
        await showDashboard(tester);
        final dashboardState = tester.state(
          find.byType(TravelCoordinatorDashboard),
        );
        final scaffoldState = tester.state<ScaffoldState>(dashboardScaffold());
        await openAccountMenu(tester);
        expect(scaffoldState.isEndDrawerOpen, isTrue);
        if (entry == 'nombre') {
          await tester.tap(drawerText(displayName()));
        } else if (entry == 'RUT') {
          await tester.tap(drawerText(tour.tourTripulationIdentificationId));
        } else if (entry == 'foto') {
          final avatar = find.descendant(
            of: find.byType(CoordinatorEndDrawer),
            matching: find.byType(CircleAvatar),
          );
          await tester.tapAt(tester.getCenter(avatar));
        } else {
          await tester.tap(drawerText('Mi perfil'));
        }
        await expectProfileAndReturn(tester, dashboardState, scaffoldState);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  for (final entry in ['foto', 'nombre en información de la gira']) {
    testWidgets('dashboard $entry opens profile without rebuilding the trip', (
      tester,
    ) async {
      await showDashboard(tester);
      final dashboardState = tester.state(
        find.byType(TravelCoordinatorDashboard),
      );
      final scaffoldState = tester.state<ScaffoldState>(dashboardScaffold());
      if (entry == 'foto') {
        // The camera is a separate touch target over the avatar's lower right.
        final avatar = find.byTooltip('Abrir mi perfil');
        await tester.tapAt(tester.getTopLeft(avatar) + const Offset(16, 16));
      } else {
        await openTripDetails(tester);
        await tester.tap(find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(displayName()),
        ));
      }
      await expectProfileAndReturn(tester, dashboardState, scaffoldState);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
