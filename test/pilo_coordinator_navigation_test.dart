import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/navigation/family_navigation.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double textScale = 1,
    VoidCallback? onMapOpened,
    ValueChanged<int>? onMapRequested,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: FamilyNavigation(
          pilo: true,
          coordinatorTools: true,
          immersiveMap: true,
          onMapOpened: onMapOpened,
          onMapRequested: onMapRequested,
          builders: {
            for (final section in FamilySection.values)
              section: (context) {
                final navigation = FamilyNavigationScope.maybeOf(context)!;
                return Scaffold(
                  body: Column(
                    children: [
                      Text('Sección ${section.name}'),
                      if (section == FamilySection.map)
                        TextButton(
                          onPressed: navigation.back,
                          child: const Text('Volver del mapa'),
                        )
                      else ...[
                        TextButton(
                          onPressed: () => navigation.select(FamilySection.map),
                          child: const Text('Abrir mapa'),
                        ),
                        TextButton(
                          onPressed: () => navigation.openMap(910001),
                          child: const Text('Ver hito en mapa'),
                        ),
                      ],
                      if (section == FamilySection.documents)
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const Scaffold(
                                body: Text('Documento de ejemplo abierto'),
                              ),
                            ),
                          ),
                          child: const Text('Abrir documento de ejemplo'),
                        ),
                    ],
                  ),
                );
              },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, FamilySection section) async {
    await tester.tap(find.byKey(ValueKey('family-tab-${section.name}')));
    await tester.pumpAndSettle();
  }

  testWidgets('coordinator dock exposes files and retains an open document', (
    tester,
  ) async {
    await show(tester);
    expect(find.byKey(const ValueKey('family-tab-map')), findsNothing);
    expect(find.byKey(const ValueKey('family-tab-crew')), findsNothing);
    final buttons = tester.widgetList<TextButton>(
      find.descendant(
        of: find.byType(FamilyNavigationBar),
        matching: find.byType(TextButton),
      ),
    );
    expect(buttons.map((button) => button.key), [
      const ValueKey('family-tab-home'),
      const ValueKey('family-tab-diary'),
      const ValueKey('family-tab-gallery'),
      const ValueKey('family-tab-documents'),
    ]);
    await tab(tester, FamilySection.documents);
    expect(
      tester
          .widget<FamilyNavigationBar>(find.byType(FamilyNavigationBar))
          .selected,
      FamilySection.documents,
    );
    await tester.tap(find.text('Abrir documento de ejemplo'));
    await tester.pumpAndSettle();
    await tab(tester, FamilySection.diary);
    await tab(tester, FamilySection.documents);
    expect(
      find.text('Documento de ejemplo abierto').hitTestable(),
      findsOneWidget,
    );
    final navigation = tester.state<FamilyNavigationState>(
      find.byType(FamilyNavigation),
    );
    await navigation.back();
    await tester.pumpAndSettle();
    expect(find.text('Sección documents').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview and hito map entry keep callbacks and origin on back', (
    tester,
  ) async {
    var opened = 0;
    final requests = <int>[];
    await show(
      tester,
      onMapOpened: () => opened++,
      onMapRequested: requests.add,
    );
    for (final origin in [FamilySection.home, FamilySection.documents]) {
      await tab(tester, origin);
      await tester.tap(find.text('Abrir mapa').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(FamilyNavigationBar), findsNothing);
      await tester.tap(find.text('Volver del mapa'));
      await tester.pumpAndSettle();
      expect(find.text('Sección ${origin.name}').hitTestable(), findsOneWidget);
    }
    expect(opened, 2);
    await tester.tap(find.text('Ver hito en mapa').hitTestable());
    await tester.pumpAndSettle();
    expect(requests, [910001]);
    expect(opened, 2);
    await tester.tap(find.text('Volver del mapa'));
    await tester.pumpAndSettle();
    expect(find.text('Sección documents').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final layout in [
    (const Size(402, 874), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(874, 402), 1.0),
  ]) {
    testWidgets('coordinator dock fits ${layout.$1} / ${layout.$2}', (
      tester,
    ) async {
      await show(tester, size: layout.$1, textScale: layout.$2);
      for (final section in [
        FamilySection.home,
        FamilySection.diary,
        FamilySection.gallery,
        FamilySection.documents,
      ]) {
        final button = find.byKey(ValueKey('family-tab-${section.name}'));
        expect(button.hitTestable(), findsOneWidget);
        final bounds = tester.getRect(button);
        expect(bounds.width, greaterThanOrEqualTo(44));
        expect(bounds.height, greaterThanOrEqualTo(44));
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(layout.$1.width));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
