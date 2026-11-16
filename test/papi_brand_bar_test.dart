import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/papi_brand_bar.dart';

void main() {
  testWidgets(
    'cabecera compacta mantiene logo centrado, áreas táctiles y acciones',
    (tester) async {
      var back = 0;
      var menu = 0;
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        for (final showBack in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(3)),
                  child: PapiBrandBar(
                    onBack: showBack ? () => back++ : null,
                    onMenu: () => menu++,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.getSize(find.byKey(const ValueKey('papi-brand-bar'))).height,
            72,
          );
          expect(tester.getCenter(find.byType(Image)).dx, 160);
          expect(tester.getSize(find.byType(Image)).height, 40);
          for (final button in find.byType(IconButton).evaluate()) {
            expect(
              tester.getSize(find.byWidget(button.widget)).shortestSide,
              greaterThanOrEqualTo(48),
            );
          }
          await tester.tap(find.byTooltip('Abrir menú'));
          if (showBack) await tester.tap(find.byTooltip('Volver'));
          expect(tester.takeException(), isNull);
        }
      }
      expect(menu, 4);
      expect(back, 2);
    },
  );
}
