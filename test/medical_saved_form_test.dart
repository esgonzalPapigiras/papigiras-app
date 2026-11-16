import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/medical_form_components.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/requestMedicalRecord.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';
import 'package:papigiras_app/pages/attorney/viewmedicalRecord.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

final fixtureLogin = ResponseAttorney(
  passengerId: 910011,
  tourId: 910001,
  passengerName: 'Sofía',
  passengerApellidos: 'Ejemplo LAB',
  passengerIdentificacion: 'LAB-910011',
);
Map<String, dynamic> fixtureJson() => {
  'idPassengersMedicalRecord': 910011,
  'passengerId': 910011,
  'tourSalesId': 910001,
  'grupoSanguineo': 'O+',
  'contactoEmergenciaNombre': 'Contacto Ejemplo LAB',
  'contactoEmergenciaRelacion': 'Apoderado',
  'contactoEmergenciaTelefono': '912345678',
  'contactoEmergenciaEmail': 'familia@example.invalid',
  'tieneFonasa': true,
  'tieneIsapre': true,
  'isapre': 'Cobertura LAB',
  'tieneEnfermedades': true,
  'enfermedades': 'Antecedente ficticio',
  'tomaMedicamentos': true,
  'medicamentos': 'Uno - dosis uno\nDos - dosis dos',
  'medicamentosDetalle': [
    {'nombre': 'Uno', 'dosis': 'dosis uno'},
    {'nombre': 'Dos', 'dosis': 'dosis dos'},
  ],
  'evitarMedicamentos': true,
  'medicamentosEvitar': 'Evitar ficticio',
  'fechaAutorizacion': '2026-11-12T12:30:00Z',
  'revision': 'revision-original',
  'requiereCuidadosEspeciales': false,
  'cuidadosEspeciales': null,
};

class MedicalFixtureProvider extends CoordinatorProviders {
  Map<String, dynamic> data = fixtureJson();
  bool failRead = false, failPdf = false;
  int? failUpdate;
  int reads = 0, updates = 0, downloads = 0, shares = 0;
  RequestPassengerMedical? request;
  String? revision;
  bool? preserveLegacy;
  Completer<PassengersMedicalRecordDTO>? pending;
  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async => Responseimagepassenger(image: '');
  @override
  Future<PassengersMedicalRecordDTO> getMedicalRecord(
    String tour,
    String passenger,
  ) async {
    expect([tour, passenger], ['910001', '910011']);
    reads++;
    if (failRead) throw StateError('fixture');
    return PassengersMedicalRecordDTO.fromJson(data);
  }

  @override
  Future<PassengersMedicalRecordDTO> updateFamilyMedicalRecord(
    RequestPassengerMedical medical, {
    required String revision,
    required bool preserveLegacyMedications,
  }) async {
    updates++;
    request = medical;
    this.revision = revision;
    preserveLegacy = preserveLegacyMedications;
    if (failUpdate != null) throw LabApiException(failUpdate!);
    data = {
      ...data,
      ...medical.toJson(),
      'medicamentos': preserveLegacyMedications
          ? data['medicamentos']
          : 'actualizado',
      'medicamentosDetalle': preserveLegacyMedications
          ? null
          : medical.medicamentos,
      'revision': 'revision-nueva',
      'fechaAutorizacion': '2026-11-13T12:00:00Z',
    };
    return pending == null
        ? PassengersMedicalRecordDTO.fromJson(data)
        : pending!.future;
  }

  @override
  Future<void> downloadDocumentMedicalRecord(
    String tour,
    String passenger,
    String rut,
  ) async {
    expect([tour, passenger, rut], ['910001', '910011', 'LAB-910011']);
    downloads++;
    if (failPdf) throw StateError('fixture');
  }

  @override
  Future<void> shareDocumentMedicalRecord(
    String tour,
    String passenger,
    String rut,
  ) async {
    expect([tour, passenger, rut], ['910001', '910011', 'LAB-910011']);
    shares++;
    if (failPdf) throw StateError('fixture');
  }
}

void main() {
  late MedicalFixtureProvider provider;
  setUp(() => provider = MedicalFixtureProvider());
  tearDown(() => provider.dispose());
  Future<void> show(
    WidgetTester t, {
    Size size = const Size(402, 874),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        builder: (c, ch) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: ch!,
        ),
        home: ViewMedicalRecordScreen(login: fixtureLogin, provider: provider),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  Future<void> tap(WidgetTester t, String key) async {
    var f = find.byKey(ValueKey(key));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Finder field(String label) =>
      find.byWidgetPredicate((w) => w is MedicalFormField && w.label == label);
  String value(WidgetTester t, String label) =>
      t.widget<MedicalFormField>(field(label)).controller.text;
  Future<void> enter(WidgetTester t, String label, String value) async {
    var f = find.descendant(
      of: field(label),
      matching: find.byType(TextFormField),
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.enterText(f, value);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
  }

  testWidgets(
    'same five sections and every persisted answer are visible and locked',
    (t) async {
      await show(t);
      expect(provider.reads, 1);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byKey(const ValueKey('medical-save')), findsNothing);
      expect(
        t
            .widgetList<MedicalFormSection>(find.byType(MedicalFormSection))
            .take(5)
            .map((s) => s.title),
        [
          'Datos del pasajero',
          'Contacto de emergencia',
          'Cobertura médica',
          'Antecedentes médicos',
          'Medicamentos',
        ],
      );
      for (final pair in {
        'Nombre y apellido': 'Contacto Ejemplo LAB',
        'Relación con el alumno(a)': 'Apoderado',
        'Teléfono celular': '912345678',
        'Correo electrónico': 'familia@example.invalid',
        'Nombre de la ISAPRE': 'Cobertura LAB',
        'Enfermedades crónicas o alergias': 'Antecedente ficticio',
        'Medicamento 1': 'Uno',
        'Dosis del medicamento 1': 'dosis uno',
        'Medicamento 2': 'Dos',
        'Dosis del medicamento 2': 'dosis dos',
        'Medicamentos que debe evitar': 'Evitar ficticio',
      }.entries)
        expect(value(t, pair.key), pair.value);
      for (final button in t.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      ))
        expect(button.onPressed, isNull);
      expect(provider.updates, 0);
    },
  );
  testWidgets(
    'explicit edit prefills, cancel confirmation restores saved answers',
    (t) async {
      await show(t);
      await tap(t, 'medical-edit');
      expect(find.byType(TextFormField), findsNWidgets(11));
      await enter(t, 'Nombre y apellido', 'Cambio sin guardar');
      await tap(t, 'medical-cancel-edit');
      await t.tap(find.text('Seguir editando'));
      await t.pumpAndSettle();
      expect(value(t, 'Nombre y apellido'), 'Cambio sin guardar');
      await tap(t, 'medical-cancel-edit');
      await t.tap(find.text('Descartar'));
      await t.pumpAndSettle();
      expect(value(t, 'Nombre y apellido'), 'Contacto Ejemplo LAB');
      expect(find.byType(TextFormField), findsNothing);
      expect(provider.updates, 0);
    },
  );
  testWidgets(
    'validates before renewal and canceling consent makes no request',
    (t) async {
      await show(t);
      await tap(t, 'medical-edit');
      await enter(t, 'Teléfono celular', 'bad');
      await tap(t, 'medical-save');
      expect(find.text('Ingresa un teléfono válido'), findsOneWidget);
      expect(provider.updates, 0);
      await enter(t, 'Teléfono celular', '912345678');
      await tap(t, 'medical-save');
      expect(find.text('Autorización médica'), findsOneWidget);
      await t.ensureVisible(find.text('Volver'));
      await t.pumpAndSettle();
      await t.tap(find.text('Volver'));
      await t.pumpAndSettle();
      expect(find.text('Autorizar y actualizar'), findsNothing);
      await t.pumpAndSettle();
      expect(provider.updates, 0);
      expect(find.byType(TextFormField), findsNWidgets(11));
    },
  );
  testWidgets(
    'update preserves all fields and relocks without replacing route',
    (t) async {
      await show(t);
      await tap(t, 'medical-edit');
      await enter(t, 'Nombre y apellido', 'Contacto actualizado LAB');
      await enter(t, 'Dosis del medicamento 2', 'Dosis nueva LAB');
      await tap(t, 'medical-save');
      await tap(t, 'medical-confirm-save');
      expect(provider.updates, 1);
      expect(provider.revision, 'revision-original');
      expect(provider.preserveLegacy, isFalse);
      expect(provider.request!.idPassenger, 910011);
      expect(provider.request!.idTour, 910001);
      expect(
        provider.request!.contactoEmergenciaNombre,
        'Contacto actualizado LAB',
      );
      expect(provider.request!.medicamentos.last['dosis'], 'Dosis nueva LAB');
      expect(provider.request!.tieneFonasa, isTrue);
      expect(provider.request!.evitarMedicamentos, isTrue);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Ficha médica actualizada y guardada'), findsOneWidget);
      expect(find.byType(ViewMedicalRecordScreen), findsOneWidget);
      await tap(t, 'medical-edit');
      expect(value(t, 'Dosis del medicamento 2'), 'Dosis nueva LAB');
      await tap(t, 'medical-save');
      await tap(t, 'medical-confirm-save');
      expect(provider.revision, 'revision-nueva');
    },
  );
  testWidgets('pending save disables duplicate submit', (t) async {
    await show(t);
    await tap(t, 'medical-edit');
    provider.pending = Completer();
    await tap(t, 'medical-save');
    await t.tap(find.byKey(const ValueKey('medical-confirm-save')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 20));
    expect(provider.updates, 1);
    expect(
      t
          .widget<FilledButton>(find.byKey(const ValueKey('medical-save')))
          .onPressed,
      isNull,
    );
    provider.pending!.complete(
      PassengersMedicalRecordDTO.fromJson(provider.data),
    );
    await t.pumpAndSettle();
    expect(find.text('Ficha médica actualizada y guardada'), findsOneWidget);
  });
  for (final code in [500, 409])
    testWidgets('failed update $code keeps answers and never reports success', (
      t,
    ) async {
      await show(t);
      await tap(t, 'medical-edit');
      await enter(t, 'Nombre y apellido', 'Texto conservado');
      provider.failUpdate = code;
      await tap(t, 'medical-save');
      await tap(t, 'medical-confirm-save');
      expect(value(t, 'Nombre y apellido'), 'Texto conservado');
      expect(find.text('Ficha médica actualizada y guardada'), findsNothing);
      expect(
        find.textContaining(code == 409 ? 'otra sesión' : 'No se pudo guardar'),
        findsOneWidget,
      );
    });
  testWidgets(
    'PDF actions fetch via provider each time and recover from failure',
    (t) async {
      await show(t);
      await tap(t, 'medical-download');
      await tap(t, 'medical-share');
      expect(provider.downloads, 1);
      expect(provider.shares, 1);
      provider.failPdf = true;
      await tap(t, 'medical-download');
      expect(
        find.text('No se pudo obtener el PDF. Vuelve a intentarlo.'),
        findsOneWidget,
      );
      provider.failPdf = false;
      await tap(t, 'medical-download');
      expect(provider.downloads, 3);
      expect(find.textContaining('No se pudo obtener'), findsNothing);
    },
  );
  testWidgets(
    'legacy ambiguous medication text is retained rather than guessed',
    (t) async {
      provider.data.remove('medicamentosDetalle');
      provider.data['medicamentos'] =
          'Registro histórico sin separación de dosis';
      await show(t);
      expect(
        value(t, 'Medicamentos registrados'),
        'Registro histórico sin separación de dosis',
      );
      await tap(t, 'medical-edit');
      await tap(t, 'medical-save');
      await tap(t, 'medical-confirm-save');
      expect(provider.preserveLegacy, isTrue);
      expect(
        value(t, 'Medicamentos registrados'),
        'Registro histórico sin separación de dosis',
      );
    },
  );
  testWidgets('load error can retry without creating an empty record', (
    t,
  ) async {
    provider.failRead = true;
    await show(t);
    expect(find.text('No se pudo cargar la ficha médica.'), findsOneWidget);
    expect(find.byType(MedicalRecordScreen), findsNothing);
    provider.failRead = false;
    await t.tap(find.text('Reintentar'));
    await t.pumpAndSettle();
    expect(find.byType(MedicalRecordScreen), findsOneWidget);
    expect(provider.reads, 2);
    expect(provider.updates, 0);
  });
  testWidgets('consent stays in the form navigator when nested', (t) async {
    final inner = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: inner,
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => ViewMedicalRecordScreen(
              login: fixtureLogin,
              provider: provider,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await tap(t, 'medical-edit');
    await tap(t, 'medical-save');
    expect(
      Navigator.of(t.element(find.byType(AlertDialog))),
      same(inner.currentState),
    );
    await t.ensureVisible(find.text('Volver'));
    await t.pumpAndSettle();
    await t.tap(find.text('Volver'));
    await t.pumpAndSettle();
    expect(provider.updates, 0);
    expect(find.byType(ViewMedicalRecordScreen), findsOneWidget);
  });
  for (final scale in [2.0, 3.0])
    testWidgets('small width and text ${scale}x retain fields and PDF actions', (
      t,
    ) async {
      provider.data['contactoEmergenciaNombre'] =
          'Nombre de contacto ficticio muy largo para validar el ajuste de texto';
      await show(t, size: const Size(320, 568), scale: scale);
      await tap(t, 'medical-edit');
      await enter(t, 'Nombre y apellido', 'Contacto LAB');
      await tap(t, 'medical-save');
      expect(t.takeException(), isNull);
      expect(find.text('Autorizar y actualizar'), findsOneWidget);
      await t.ensureVisible(find.text('Volver'));
      await t.pumpAndSettle();
      await t.tap(find.text('Volver'));
      await t.pumpAndSettle();
      expect(find.text('Autorizar y actualizar'), findsNothing);
      await t.pumpAndSettle();
    });
}
