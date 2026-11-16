import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_family_medical_preview.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';
import 'package:papigiras_app/pages/attorney/viewmedicalRecord.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

final _login = ResponseAttorney(
  passengerId: 910011,
  tourId: 910001,
  passengerName: 'SOFÍA ALEJANDRA',
  passengerApellidos: 'EJEMPLO LAB',
  passengerIdentificacion: 'LAB-910011',
);

class _Provider extends CoordinatorProviders {
  int calls = 0;
  int? error;
  String? date = '2026-11-12T12:30:00Z';
  Completer<PassengersMedicalRecordDTO>? pending;
  @override
  Future<PassengersMedicalRecordDTO> getMedicalRecord(
    String tour,
    String passenger,
  ) async {
    expect([tour, passenger], ['910001', '910011']);
    calls++;
    if (error != null) throw LabApiException(error!);
    if (pending != null) return pending!.future;
    return PassengersMedicalRecordDTO.fromJson({
      'idPassengersMedicalRecord': 910011,
      'passengerId': 910011,
      'tourSalesId': 910001,
      'fechaAutorizacion': date,
    });
  }

  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async => Responseimagepassenger(image: '');
}

void main() {
  late _Provider provider;
  var opens = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = _Provider();
    opens = 0;
  });
  tearDown(() => provider.dispose());

  Future<void> show(
    WidgetTester tester, {
    double width = 393,
    double scale = 1,
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
              onPressed: () => showPiloFamilyMedicalPreview(
                context,
                login: _login,
                provider: provider,
                onOpenRecord: () async {
                  opens++;
                },
              ),
              child: const Text('Abrir resumen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir resumen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'saved preview uses authorization date and routes only on explicit CTA',
    (tester) async {
      await show(tester);
      expect(find.text('Sofía Ejemplo'), findsOneWidget);
      expect(find.text('Ficha guardada'), findsOneWidget);
      expect(
        find.text('Autorizada el 12 de noviembre de 2026'),
        findsOneWidget,
      );
      expect(find.textContaining('Última revisión'), findsNothing);
      expect(opens, 0);
      await tester.tap(
        find.byKey(const ValueKey('family-medical-preview-open')),
      );
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(
        find.byKey(const ValueKey('family-medical-preview')),
        findsNothing,
      );
    },
  );

  testWidgets('missing record is distinct from load failure', (tester) async {
    provider.error = 404;
    await show(tester);
    expect(find.text('Ficha por completar'), findsOneWidget);
    expect(find.text('Completar ficha'), findsOneWidget);
    expect(find.text('Ficha guardada'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('family-medical-preview-open')));
    await tester.pumpAndSettle();
    expect(opens, 1);
  });

  testWidgets(
    'permission or network failure cannot be shown as missing or saved; retries',
    (tester) async {
      provider.error = 403;
      await show(tester);
      expect(find.text('No pudimos consultar la ficha'), findsOneWidget);
      expect(find.text('Ficha por completar'), findsNothing);
      expect(find.text('Ficha guardada'), findsNothing);
      provider.error = null;
      provider.date = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(provider.calls, 2);
      expect(find.text('Ficha guardada'), findsOneWidget);
      expect(find.text('Disponible para revisar y editar'), findsOneWidget);
      expect(opens, 0);
    },
  );

  testWidgets('pending request disables open; closing while loading is safe', (
    tester,
  ) async {
    provider.pending = Completer<PassengersMedicalRecordDTO>();
    await show(tester);
    expect(find.text('Consultando ficha'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('family-medical-preview-open')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Cerrar vista previa de ficha médica'));
    await tester.pumpAndSettle();
    provider.pending!.completeError(const LabApiException(503));
    await tester.pumpAndSettle();
    expect(opens, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small screen and large text remain scrollable with accessible CTA',
    (tester) async {
      await show(tester, width: 320, scale: 1.8);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('family-medical-preview-open')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('family-medical-preview-open')),
      );
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('full medical screen loads initial form on confirmed 404 only', (
    tester,
  ) async {
    provider.error = 404;
    await tester.pumpWidget(
      MaterialApp(
        home: ViewMedicalRecordScreen(login: _login, provider: provider),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MedicalRecordScreen), findsOneWidget);
    expect(
      tester
          .widget<MedicalRecordScreen>(find.byType(MedicalRecordScreen))
          .savedRecord,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('full medical screen retains retry on permission failure', (
    tester,
  ) async {
    provider.error = 403;
    await tester.pumpWidget(
      MaterialApp(
        home: ViewMedicalRecordScreen(login: _login, provider: provider),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MedicalRecordScreen), findsNothing);
    expect(find.text('No se pudo cargar la ficha médica.'), findsOneWidget);
  });
}
