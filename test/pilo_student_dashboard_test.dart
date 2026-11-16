import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:papigiras_app/design/pilo_student_home.dart';
import 'package:papigiras_app/design/pilo_student_medical_sheet.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/lab/session.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

ResponseAttorney login([int id = 910011]) => ResponseAttorney(
  passengerId: id,
  tourId: 910001,
  passengerName: 'SOFÍA ISABEL',
  passengerApellidos: 'EJEMPLO LAB',
  passengerIdentificacion: 'LAB-$id',
);
PassengersMedicalRecordDTO medical([int id = 910011]) =>
    PassengersMedicalRecordDTO.fromJson({
      'idPassengersMedicalRecord': id,
      'passengerId': id,
      'tourSalesId': 910001,
      'contactoEmergenciaNombre': 'CONTACTO FICTICIO',
      'contactoEmergenciaTelefono': '+56 9 0000 0000',
      'contactoEmergenciaRelacion': 'Familiar',
      'grupoSanguineo': 'O+',
    });

class FakeProvider extends CoordinatorProviders {
  int calls = 0;
  int pdfCalls = 0;
  final pendingPdf = Completer<Uint8List>();
  int? error;
  int responseId = 910011;
  Completer<PassengersMedicalRecordDTO>? pending;
  @override
  Future<PassengersMedicalRecordDTO> getMedicalRecord(
    String tour,
    String passenger,
  ) async {
    expect(tour, '910001');
    expect(['910011', '910012'], contains(passenger));
    calls++;
    if (error != null) throw LabApiException(error!);
    if (pending != null) return pending!.future;
    return medical(responseId);
  }

  @override
  Future<Uint8List> getMedicalRecordPdf(String tour, String passenger) async {
    expect([tour, passenger], ['910001', '910011']);
    pdfCalls++;
    return pendingPdf.future;
  }

  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async => Responseimagepassenger(image: '');
}

void main() {
  late FakeProvider provider;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = FakeProvider();
  });
  tearDown(() => provider.dispose());
  Future<void> show(WidgetTester tester, {int id = 910011}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TravelPassengerDashboard(login: login(id), provider: provider),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  PiloStudentHome home(WidgetTester tester) =>
      tester.widget(find.byType(PiloStudentHome));

  testWidgets('uses own medical PDF without showing contacts on home', (
    tester,
  ) async {
    await show(tester);
    expect(home(tester).name, 'Sofía Ejemplo');
    expect(home(tester).medicalStatus, PiloStudentMedicalStatus.ready);
    expect(find.text('Contactos de emergencia'), findsNothing);
    expect(find.text('Contacto Ficticio'), findsNothing);
    expect(find.text('+56 9 0000 0000'), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('student-medical-open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(provider.pdfCalls, 1);
    expect(find.byType(PiloStudentMedicalSheet), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('Editar'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('student-medical-close')));
    await tester.pumpAndSettle();
    expect(find.byType(PiloStudentMedicalSheet), findsNothing);
  });

  testWidgets('student menu excludes guardian actions and retains logout', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('student-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('family-menu-logout')), findsOneWidget);
    expect(find.byKey(const ValueKey('family-menu-password')), findsNothing);
    expect(find.text('Datos gira'), findsNothing);
    expect(find.text('Documentos'), findsNothing);
  });

  testWidgets('404 is absent, 403 is an error and retry recovers', (
    tester,
  ) async {
    provider.error = 404;
    await show(tester);
    expect(home(tester).medicalStatus, PiloStudentMedicalStatus.missing);
    expect(find.text('Ficha aún no cargada'), findsOneWidget);
    provider.error = 403;
    home(tester).onRetry();
    await tester.pumpAndSettle();
    expect(home(tester).medicalStatus, PiloStudentMedicalStatus.failed);
    provider.error = null;
    home(tester).onRetry();
    await tester.pumpAndSettle();
    expect(home(tester).medicalStatus, PiloStudentMedicalStatus.ready);
  });

  testWidgets('mismatched record is never displayed', (tester) async {
    provider.responseId = 910012;
    await show(tester);
    expect(home(tester).medicalStatus, PiloStudentMedicalStatus.failed);
    home(tester).onMedical();
    await tester.pumpAndSettle();
    expect(find.byType(PiloStudentMedicalSheet), findsNothing);
    expect(provider.pdfCalls, 0);
  });

  testWidgets(
    'session change clears medical data and discards pending response',
    (tester) async {
      await show(tester);
      provider.pending = Completer<PassengersMedicalRecordDTO>();
      home(tester).onRetry();
      await tester.pump();
      await LabSession.clear(await SharedPreferences.getInstance());
      provider.pending!.complete(medical());
      await tester.pumpAndSettle();
      expect(home(tester).medicalStatus, PiloStudentMedicalStatus.failed);
      home(tester).onMedical();
      await tester.pumpAndSettle();
      expect(provider.pdfCalls, 0);
      expect(find.byType(PiloStudentMedicalSheet), findsNothing);
    },
  );

  testWidgets('late response after screen disposal is ignored', (tester) async {
    provider.pending = Completer<PassengersMedicalRecordDTO>();
    await show(tester);
    expect(home(tester).medicalStatus, PiloStudentMedicalStatus.loading);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    provider.pending!.complete(medical());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
