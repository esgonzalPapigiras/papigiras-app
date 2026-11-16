import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_student_home.dart';

void main() {
  var medicalOpens = 0;
  var menuOpens = 0;
  var retries = 0;

  setUp(() {
    medicalOpens = 0;
    menuOpens = 0;
    retries = 0;
  });

  Future<void> show(
    WidgetTester tester, {
    double width = 393,
    double scale = 1,
    String name = 'Sofía Ejemplo',
    PiloStudentMedicalStatus status = PiloStudentMedicalStatus.ready,
  }) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: PiloStudentHome(
            name: name,
            rut: 'LAB-910011',
            avatar: const CircleAvatar(child: Text('SE')),
            qr: const ColoredBox(
              key: ValueKey('original-qr'),
              color: Colors.white,
              child: Icon(Icons.qr_code_2, size: 180),
            ),
            onMenu: () => menuOpens++,
            onMedical: () => medicalOpens++,
            onRetry: () => retries++,
            medicalStatus: status,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'shows only identity, pass and prominent read-only medical access',
    (tester) async {
      await show(tester);
      expect(find.text('Sofía Ejemplo'), findsOneWidget);
      expect(find.text('RUT LAB-910011'), findsOneWidget);
      expect(find.byKey(const ValueKey('original-qr')), findsOneWidget);
      expect(find.text('Sólo lectura'), findsOneWidget);
      expect(find.text('Contactos de emergencia'), findsNothing);
      expect(find.byTooltip('Copiar número de contacto'), findsNothing);
      expect(find.text('Consultando tu ficha médica…'), findsNothing);
      expect(find.text('Ficha aún no cargada'), findsNothing);
      expect(find.text('No pudimos cargar la ficha'), findsNothing);
      expect(find.textContaining('Editar'), findsNothing);
      expect(find.text('Gira'), findsNothing);
      expect(find.text('Mapa'), findsNothing);
      expect(find.text('Bitácora'), findsNothing);
      final cta = find.byKey(const ValueKey('student-medical-open'));
      expect(tester.getSize(cta).height, greaterThanOrEqualTo(88));
      expect(tester.getBottomLeft(cta).dy, lessThan(852));
      await tester.tap(cta);
      await tester.pump();
      expect(medicalOpens, 1);
      await tester.tap(find.byKey(const ValueKey('student-menu')));
      await tester.pump();
      expect(menuOpens, 1);
    },
  );

  testWidgets('loading keeps the pass available and medical access disabled', (
    tester,
  ) async {
    await show(tester, status: PiloStudentMedicalStatus.loading);
    expect(find.text('Consultando tu ficha médica…'), findsOneWidget);
    expect(find.text('Contactos de emergencia'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('student-medical-open')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byKey(const ValueKey('original-qr')), findsOneWidget);
  });

  testWidgets('missing and failed are distinct, both can retry', (
    tester,
  ) async {
    await show(tester, status: PiloStudentMedicalStatus.missing);
    expect(find.text('Ficha aún no cargada'), findsOneWidget);
    expect(
      find.text('Tu apoderado puede completarla desde su perfil.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Actualizar'));
    await tester.tap(find.text('Actualizar'));
    expect(retries, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('student-medical-open')),
          )
          .onPressed,
      isNull,
    );

    await show(tester, status: PiloStudentMedicalStatus.failed);
    expect(find.text('No pudimos cargar la ficha'), findsOneWidget);
    expect(find.text('Ficha aún no cargada'), findsNothing);
    await tester.ensureVisible(find.text('Reintentar'));
    await tester.tap(find.text('Reintentar'));
    expect(retries, 2);
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
      '320-point width and text scale $scale keep actions reachable',
      (tester) async {
        await show(
          tester,
          width: 320,
          scale: scale,
          name: 'Alejandra Ejemplolargodelaboratorio',
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('student-medical-open')),
        );
        await tester.tap(find.byKey(const ValueKey('student-medical-open')));
        expect(medicalOpens, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
