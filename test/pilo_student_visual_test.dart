import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/pilo_student_medical_sheet.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Every value in this visual fixture is synthetic. Providers are overridden,
/// so rendering never queries the LAB database, medical API, or image service.
class _StudentVisualProvider extends CoordinatorProviders {
  final pdf = Completer<Uint8List>();

  @override
  Future<Uint8List> getMedicalRecordPdf(String tour, String passenger) {
    expect([tour, passenger], ['910001', '910011']);
    return pdf.future;
  }

  @override
  Future<PassengersMedicalRecordDTO> getMedicalRecord(
    String tour,
    String passenger,
  ) async {
    expect([tour, passenger], ['910001', '910011']);
    return PassengersMedicalRecordDTO.fromJson({
      'idPassengersMedicalRecord': 910011,
      'passengerId': 910011,
      'tourSalesId': 910001,
      'grupoSanguineo': 'O+',
      'tieneEnfermedades': false,
      'tomaMedicamentos': false,
      'evitarMedicamentos': false,
      'requiereCuidadosEspeciales': false,
      'tieneFonasa': true,
      'contactoEmergenciaNombre': 'CAROLINA EJEMPLO',
      'contactoEmergenciaTelefono': '+56 9 0000 0000',
      'contactoEmergenciaRelacion': 'Apoderada',
    });
  }

  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async {
    expect([rut, tour], ['LAB-910011', '910001']);
    return Responseimagepassenger(image: '');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await Future.wait([
      (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load(),
      (FontLoader(
        'Manjari',
      )..addFont(rootBundle.load('assets/fonts/Manjari-Regular.ttf'))).load(),
      (FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
          .load(),
    ]);
  });

  testWidgets('student dashboard and PDF loading/error visual fixture', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _StudentVisualProvider();
    addTearDown(provider.dispose);
    final boundary = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: PiloFamilyTheme.theme(ThemeData()),
        builder: (context, child) => RepaintBoundary(
          key: boundary,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: 48, bottom: 24)),
            child: child!,
          ),
        ),
        home: TravelPassengerDashboard(
          login: ResponseAttorney(
            passengerId: 910011,
            tourId: 910001,
            passengerName: 'SOFÍA ISABEL',
            passengerApellidos: 'TORRES EJEMPLO',
            passengerIdentificacion: 'LAB-910011',
          ),
          provider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final avatar in tester.widgetList<CircleAvatar>(
        find.byType(CircleAvatar),
      )) {
        if (avatar.backgroundImage != null) {
          await precacheImage(
            avatar.backgroundImage!,
            boundary.currentContext!,
          );
        }
      }
    });
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      if (Platform.environment['PILO_STUDENT_VISUAL'] != '1') return;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File(
          'registro-local/PILO-ALUMNO-FICHA-COMPARTIR/evidencia/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    expect(find.text('Sofía Torres'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    // Keep contacts in the fixture: the dashboard must omit this block even
    // when a medical record contains them. The PDF remains the document source.
    expect(find.text('Contactos de emergencia'), findsNothing);
    expect(find.text('Carolina Ejemplo'), findsNothing);
    expect(find.text('CAROLINA EJEMPLO'), findsNothing);
    expect(find.text('+56 9 0000 0000'), findsNothing);
    expect(find.text('Apoderada'), findsNothing);
    final medical = find.byKey(const ValueKey('student-medical-open'));
    expect(medical.hitTestable(), findsOneWidget);
    expect(tester.getRect(medical).bottom, lessThan(828));
    await capture('alumno-inicio-fixture');

    await tester.tap(medical);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PiloStudentMedicalSheet), findsOneWidget);
    expect(find.text('Sofía Isabel Torres Ejemplo'), findsOneWidget);
    expect(find.text('Abriendo tu ficha médica…'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byKey(const ValueKey('student-medical-share')), findsNothing);
    expect(
      find.byKey(const ValueKey('student-medical-download')),
      findsNothing,
    );
    // This fixture verifies only the shell/loading/error UI. Native PDF render
    // is exercised separately by student_native_preview.dart on the QA device.
    await capture('alumno-ficha-medica-cargando-fixture');
    provider.pdf.completeError(StateError('Synthetic PDF unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos abrir tu ficha médica.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byKey(const ValueKey('student-medical-share')), findsNothing);
    expect(
      find.byKey(const ValueKey('student-medical-download')),
      findsNothing,
    );
    await capture('alumno-ficha-medica-error-fixture');
    await tester.tap(find.byTooltip('Cerrar ficha médica'));
    await tester.pumpAndSettle();
    expect(find.byType(PiloStudentMedicalSheet), findsNothing);
    expect(find.text('Sofía Torres'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
