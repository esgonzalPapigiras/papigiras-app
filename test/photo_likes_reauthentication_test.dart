import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/dto/coordinator_session.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/likes/photo_likes_reauthentication.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

const tour = 910001;
const passenger = 910011;
ResponseAttorney account({
  int id = passenger,
  int tourId = tour,
  bool active = true,
  String token = 'synthetic-renewed',
}) => ResponseAttorney(
  passengerId: id,
  tourId: tourId,
  isActive: active,
  tokenKey: token,
  passengerIdentificacion: '99.000.011-5',
  passengerName: 'Persona Demo',
);

class _Provider extends CoordinatorProviders {
  int calls = 0;
  Future<ResponseAttorney?> Function()? result;
  @override
  Future<ResponseAttorney?> validateLoginUserFather(
    String rut,
    String password,
  ) {
    calls++;
    expect(rut, '99.000.011-5');
    expect(password, 'synthetic-password');
    return result?.call() ?? Future.value(account());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<SharedPreferences> seed({String role = 'father'}) async {
    SharedPreferences.setMockInitialValues({
      'token': 'synthetic-old',
      'tokenExpiry': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'loginData': jsonEncode(account(token: 'synthetic-old').toJson()),
      'isLoggedIn': true,
      'userRole': role,
      'labSessionRevision': LabSession.revision,
      'selectedTourId': tour,
      'unrelatedPreference': 'keep-me',
    });
    return SharedPreferences.getInstance();
  }

  setUp(() async {
    LabMode.useFixturesForTests(false);
    await seed();
  });

  Future<void> renew(ResponseAttorney login, {int? generation}) =>
      LabSession.renewAttorney(
        login: login,
        expectedPassengerId: passenger,
        expectedTourId: tour,
        expectedGeneration: generation ?? LabSession.generation,
      );

  test(
    'renewal changes generation and notifies only after complete credential',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final generation = LabSession.generation;
      final events = <String?>[];
      void listener() {
        events.add(prefs.getString('token'));
        expect(
          jsonDecode(prefs.getString('loginData')!)['tokenKey'],
          'synthetic-renewed',
        );
        expect(prefs.getString('userRole'), 'father');
      }

      LabSession.changed.addListener(listener);
      try {
        await renew(account());
      } finally {
        LabSession.changed.removeListener(listener);
      }
      expect(LabSession.generation, generation + 1);
      expect(events, ['synthetic-renewed']);
      expect(prefs.getString('unrelatedPreference'), 'keep-me');
      expect(prefs.getInt('selectedTourId'), tour);
      expect(prefs.getBool('isLoggedIn'), isTrue);
      expect(prefs.getString('userPassword'), isNull);
    },
  );

  test(
    'fresh family login notifies once after complete identity is saved',
    () async {
      final prefs = await SharedPreferences.getInstance();
      var events = 0;
      void listener() {
        events++;
        expect(prefs.getString('token'), 'synthetic-renewed');
        expect(prefs.getString('userRole'), 'father');
        expect(prefs.getBool('isLoggedIn'), isTrue);
        expect(
          jsonDecode(prefs.getString('loginData')!)['passengerId'],
          passenger,
        );
      }

      LabSession.changed.addListener(listener);
      try {
        await LabSession.savePassenger(account(), 'attorney');
      } finally {
        LabSession.changed.removeListener(listener);
      }
      expect(events, 1);
    },
  );

  test(
    'fresh coordinator login notifies once after complete identity is saved',
    () async {
      final prefs = await SharedPreferences.getInstance();
      var events = 0;
      void listener() {
        events++;
        expect(prefs.getString('token'), 'synthetic-coordinator');
        expect(prefs.getString('userRole'), 'coordinator');
        expect(prefs.getBool('isLoggedIn'), isTrue);
        expect(
          jsonDecode(prefs.getString('coordinatorData')!)['coordinatorId'],
          910001,
        );
      }

      LabSession.changed.addListener(listener);
      try {
        await LabSession.saveCoordinator(
          const CoordinatorLogin(
            coordinatorId: 910001,
            rut: '99000001-8',
            name: 'Coordinador',
            lastname: 'Demo',
            mustChangePassword: false,
            token: 'synthetic-coordinator',
          ),
        );
      } finally {
        LabSession.changed.removeListener(listener);
      }
      expect(events, 1);
    },
  );

  test(
    'wrong passenger, tour, disabled account and empty token never replace login',
    () async {
      final generation = LabSession.generation;
      for (final invalid in [
        account(id: 910012),
        account(tourId: 910002),
        account(active: false),
        account(token: ''),
      ]) {
        await expectLater(renew(invalid), throwsFormatException);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), 'synthetic-old');
      expect(LabSession.generation, generation);
    },
  );

  test('role or current saved owner changes reject renewal', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', 'coordinator');
    await expectLater(renew(account()), throwsFormatException);
    await prefs.setString('userRole', 'father');
    await prefs.setString(
      'loginData',
      jsonEncode(account(id: 910012).toJson()),
    );
    await expectLater(renew(account()), throwsFormatException);
    expect(prefs.getString('token'), 'synthetic-old');
  });

  test(
    'late authentication after logout cannot resurrect signed-out session',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final generation = LabSession.generation;
      await LabSession.clear(prefs);
      await expectLater(
        renew(account(), generation: generation),
        throwsFormatException,
      );
      expect(prefs.getString('token'), isNull);
      expect(prefs.getBool('isLoggedIn'), isFalse);
    },
  );

  test(
    'real provider rejected unauthenticated login preserves existing credential',
    () async {
      final generation = LabSession.generation;
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((request) async {
            expect(request.url.path, '/app/services/lab/mobile/login');
            expect(request.headers.containsKey('authorization'), isFalse);
            expect(jsonDecode(request.body)['role'], 'attorney');
            return http.Response('', 401);
          }),
        ),
      );
      addTearDown(provider.dispose);
      await expectLater(
        provider.validateLoginUserFather('99.000.011-5', 'wrong'),
        throwsException,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), 'synthetic-old');
      expect(prefs.getBool('isLoggedIn'), isTrue);
      expect(LabSession.generation, generation);
    },
  );

  Future<void> host(
    WidgetTester tester,
    CoordinatorProviders provider,
    ValueChanged<Future<bool>> capture, {
    int tourId = tour,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open'),
              onPressed: () => capture(
                reauthenticatePhotoLikes(
                  context,
                  tourId: tourId,
                  provider: provider,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('photo-likes-reauth-password')),
      'synthetic-password',
    );
    await tester.tap(find.byKey(const Key('photo-likes-reauth-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cancel keeps screen and credential, exposes read-only RUT and native autofill',
    (tester) async {
      final provider = _Provider();
      addTearDown(provider.dispose);
      late Future<bool> result;
      await host(tester, provider, (value) => result = value);
      expect(find.text('Activa tus Me gusta'), findsOneWidget);
      final rut = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('photo-likes-reauth-rut')),
          matching: find.byType(TextField),
        ),
      );
      final password = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('photo-likes-reauth-password')),
          matching: find.byType(TextField),
        ),
      );
      expect(rut.readOnly, isTrue);
      expect(rut.controller!.text, '99.000.011-5');
      expect(rut.autofillHints, contains(AutofillHints.username));
      expect(password.autofillHints, contains(AutofillHints.password));
      expect(password.obscureText, isTrue);
      await tester.tap(find.byKey(const Key('photo-likes-reauth-cancel')));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
      expect(provider.calls, 0);
      expect(
        (await SharedPreferences.getInstance()).getString('token'),
        'synthetic-old',
      );
      expect(find.byKey(const Key('open')), findsOneWidget);
    },
  );

  testWidgets('valid password renews same family session and closes in place', (
    tester,
  ) async {
    final provider = _Provider();
    addTearDown(provider.dispose);
    late Future<bool> result;
    await host(tester, provider, (value) => result = value);
    await submit(tester);
    expect(await result, isTrue);
    expect(provider.calls, 1);
    expect(find.byKey(const Key('photo-likes-reauth-dialog')), findsNothing);
    expect(find.byKey(const Key('open')), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('token'),
      'synthetic-renewed',
    );
    expect(
      (await SharedPreferences.getInstance()).getString('userPassword'),
      isNull,
    );
  });

  testWidgets('wrong password stays recoverable without logging out', (
    tester,
  ) async {
    final provider = _Provider()
      ..result = () => Future.error(StateError('synthetic denied'));
    addTearDown(provider.dispose);
    late Future<bool> result;
    await host(tester, provider, (value) => result = value);
    await submit(tester);
    expect(
      find.text(
        'No pudimos confirmar tu contraseña. Revísala e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('token'),
      'synthetic-old',
    );
    await tester.tap(find.byKey(const Key('photo-likes-reauth-cancel')));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('wrong returned identity is rejected before any session update', (
    tester,
  ) async {
    final provider = _Provider()..result = () async => account(id: 910012);
    addTearDown(provider.dispose);
    late Future<bool> result;
    await host(tester, provider, (value) => result = value);
    await submit(tester);
    expect(
      (await SharedPreferences.getInstance()).getString('token'),
      'synthetic-old',
    );
    expect(find.byKey(const Key('photo-likes-reauth-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('photo-likes-reauth-cancel')));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets(
    'logout during pending authentication cannot replace new session',
    (tester) async {
      final gate = Completer<ResponseAttorney?>();
      final provider = _Provider()..result = () => gate.future;
      addTearDown(provider.dispose);
      late Future<bool> result;
      await host(tester, provider, (value) => result = value);
      await tester.enterText(
        find.byKey(const Key('photo-likes-reauth-password')),
        'synthetic-password',
      );
      await tester.tap(find.byKey(const Key('photo-likes-reauth-submit')));
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      await LabSession.clear(prefs);
      gate.complete(account());
      await tester.pumpAndSettle();
      expect(prefs.getString('token'), isNull);
      expect(prefs.getBool('isLoggedIn'), isFalse);
      expect(
        find.text(
          'Tu sesión cambió. Cierra esta ventana y vuelve a intentarlo.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('photo-likes-reauth-cancel')));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    },
  );

  testWidgets('coordinator and another tour cannot open family recovery', (
    tester,
  ) async {
    final provider = _Provider();
    addTearDown(provider.dispose);
    late Future<bool> result;
    await host(tester, provider, (value) => result = value, tourId: 910002);
    expect(await result, isFalse);
    expect(find.byKey(const Key('photo-likes-reauth-dialog')), findsNothing);
    await (await SharedPreferences.getInstance()).setString(
      'userRole',
      'coordinator',
    );
    await host(tester, provider, (value) => result = value);
    expect(await result, isFalse);
    expect(find.byKey(const Key('photo-likes-reauth-dialog')), findsNothing);
    expect(provider.calls, 0);
  });

  testWidgets('simultaneous triggers share exactly one confirmation dialog', (
    tester,
  ) async {
    final provider = _Provider();
    addTearDown(provider.dispose);
    final results = <Future<bool>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open'),
              onPressed: () {
                results.add(
                  reauthenticatePhotoLikes(
                    context,
                    tourId: tour,
                    provider: provider,
                  ),
                );
                results.add(
                  reauthenticatePhotoLikes(
                    context,
                    tourId: tour,
                    provider: provider,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-likes-reauth-dialog')), findsOneWidget);
    expect(identical(results[0], results[1]), isTrue);
    await tester.tap(find.byKey(const Key('photo-likes-reauth-cancel')));
    await tester.pumpAndSettle();
    expect(await Future.wait(results), [false, false]);
  });
}
