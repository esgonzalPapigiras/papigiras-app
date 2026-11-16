import 'dart:collection';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/dto/requestMedicalRecord.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:papigiras_app/design/medical_form_components.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'package:papigiras_app/lab/fixtures.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';
import 'package:papigiras_app/pages/attorney/medicalRecordScreenEdit.dart';
import 'package:papigiras_app/pages/attorney/viewmedicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecordScreenEditCoordinator.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CL'));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LabMode.useFixturesForTests(true);
    LabFixtures.reset();
    await (await SharedPreferences.getInstance()).clear();
  });
  tearDown(() {
    LabMode.useFixturesForTests(false);
    LabFixtures.medical = {};
  });
  final tour = TourSales.fromCoordinatorTour(
    coordinator: LabFixtures.coordinator,
    tour: LabFixtures.tour,
  );
  final screens = <String, Widget Function()>{
    'crear': () => MedicalRecordScreen(login: LabFixtures.passenger),
    'editar': () => MedicalRecordScreenEdit(
      login: LabFixtures.passenger,
      record: LabFixtures.defaultMedical(1),
    ),
    'lectura': () => ViewMedicalRecordScreen(login: LabFixtures.passenger),
    'coordinador': () => MedicalRecordScreenEditCoordinator(
      login: tour,
      idPassenger: '1',
      idDocumento: 'DOC-LAB',
      nombrepassenger: 'Estudiante',
      passengerApellidos: 'Ficticio',
    ),
  };
  for (final screen in screens.entries) {
    testWidgets(
      '${screen.key}: ficha legible a320px texto1.4 sin overflow ni datos reales',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: papiTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!,
            ),
            home: screen.value(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final button = screen.key == 'lectura'
            ? find.byKey(const ValueKey('medical-edit'))
            : screen.key == 'coordinador'
            ? find.text('Guardar ficha médica')
            : find.byKey(const ValueKey('medical-save'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(button, findsOneWidget);
        if (screen.key == 'crear') {
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(
            find.text(
              'Revisa el teléfono y el correo electrónico antes de guardar.',
            ),
            findsOneWidget,
          );
          expect(find.text('El teléfono es obligatorio'), findsOneWidget);
          expect(find.text('El correo es obligatorio'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'crear: consentimiento previo, cancelación y un solo guardado con doble toque',
    (tester) async {
      final records = _CountingMedicalMap();
      LabFixtures.medical = records;
      await tester.pumpWidget(
        MaterialApp(
          theme: papiTheme(),
          home: MedicalRecordScreen(login: LabFixtures.passenger),
        ),
      );
      await tester.pumpAndSettle();
      Finder field(String label) => find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is MedicalFormField && widget.label == label,
        ),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(field('Teléfono celular'));
      await tester.enterText(field('Teléfono celular'), '900000001');
      await tester.ensureVisible(field('Correo electrónico'));
      await tester.enterText(
        field('Correo electrónico'),
        'prueba@example.invalid',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('medical-save')));
      await tester.pumpAndSettle();
      var save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('medical-save')),
      );
      save.onPressed!();
      save.onPressed!();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Autorización médica'), findsOneWidget);
      expect(records.writes, 0);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('medical-save')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(records.writes, 0);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('medical-save')))
            .onPressed,
        isNotNull,
      );
      save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('medical-save')),
      );
      save.onPressed!();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('medical-confirm-save')));
      await tester.pumpAndSettle();
      expect(records.writes, 1);
      expect(
        records[LabFixtures.passenger.passengerId]!.emergencyContactEmail,
        'prueba@example.invalid',
      );
      expect(find.text('Ficha médica guardada'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'editar: el doble toque envía una vez y conserva el flujo existente',
    (tester) async {
      final records = _CountingMedicalMap();
      LabFixtures.medical = records;
      await tester.pumpWidget(
        MaterialApp(
          theme: papiTheme(),
          home: MedicalRecordScreen(
            login: LabFixtures.passenger,
            savedRecord: LabFixtures.defaultMedical(1),
            startEditing: true,
            provider: _UpdateMedicalFixtureProvider(records),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final phone = find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is MedicalFormField && widget.label == 'Teléfono celular',
        ),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '900000001');
      await tester.ensureVisible(find.byKey(const ValueKey('medical-save')));
      await tester.pumpAndSettle();
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('medical-save')),
      );
      save.onPressed!();
      save.onPressed!();
      await tester.pumpAndSettle();
      expect(records.writes, 0);
      expect(find.text('Autorización médica'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('medical-confirm-save')));
      await tester.pumpAndSettle();
      expect(records.writes, 1);
      expect(find.text('Ficha médica actualizada y guardada'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

class _CountingMedicalMap extends MapBase<int, PassengersMedicalRecordDTO> {
  final _values = <int, PassengersMedicalRecordDTO>{};
  int writes = 0;
  @override
  PassengersMedicalRecordDTO? operator [](Object? key) => _values[key];
  @override
  void operator []=(int key, PassengersMedicalRecordDTO value) {
    writes++;
    _values[key] = value;
  }

  @override
  Iterable<int> get keys => _values.keys;
  @override
  void clear() => _values.clear();
  @override
  PassengersMedicalRecordDTO? remove(Object? key) => _values.remove(key);
}

class _UpdateMedicalFixtureProvider extends CoordinatorProviders {
  _UpdateMedicalFixtureProvider(this.records);
  final _CountingMedicalMap records;
  @override
  Future<PassengersMedicalRecordDTO> updateFamilyMedicalRecord(
    RequestPassengerMedical medical, {
    required String revision,
    required bool preserveLegacyMedications,
  }) async {
    final saved = PassengersMedicalRecordDTO.fromJson({
      ...medical.toJson(),
      'idPassengersMedicalRecord': medical.idPassenger,
      'passengerId': medical.idPassenger,
      'tourSalesId': medical.idTour,
      'medicamentos': '',
      'revision': 'fixture-updated',
    });
    records[medical.idPassenger] = saved;
    return saved;
  }
}
