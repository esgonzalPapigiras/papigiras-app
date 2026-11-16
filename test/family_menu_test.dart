import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/lab/offline.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';
import 'package:papigiras_app/utils/profile_photo_avatar.dart';

class _Photos extends CoordinatorProviders {
  final calls = <List<String>>[];
  int writes = 0;
  int passwordWrites = 0;
  @override
  Future<void> changeAttorneyPassword(String current, String next) async {
    passwordWrites++;
  }

  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async {
    calls.add([rut, tour]);
    return Responseimagepassenger(
      image: base64Encode(
        (await rootBundle.load('assets/profile.jpg')).buffer.asUint8List(),
      ),
    );
  }

  @override
  Future<void> addHitoFotoPassenger(
    String passenger,
    String tour,
    XFile file,
  ) async {
    writes++;
  }
}

void main() {
  late _Photos provider;
  late GlobalKey<ScaffoldState> scaffold;
  late GlobalKey<NavigatorState> navigator;
  int picks = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'token': 'fixture-only',
      'userRut': 'LAB-910011',
      'userPassword': 'fixture-only',
      'isLoggedIn': true,
    });
    provider = _Photos();
    scaffold = GlobalKey<ScaffoldState>();
    navigator = GlobalKey<NavigatorState>();
    picks = 0;
  });
  tearDown(() => provider.dispose());
  Future<void> show(
    WidgetTester tester, {
    double width = 393,
    double scale = 1,
    bool longName = false,
    bool allowPasswordChange = true,
  }) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final login = ResponseAttorney(
      passengerId: 910011,
      tourId: 910001,
      passengerName: longName
          ? '  SOFÍA ALEJANDRA DE LA DEMOSTRACIÓN '
          : 'SOFÍA',
      passengerApellidos: longName
          ? 'APELLIDO EXTENSO DE EJEMPLO LAB'
          : 'EJEMPLO LAB',
      passengerIdentificacion: 'LAB-910011',
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        scaffoldMessengerKey: labMessengerKey,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          key: scaffold,
          body: const Center(child: Text('Página de prueba')),
          endDrawer: AppDrawerFather(
            login: login,
            allowPasswordChange: allowPasswordChange,
            photoProvider: provider,
            passwordProvider: provider,
            pickImage: () async {
              picks++;
              return null;
            },
          ),
        ),
      ),
    );
    scaffold.currentState!.openEndDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'contact and report retain isolated operation and current session',
    (tester) async {
      await show(tester);
      for (final key in ['family-menu-contact', 'family-menu-report']) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'LAB: contacto simulado. No se abrió ninguna aplicación externa.',
          ),
          findsOneWidget,
        );
        expect(
          (await SharedPreferences.getInstance()).getString('token'),
          'fixture-only',
        );
        expect(scaffold.currentState!.isEndDrawerOpen, isTrue);
        labMessengerKey.currentState!.removeCurrentSnackBar();
        await tester.pumpAndSettle();
      }
      expect(find.byIcon(Icons.phone), findsNothing);
      expect(find.text('Contactar agencia'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Contactar agencia por WhatsApp'),
        findsOneWidget,
      );
    },
  );
  testWidgets('close menu returns to same page without clearing credentials', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.byTooltip('Cerrar menú'));
    await tester.pumpAndSettle();
    expect(scaffold.currentState!.isEndDrawerOpen, isFalse);
    expect(find.text('Página de prueba'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('token'),
      'fixture-only',
    );
    expect(navigator.currentState!.canPop(), isFalse);
  });
  testWidgets(
    'camera keeps passenger identity and cancelling does not upload',
    (tester) async {
      await show(tester);
      expect(provider.calls.single, ['LAB-910011', '910001']);
      expect(
        tester
            .widget<ProfilePhotoAvatar>(find.byType(ProfilePhotoAvatar))
            .passenger!
            .passengerId,
        910011,
      );
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      expect(picks, 1);
      expect(provider.writes, 0);
      expect(find.text('Sofía Ejemplo Lab'), findsOneWidget);
      expect(scaffold.currentState!.isEndDrawerOpen, isTrue);
    },
  );
  testWidgets(
    'guardian menu opens its own password form and preserves session',
    (tester) async {
      await show(tester);
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
      expect(scaffold.currentState!.isEndDrawerOpen, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getString('token'),
        'fixture-only',
      );
      expect(provider.passwordWrites, 0);
    },
  );

  testWidgets('logout clears only mocked preferences and returns to welcome', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('family-menu-logout')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('token'), isNull);
    expect(prefs.getString('userRut'), isNull);
    expect(prefs.getString('userPassword'), isNull);
    expect(prefs.getBool('isLoggedIn'), isNot(true));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
  });
  testWidgets(
    'guardian password change preserves distinct student and coordinator saved credentials',
    (tester) async {
      const channel = MethodChannel('com.papigiras.lab/credentials');
      final savedRoles = <String>[];
      final readRoles = <String>[];
      final stored = {
        'attorney': {'rut': 'LAB-910011', 'password': 'fixture-current'},
        'passenger': {
          'rut': 'LAB-910011',
          'password': 'fixture-student-separate',
        },
        'coordinator': {'rut': 'LAB-910001', 'password': 'fixture-coordinator'},
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            final role = args['role'] as String;
            if (call.method == 'read') {
              readRoles.add(role);
              return stored[role];
            }
            if (call.method == 'save') {
              expect(provider.passwordWrites, 1);
              expect(args['rut'], 'LAB-910011');
              expect(args['password'], 'fixture-next');
              savedRoles.add(role);
              stored[role] = {
                'rut': args['rut'] as String,
                'password': args['password'] as String,
              };
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('family-menu-password')));
      await tester.pumpAndSettle();
      for (final entry in {
        'password-current': 'fixture-current',
        'password-new': 'fixture-next',
        'password-confirmation': 'fixture-next',
      }.entries) {
        await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
      }
      await tester.tap(find.byKey(const ValueKey('password-save')));
      await tester.pumpAndSettle();
      expect(provider.passwordWrites, 1);
      expect(readRoles, ['attorney']);
      expect(savedRoles, ['attorney']);
      expect(stored['attorney']!['password'], 'fixture-next');
      expect(stored['passenger']!['password'], 'fixture-student-separate');
      expect(stored['coordinator']!['password'], 'fixture-coordinator');
      expect(
        (await SharedPreferences.getInstance()).getString('token'),
        'fixture-only',
      );
      expect(find.text('Contraseña actualizada.'), findsOneWidget);
    },
  );
  testWidgets('student menu does not expose the guardian password action', (
    tester,
  ) async {
    await show(tester, allowPasswordChange: false);
    expect(find.byKey(const ValueKey('family-menu-password')), findsNothing);
    expect(find.text('Cambiar contraseña'), findsNothing);
    for (final action in ['contact', 'report', 'logout']) {
      expect(find.byKey(ValueKey('family-menu-$action')), findsOneWidget);
    }
    expect(provider.passwordWrites, 0);
  });

  for (final scale in [2.0, 3.0]) {
    testWidgets(
      '320 width text ${scale}x keeps long name and all menu actions reachable',
      (tester) async {
        await show(tester, width: 320, scale: scale, longName: true);
        expect(
          find.text(
            'Sofía Alejandra de la Demostración Apellido Extenso de Ejemplo Lab',
          ),
          findsOneWidget,
        );
        for (final key in [
          'family-menu-password',
          'family-menu-contact',
          'family-menu-report',
          'family-menu-logout',
        ]) {
          final target = find.byKey(ValueKey(key));
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          expect(
            tester
                .getRect(target)
                .overlaps(const Rect.fromLTWH(0, 0, 320, 852)),
            isTrue,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
