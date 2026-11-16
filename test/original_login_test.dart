import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papigiras_app/design/pilo_login_form.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.papigiras.lab/credentials'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.papigiras.lab/credentials'),
          null,
        );
  });

  for (final role in PiloLoginRole.values) {
    testWidgets(
      '${role.name} formats RUT while preserving login identity and reminder flow',
      (tester) async {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: PiloLoginForm(
              role: role,
              authenticate: (rut, password) async {
                calls++;
                expect(rut, '99000011-5');
                expect(password, '990000');
                return (
                  destination: const Scaffold(body: Text('Sesión de prueba')),
                  temporaryPassword: role == PiloLoginRole.coordinator,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '990000115');
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '99.000.011-5',
        );
        await tester.enterText(find.byType(TextField).last, '990000');
        await tester.ensureVisible(find.text('Ingresar'));
        await tester.tap(find.text('Ingresar'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.text('Continuar'), findsOneWidget);
        expect(find.text('Sesión de prueba'), findsNothing);
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(find.text('Sesión de prueba'), findsOneWidget);
        expect(find.byType(PiloLoginForm), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('saved RUT is formatted without changing saved credentials', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const channel = MethodChannel('com.papigiras.lab/credentials');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'contains') return true;
      if (call.method == 'read') {
        return {'rut': '99000011-5', 'password': 'Ficticia-Personal'};
      }
      fail('Loading credentials must not save or delete them');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: PiloLoginForm(
          role: PiloLoginRole.coordinator,
          authenticate: (_, _) async =>
              (destination: const SizedBox(), temporaryPassword: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller!.text, '99.000.011-5');
    expect(fields.last.controller!.text, 'Ficticia-Personal');
    expect(fields.last.obscureText, isTrue);
    expect(find.textContaining('iPhone'), findsNothing);
    expect(find.text('Guardar contraseña en este dispositivo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'Apoderado': 'RUT del alumno',
    'Alumno': 'RUT del alumno',
    'Coordinador': 'Tu RUT',
  }.entries) {
    testWidgets(
      'original role access ${entry.key} is empty and has password visibility',
      (tester) async {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(home: WelcomeScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text(entry.value), findsOneWidget);
        expect(find.byType(AutofillGroup), findsOneWidget);
        expect(
          tester
              .widget<AutofillGroup>(find.byType(AutofillGroup))
              .onDisposeAction,
          AutofillContextAction.cancel,
        );
        for (final field in tester.widgetList<TextField>(
          find.byType(TextField),
        )) {
          expect(field.controller!.text, isEmpty);
        }
        expect(find.text('Ingresar'), findsOneWidget);
        expect(find.textContaining('Clave local'), findsNothing);
        expect(find.textContaining('Cuenta ficticia'), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isTrue,
        );
        await tester.tap(find.byIcon(Icons.visibility));
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isFalse,
        );
        if (entry.key == 'Alumno') {
          await tester.tap(find.text('Soy apoderado'));
          await tester.pumpAndSettle();
          expect(
            find.text('Acompaña la gira de tu estudiante.'),
            findsOneWidget,
          );
        }
        await tester.tap(find.byTooltip('Volver a elegir perfil'));
        await tester.pumpAndSettle();
        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'secure storage remembers accepted passwords including initial ones with consent',
    (tester) async {
      const channel = MethodChannel('com.papigiras.lab/credentials');
      final messenger = tester.binding.defaultBinaryMessenger;
      final saved = <Object?>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'contains') return false;
        if (call.method == 'save') saved.add(call.arguments);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final password in ['rechazada', '990000', 'Ficticia-Personal']) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(password),
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: PiloLoginForm(
              role: PiloLoginRole.attorney,
              authenticate: (rut, password) async {
                if (password == 'rechazada') {
                  throw const FormatException('Credenciales incorrectas');
                }
                return (
                  destination: const Scaffold(body: Text('Sesión de prueba')),
                  temporaryPassword: false,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isFalse,
        );
        await tester.enterText(find.byType(TextField).first, '99.000.011-5');
        await tester.enterText(find.byType(TextField).last, password);
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.ensureVisible(find.text('Ingresar'));
        await tester.tap(find.text('Ingresar'));
        await tester.pumpAndSettle();

        if (password == 'rechazada') {
          expect(find.text('Credenciales incorrectas'), findsOneWidget);
          expect(saved, isEmpty);
        } else {
          if (password == '990000') {
            await tester.tap(find.text('Continuar'));
            await tester.pumpAndSettle();
          }
          expect(find.text('Sesión de prueba'), findsOneWidget);
          if (password == '990000') expect(saved, hasLength(1));
        }
      }
      expect(saved, [
        {'role': 'attorney', 'rut': '99000011-5', 'password': '990000'},
        {
          'role': 'attorney',
          'rut': '99000011-5',
          'password': 'Ficticia-Personal',
        },
      ]);
    },
  );

  for (final role in ['attorney', 'passenger', 'coordinator']) {
    test(
      '$role uses scoped local JSON login without URL credentials or operator privileges',
      () async {
        var calls = 0;
        final provider = CoordinatorProviders(
          client: LabApiClient(
            transport: MockClient((request) async {
              calls++;
              expect(request.method, 'POST');
              expect(request.url, LabApi.uri('/app/services/lab/mobile/login'));
              expect(request.url.hasQuery, isFalse);
              expect(request.headers['authorization'], isNull);
              expect(jsonDecode(request.body), {
                'role': role,
                'rut': '99.000.011-5',
                'password': '990000',
              });
              return http.Response(
                jsonEncode(
                  role == 'coordinator'
                      ? LabFixtures.coordinator.toJson()
                      : LabFixtures.passenger.toJson(),
                ),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        );
        addTearDown(provider.dispose);
        if (role == 'coordinator') {
          final login = await provider.loginCoordinator(
            '99.000.011-5',
            '990000',
          );
          await LabSession.saveCoordinator(login);
        } else {
          final login = role == 'attorney'
              ? await provider.validateLoginUserFather('99.000.011-5', '990000')
              : await provider.validateLoginUserPassenger(
                  '99.000.011-5',
                  '990000',
                );
          await LabSession.savePassenger(login!, role);
        }
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('labSessionRevision'), LabSession.revision);
        expect(prefs.getString('userPassword'), isNull);
        expect(prefs.getString('userRut'), isNull);
        expect(prefs.getString('token'), LabFixtures.token);
        expect(calls, 1);
      },
    );
  }

  test(
    'failed local login shows useful error and does not create a session',
    () async {
      final provider = CoordinatorProviders(
        client: LabApiClient(
          transport: MockClient((_) async => http.Response('{}', 401)),
        ),
      );
      addTearDown(provider.dispose);
      await expectLater(
        provider.validateLoginUserFather('990000115', 'wrong'),
        throwsA(
          predicate(
            (e) => e.toString().contains('Revisa el RUT y la contraseña'),
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), isNull);
      expect(prefs.getString('loginData'), isNull);
    },
  );
}
