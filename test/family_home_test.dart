import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/apple_design_trial.dart';
import 'package:papigiras_app/design/family_home.dart';
import 'package:papigiras_app/design/papi_brand_bar.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final item in [
      (const Size(402, 874), 1.0),
      (const Size(320, 568), 1.0),
      (const Size(320, 568), 2.0),
      (const Size(402, 874), 3.0),
      (const Size(844, 390), 1.0),
    ]) {
      testWidgets(
        'bounded family home ${platform.name} ${item.$1}, text ${item.$2}',
        (tester) async {
          tester.view.physicalSize = item.$1;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final calls = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(item.$2)),
                child: child!,
              ),
              home: AppleDesignTrialScope(
                child: Scaffold(
                  body: Column(
                    children: [
                      const PapiBrandBar(),
                      Expanded(
                        child: FamilyHome(
                          givenNames: 'Sofía Ejemplo LAB',
                          surnames: 'de Apellido Extenso',
                          rut: 'LAB-910011',
                          school:
                              'Colegio de Demostración con Nombre Extenso LAB',
                          course: '3B',
                          year: '2026',
                          departure: '2026-10-26',
                          returnDate: '2026-11-01',
                          tourCode: 'BRC26910001A',
                          avatar: const SizedBox.square(
                            dimension: 72,
                            child: CircleAvatar(child: Icon(Icons.person)),
                          ),
                          map: GestureDetector(
                            onTap: () => calls.add('map'),
                            child: const ColoredBox(color: Colors.grey),
                          ),
                          onMedical: () => calls.add('medical'),
                          onDiary: () => calls.add('diary'),
                          onCrew: () => calls.add('crew'),
                          onDocuments: () => calls.add('documents'),
                          onMap: () => calls.add('map-button'),
                          onGallery: () => calls.add('gallery'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(Scrollable), findsNothing);
          final map = find.byKey(const ValueKey('family-map-card'));
          expect(tester.getSize(map).height, greaterThan(120));
          final original = tester.getRect(map);
          await tester.drag(map, const Offset(0, -120));
          await tester.pumpAndSettle();
          expect(tester.getRect(map), original);
          await tester.tap(map);
          expect(calls, ['map']);
          for (final id in [
            'medical',
            'action-diary',
            'action-crew',
            'action-documents',
            'action-map',
            'action-gallery',
          ]) {
            final button = find.byKey(ValueKey('family-$id'));
            expect(button.hitTestable(), findsOneWidget);
            expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
            await tester.tap(button);
            await tester.pumpAndSettle();
          }
          expect(calls, [
            'map',
            'medical',
            'diary',
            'crew',
            'documents',
            'map-button',
            'gallery',
          ]);
          final positions = ['crew', 'documents', 'diary', 'map', 'gallery']
              .map(
                (id) => tester
                    .getCenter(find.byKey(ValueKey('family-action-$id')))
                    .dx,
              )
              .toList();
          expect(positions, orderedEquals([...positions]..sort()));
          final compact = find.byKey(const ValueKey('family-compact-details'));
          final details = compact.evaluate().isEmpty
              ? find.byKey(const ValueKey('family-trip-details'))
              : compact;
          await tester.tap(details);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('RUT LAB-910011'), findsOneWidget);
          expect(find.text('Salida · 26/10/2026'), findsOneWidget);
          expect(find.text('Regreso · 01/11/2026'), findsOneWidget);
          await tester.ensureVisible(find.text('Cerrar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cerrar'));
          await tester.pumpAndSettle();
          expect(tester.getRect(map), original);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
