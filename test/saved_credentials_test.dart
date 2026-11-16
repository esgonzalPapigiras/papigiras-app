import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/auth/saved_credentials.dart';
import 'package:papigiras_app/design/pilo_login_form.dart';

// Synthetic credentials only. The channel is mocked: these tests never read
// device credentials, call the API, or persist a password on disk.
const _channel = MethodChannel('com.papigiras.lab/credentials');
const _rut = '99000011-5';
const _displayRut = '99.000.011-5';
const _personal = 'Ficticia-Personal';
const _destination = 'Sesión sintética';

void main() {
  late Map<String, Map<String, String>> vault;
  late List<MethodCall> mutations;

  setUp(() {
    vault = {};
    mutations = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          final arguments = Map<String, String>.from(call.arguments as Map);
          final role = arguments['role']!;
          switch (call.method) {
            case 'read':
              return vault[role];
            case 'contains':
              return vault.containsKey(role);
            case 'save':
              mutations.add(call);
              vault[role] = {
                'rut': arguments['rut']!,
                'password': arguments['password']!,
              };
              return null;
            case 'delete':
              mutations.add(call);
              vault.remove(role);
              return null;
            default:
              throw MissingPluginException();
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> open(
    WidgetTester tester, {
    PiloLoginRole role = PiloLoginRole.attorney,
    TargetPlatform platform = TargetPlatform.iOS,
    bool temporary = false,
    bool reject = false,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: ThemeData(platform: platform),
        home: PiloLoginForm(
          role: role,
          authenticate: (rut, password) async {
            if (reject) throw const FormatException('Credenciales incorrectas');
            return (
              destination: const Scaffold(body: Text(_destination)),
              temporaryPassword: temporary,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
  }

  Future<void> fillAndRemember(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField).first, _rut);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final role in PiloLoginRole.values) {
      for (final initial in [false, true]) {
        testWidgets(
          '${platform.name}/${role.name}: accepted ${initial ? 'initial' : 'personal'} password prefills after reopening',
          (tester) async {
            final password = initial ? '990000' : _personal;
            await open(
              tester,
              platform: platform,
              role: role,
              temporary: initial && role == PiloLoginRole.coordinator,
            );
            await fillAndRemember(tester, password);
            expect(vault, isEmpty, reason: 'Do not save before authentication');
            await submit(tester);
            if (initial) {
              expect(find.text('Continuar'), findsOneWidget);
              await tester.tap(find.text('Continuar'));
              await tester.pumpAndSettle();
            }
            expect(find.text(_destination), findsOneWidget);
            expect(vault[role.name], {'rut': _rut, 'password': password});
            expect(
              mutations.where((call) => call.method == 'save'),
              hasLength(1),
            );

            await open(tester, platform: platform, role: role);
            final fields = tester
                .widgetList<TextField>(find.byType(TextField))
                .toList();
            expect(fields.first.controller!.text, _displayRut);
            expect(fields.last.controller!.text, password);
            expect(fields.last.obscureText, isTrue);
            expect(
              tester
                  .widget<CheckboxListTile>(find.byType(CheckboxListTile))
                  .value,
              isTrue,
            );
            expect(
              mutations.where((call) => call.method == 'save'),
              hasLength(1),
              reason: 'Reading must not rewrite the credential',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('rejected login cannot overwrite an existing saved credential', (
    tester,
  ) async {
    vault['attorney'] = {'rut': _rut, 'password': _personal};
    await open(tester, reject: true);
    await tester.enterText(find.byType(TextField).last, 'Rechazada-Ficticia');
    await submit(tester);
    expect(find.text('Credenciales incorrectas'), findsOneWidget);
    expect(vault['attorney']!['password'], _personal);
    expect(mutations, isEmpty);
  });

  testWidgets(
    'unchecking remember removes only this role after accepted login',
    (tester) async {
      vault['attorney'] = {'rut': _rut, 'password': _personal};
      vault['passenger'] = {'rut': _rut, 'password': _personal};
      await open(tester);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      expect(vault.containsKey('attorney'), isTrue);
      await submit(tester);
      expect(find.text(_destination), findsOneWidget);
      expect(vault.containsKey('attorney'), isFalse);
      expect(vault.containsKey('passenger'), isTrue);
      await open(tester);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
    },
  );

  testWidgets('a slow secure read never overwrites typing', (tester) async {
    final read = Completer<Map<String, String>?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async => read.future);
    await open(tester);
    await tester.enterText(find.byType(TextField).first, '990000123');
    await tester.enterText(find.byType(TextField).last, 'Escrita-Ahora');
    read.complete({'rut': _rut, 'password': _personal});
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller!.text, '99.000.012-3');
    expect(fields.last.controller!.text, 'Escrita-Ahora');
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });

  testWidgets(
    'forget clears both fields and consent without signing out another role',
    (tester) async {
      vault['attorney'] = {'rut': _rut, 'password': _personal};
      vault['coordinator'] = {'rut': '99000022-K', 'password': 'Otra-Ficticia'};
      await open(tester);
      await tester.ensureVisible(find.byTooltip('Quitar clave guardada'));
      await tester.tap(find.byTooltip('Quitar clave guardada'));
      await tester.pumpAndSettle();
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
      expect(vault.containsKey('attorney'), isFalse);
      expect(vault.containsKey('coordinator'), isTrue);
      expect(find.text('Usar clave guardada'), findsNothing);
    },
  );

  testWidgets(
    'secure read failure leaves manual login available and explains it',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            throw PlatformException(code: 'secure-storage-unavailable');
          });
      await open(tester);
      expect(
        find.text(
          'No pudimos leer la contraseña guardada. Puedes ingresarla de nuevo.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).readOnly,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'secure save failure reports failure while keeping successful login',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            if (call.method == 'read') return null;
            throw PlatformException(code: 'secure-storage-unavailable');
          });
      await open(tester);
      await fillAndRemember(tester, _personal);
      await submit(tester);
      expect(find.text(_destination), findsOneWidget);
      expect(
        find.text(
          'La sesión se inició, pero no se pudo actualizar la contraseña guardada en este dispositivo.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'password update changes only preexisting matching identities',
    () async {
      vault['attorney'] = {'rut': _displayRut, 'password': _personal};
      vault['passenger'] = {
        'rut': '99.000.012-3',
        'password': 'Otro-Estudiante',
      };
      await SavedCredentials.updatePasswordForIdentity(
        roles: ['attorney'],
        rut: _rut,
        password: 'Ficticia-Nueva',
      );
      expect(vault['attorney'], {
        'rut': _displayRut,
        'password': 'Ficticia-Nueva',
      });
      expect(vault['passenger']!['password'], 'Otro-Estudiante');
      expect(vault.containsKey('coordinator'), isFalse);
      expect(mutations, hasLength(1));
    },
  );

  test(
    'guardian update preserves a different student password for the same RUT',
    () async {
      vault['attorney'] = {'rut': _rut, 'password': _personal};
      vault['passenger'] = {
        'rut': _displayRut,
        'password': 'Ficticia-Alumno-Independiente',
      };
      vault['coordinator'] = {
        'rut': _displayRut,
        'password': 'Ficticia-Coordinador-Independiente',
      };
      await SavedCredentials.updatePasswordForIdentity(
        roles: ['attorney'],
        rut: '990000115',
        password: 'Ficticia-Nueva',
      );
      expect(vault['attorney']!['password'], 'Ficticia-Nueva');
      expect(vault['passenger']!['password'], 'Ficticia-Alumno-Independiente');
      expect(
        vault['coordinator']!['password'],
        'Ficticia-Coordinador-Independiente',
      );
      expect(mutations, hasLength(1));
    },
  );

  test('unknown role cannot access secure storage', () async {
    await expectLater(
      SavedCredentials.read('administrator'),
      throwsArgumentError,
    );
    expect(mutations, isEmpty);
  });
}
