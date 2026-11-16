import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:papigiras_app/design/papigiras_design.dart';
import 'package:papigiras_app/maps/trip_map_ui.dart';
import 'package:papigiras_app/lab/mode.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/attorney/loginFather.dart';
import 'package:papigiras_app/pages/alumns/loginpassenger.dart';
import 'package:papigiras_app/pages/coordinator/loginCoordinator.dart';

void main() {
  setUp(() {
    LabMode.useFixturesForTests(true);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => LabMode.useFixturesForTests(false));
  test('texto y acciones conservan contraste AA sobre sus superficies', () {
    for (final pair in [
      [PapiColors.ink, PapiColors.canvas],
      [PapiColors.muted, PapiColors.canvas],
      [PapiColors.muted, PapiColors.surface],
      [PapiColors.onMint, PapiColors.mint],
      [Colors.white, PapiColors.teal],
      [PapiColors.danger, PapiColors.canvas],
    ]) {
      final a = pair[0].computeLuminance(), b = pair[1].computeLuminance();
      final ratio = ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: pair.toString());
    }
  });
  testWidgets(
    'galería usa controles claros sobre fondo oscuro con tema compartido',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: papiTheme(),
          home: TripPhotoGallery(
            images: [base64Encode(TileProvider.transparentImage)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final textContext = tester.element(find.text('1 de 1'));
      expect(DefaultTextStyle.of(textContext).style.color, Colors.white);
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.close))).color,
        Colors.white,
      );
      expect(find.byTooltip('Cerrar fotos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final entry in <String, Widget Function()>{
    'familia': LoginFather.new,
    'alumno': LoginPassenger.new,
    'coordinador': LoginCoordinator.new,
  }.entries) {
    testWidgets(
      'acceso ${entry.key}:320px texto2x y teclado conserva controles y validación',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: papiTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 220),
              ),
              child: child!,
            ),
            home: entry.value(),
          ),
        );
        await tester.pumpAndSettle();
        // The form is a lazy list child below the large accessible heading.
        await tester.scrollUntilVisible(
          find.byType(Form),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '');
        await tester.enterText(fields.at(1), '');
        final submit = find.text('Ingresar');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text('Ingresa la contraseña.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
