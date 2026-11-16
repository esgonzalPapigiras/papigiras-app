import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class _Provider extends CoordinatorProviders {
  int photosRead = 0;
  int passwordWrites = 0;
  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async {
    expect(rut, 'LAB-910011');
    expect(tour, '910001');
    photosRead++;
    return Responseimagepassenger(image: '');
  }

  @override
  Future<void> changeAttorneyPassword(String current, String next) async {
    passwordWrites++;
  }
}

void main() {
  late _Provider provider;
  final selected = <String>[];
  int photoPicks = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'isLoggedIn': true,
      'token': 'fixture-only',
    });
    provider = _Provider();
    selected.clear();
    photoPicks = 0;
  });
  tearDown(() => provider.dispose());

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    double width = 393,
  }) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: PiloFamilyTheme.theme(ThemeData()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppDrawerFather.showPiloSheet(
                context,
                login: ResponseAttorney(
                  passengerId: 910011,
                  tourId: 910001,
                  passengerIdentificacion: 'LAB-910011',
                  passengerName: 'SOFÍA',
                  passengerApellidos: 'EJEMPLO LAB',
                ),
                photoProvider: provider,
                passwordProvider: provider,
                pickImage: () async {
                  photoPicks++;
                  return null;
                },
                onTripDetails: () => selected.add('trip'),
                onMedical: () => selected.add('medical'),
                onDocuments: () => selected.add('documents'),
                onCrew: () => selected.add('crew'),
              ),
              child: const Text('Abrir menú fixture'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir menú fixture'));
    await tester.pumpAndSettle();
  }

  testWidgets('five approved destinations have ordered readable rows', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Tu gira'), findsOneWidget);
    double previousY = 0;
    for (final action in ['trip', 'medical', 'documents', 'crew', 'profile']) {
      final row = find.byKey(ValueKey('pilo-family-menu-$action'));
      expect(row, findsOneWidget);
      final bounds = tester.getRect(row);
      expect(bounds.top, greaterThan(previousY));
      expect(bounds.height, greaterThanOrEqualTo(48));
      previousY = bounds.top;
    }
    expect(provider.photosRead, 0);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['trip', 'medical', 'documents', 'crew']) {
    testWidgets(
      '$action dismisses menu and uses current destination callback',
      (tester) async {
        await open(tester);
        await tester.tap(find.byKey(ValueKey('pilo-family-menu-$action')));
        await tester.pumpAndSettle();
        expect(selected, [action]);
        expect(
          find.byKey(const ValueKey('pilo-family-menu-sheet')),
          findsNothing,
        );
        expect(
          (await SharedPreferences.getInstance()).getString('token'),
          'fixture-only',
        );
      },
    );
  }

  testWidgets('close returns without changes or navigation', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Cerrar menú'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.byKey(const ValueKey('pilo-family-menu-sheet')), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString('token'),
      'fixture-only',
    );
  });

  testWidgets(
    'guardian student profile view retains photo editor, guardian password and support actions',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('pilo-family-menu-profile')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pilo-family-profile-sheet')),
        findsOneWidget,
      );
      expect(find.text('Sofía Ejemplo Lab'), findsOneWidget);
      expect(provider.photosRead, 1);
      for (final action in ['password', 'contact', 'report', 'logout']) {
        expect(find.byKey(ValueKey('family-menu-$action')), findsOneWidget);
      }
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      expect(photoPicks, 1);
      await tester.tap(find.byKey(const ValueKey('family-menu-password')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('password-current')), findsOneWidget);
      expect(
        find.textContaining(
          'Esta contraseña es sólo para tu acceso como apoderado.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('password-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pilo-family-profile-sheet')),
        findsOneWidget,
      );
      expect(provider.passwordWrites, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile logout clears mocked session and entire menu route', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('pilo-family-menu-profile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('family-menu-logout')),
    );
    await tester.tap(find.byKey(const ValueKey('family-menu-logout')));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pilo-family-profile-sheet')),
      findsNothing,
    );
    expect((await SharedPreferences.getInstance()).getString('token'), isNull);
  });

  for (final scale in [2.0, 3.0]) {
    testWidgets('320px and ${scale}x text keeps menu and profile scrollable', (
      tester,
    ) async {
      await open(tester, width: 320, scale: scale);
      final profile = find.byKey(const ValueKey('pilo-family-menu-profile'));
      await tester.ensureVisible(profile);
      await tester.pumpAndSettle();
      await tester.tap(profile);
      await tester.pumpAndSettle();
      for (final action in ['password', 'contact', 'report', 'logout']) {
        await tester.ensureVisible(find.byKey(ValueKey('family-menu-$action')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
