import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/medical_form_components.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/requestMedicalRecord.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class _Provider extends CoordinatorProviders {
  final requests = <RequestPassengerMedical>[];
  bool result = true;
  Completer<bool>? pending;
  String? readRut, readTour, savedPassenger, savedTour;
  Uint8List? photo;
  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async {
    readRut = rut;
    readTour = tour;
    return Responseimagepassenger(
      image: photo == null ? '' : base64Encode(photo!),
    );
  }

  @override
  Future<void> addHitoFotoPassenger(
    String passenger,
    String tour,
    XFile image,
  ) async {
    savedPassenger = passenger;
    savedTour = tour;
    photo = await image.readAsBytes();
  }

  @override
  Future<bool> createMedicalRecord(RequestPassengerMedical request) async {
    requests.add(request);
    return pending == null ? result : pending!.future;
  }
}

final _fixture = ResponseAttorney(
  passengerId: 910011,
  tourId: 910001,
  passengerName: 'Sofía',
  passengerApellidos: 'Ejemplo LAB',
  passengerIdentificacion: 'LAB-910011',
  tourName: 'Colegio Horizonte LAB',
  tourCourse: '3B',
  tourYear: 2026,
);
void main() {
  late _Provider provider;
  setUp(() {
    provider = _Provider();
  });
  tearDown(() => provider.dispose());
  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await rootBundle.load(
      'assets/profile.jpg',
    )).buffer.asUint8List();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS, brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: MedicalRecordScreen(
          login: _fixture,
          provider: provider,
          pickProfileImage: () async =>
              XFile.fromData(bytes, name: 'perfil-ficticio.jpg'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Finder input(String label) => find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is MedicalFormField && w.label == label,
    ),
    matching: find.byType(TextFormField),
  );
  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(input(label));
    await tester.pumpAndSettle();
    await tester.enterText(input(label), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> yes(WidgetTester tester, String name, {bool value = true}) =>
      tap(
        tester,
        find.byKey(ValueKey('medical-$name-${value ? 'yes' : 'no'}')),
      );
  Future<void> valid(WidgetTester tester) async {
    await enter(tester, 'Teléfono celular', '912345678');
    await enter(tester, 'Correo electrónico', 'familia@example.invalid');
  }

  final save = find.byKey(const ValueKey('medical-save'));
  final confirm = find.byKey(const ValueKey('medical-confirm-save'));

  testWidgets(
    'original fields and choices remain, validation blocks saving, consent is explicit',
    (tester) async {
      await show(tester);
      expect(find.byType(MedicalFormSection), findsNWidgets(5));
      expect(find.byType(MedicalYesNo), findsNWidgets(5));
      expect(find.byType(MedicalFormField), findsNWidgets(4));
      final blood = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('medical-blood-type')),
      );
      expect(blood.initialValue, isNull);
      await tap(tester, save);
      expect(provider.requests, isEmpty);
      expect(find.text('El teléfono es obligatorio'), findsOneWidget);
      expect(find.text('El correo es obligatorio'), findsOneWidget);
      await enter(tester, 'Teléfono celular', 'abc');
      await enter(tester, 'Correo electrónico', 'incompleto');
      await tap(tester, save);
      expect(provider.requests, isEmpty);
      await valid(tester);
      await tap(tester, save);
      expect(find.text('Autorización médica'), findsOneWidget);
      expect(provider.requests, isEmpty);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(provider.requests, isEmpty);
      expect(
        tester
            .widget<TextFormField>(input('Correo electrónico'))
            .controller!
            .text,
        'familia@example.invalid',
      );
    },
  );
  testWidgets(
    'all conditional values and exact request contract survive save; no duplicate submission',
    (tester) async {
      await show(tester);
      await tap(tester, find.byKey(const ValueKey('medical-blood-type')));
      expect(find.text('Otro'), findsOneWidget);
      await tester.tap(find.text('O+').last);
      await tester.pumpAndSettle();
      await enter(tester, 'Nombre y apellido', 'Contacto ficticio LAB');
      await enter(tester, 'Relación con el alumno(a)', 'Apoderado');
      await valid(tester);
      for (final name in [
        'fonasa',
        'isapre',
        'diseases',
        'medication',
        'avoid',
      ]) {
        await yes(tester, name);
      }
      expect(find.byType(MedicalFormField), findsNWidgets(11));
      final expected = {
        'Nombre de la ISAPRE': 'Ejemplo LAB',
        'Enfermedades crónicas o alergias': 'Dato ficticio',
        'Medicamento 1': 'Ejemplo uno',
        'Dosis del medicamento 1': 'Dosis ficticia uno',
        'Medicamento 2': 'Ejemplo dos',
        'Dosis del medicamento 2': 'Dosis ficticia dos',
        'Medicamentos que debe evitar': 'Dato ficticio',
      };
      for (final e in expected.entries) {
        await enter(tester, e.key, e.value);
      }
      await yes(tester, 'medication', value: false);
      await yes(tester, 'medication');
      expect(
        tester.widget<TextFormField>(input('Medicamento 1')).controller!.text,
        'Ejemplo uno',
      );
      provider.pending = Completer<bool>();
      await tap(tester, save);
      await tester.tap(confirm);
      await tester.pump();
      expect(provider.requests.length, 1);
      final button = tester.widget<FilledButton>(save);
      expect(button.onPressed, isNull);
      final request = provider.requests.single.toJson();
      expect(
        {...request}
          ..remove('fechaNacimiento')
          ..remove('fechaAutorizacion'),
        {
          'nombres': '',
          'apellidos': '',
          'curso': '',
          'colegio': '',
          'comuna': '',
          'rut': 'LAB-910011',
          'grupoSanguineo': 'O+',
          'contactoEmergenciaNombre': 'Contacto ficticio LAB',
          'contactoEmergenciaRelacion': 'Apoderado',
          'contactoEmergenciaTelefono': '912345678',
          'contactoEmergenciaEmail': 'familia@example.invalid',
          'tieneFonasa': true,
          'tieneIsapre': true,
          'isapre': 'Ejemplo LAB',
          'tieneEnfermedades': true,
          'enfermedades': 'Dato ficticio',
          'tomaMedicamentos': true,
          'medicamentos': [
            {'nombre': 'Ejemplo uno', 'dosis': 'Dosis ficticia uno'},
            {'nombre': 'Ejemplo dos', 'dosis': 'Dosis ficticia dos'},
          ],
          'evitarMedicamentos': true,
          'medicamentosEvitar': 'Dato ficticio',
          'requiereCuidadosEspeciales': false,
          'cuidadosEspeciales': null,
          'idPassenger': 910011,
          'idTour': 910001,
        },
      );
      provider.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Ficha médica guardada'), findsOneWidget);
      expect(provider.requests.length, 1);
    },
  );
  testWidgets(
    'failed save preserves input and offers retry; false is never a success',
    (tester) async {
      await show(tester);
      await valid(tester);
      provider.result = false;
      await tap(tester, save);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Ficha médica guardada'), findsNothing);
      expect(provider.requests.length, 1);
      expect(
        tester
            .widget<TextFormField>(input('Teléfono celular'))
            .controller!
            .text,
        '912345678',
      );
      await tap(tester, save);
      provider.result = true;
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Ficha médica guardada'), findsOneWidget);
      expect(provider.requests.length, 2);
      expect(provider.requests.last.medicamentos, isEmpty);
      expect(provider.requests.last.enfermedades, isNull);
      expect(provider.requests.last.tieneFonasa, isFalse);
    },
  );
  testWidgets(
    'avatar camera uses existing passenger photo identity and never saves medical data',
    (tester) async {
      await show(tester);
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      expect(provider.readRut, 'LAB-910011');
      expect(provider.readTour, '910001');
      expect(provider.savedPassenger, '910011');
      expect(provider.savedTour, '910001');
      expect(provider.requests, isEmpty);
      expect(find.text('Foto de perfil actualizada'), findsOneWidget);
    },
  );
  for (final layout in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(402, 874), 3.0),
    (const Size(844, 390), 1.0),
  ]) {
    testWidgets(
      'form handles ${layout.$1}, text ${layout.$2}, all conditional fields',
      (tester) async {
        await show(tester, size: layout.$1, scale: layout.$2);
        for (final name in ['isapre', 'diseases', 'medication', 'avoid']) {
          await yes(tester, name);
          expect(tester.takeException(), isNull);
        }
        for (final field
            in find
                .byType(MedicalFormField)
                .evaluate()
                .map((e) => (e.widget as MedicalFormField).label)
                .toList()) {
          await tester.ensureVisible(input(field));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
