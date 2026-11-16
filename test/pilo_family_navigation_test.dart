import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/family_home.dart';
import 'package:papigiras_app/navigation/family_navigation.dart';

void main() {
  for (final (
        size,
        scale,
        tourCode,
        tripLabel,
        givenNames,
        surnames,
        shortName,
        _,
      )
      in [
        (
          const Size(402, 874),
          1.0,
          'BRC26910001A',
          'Gira a Bariloche',
          'SOFÍA ISABEL',
          'GONZÁLEZ RÍOS',
          'Sofía González',
          'Sofía Isabel González Ríos',
        ),
        (
          const Size(320, 568),
          2.0,
          'CMB26910002B',
          'Gira a Camboriú',
          '  MARÍA-JOSÉ   ELENA ',
          'DE LA CRUZ PÉREZ',
          'María-José De la Cruz',
          'María-José Elena De la Cruz Pérez',
        ),
        (
          const Size(402, 874),
          1.0,
          ' pcn26910003c ',
          'Gira a Pucón',
          'ÁLVARO TOMÁS',
          '',
          'Álvaro',
          'Álvaro Tomás',
        ),
        (
          const Size(402, 874),
          1.0,
          'XYZ26910004A',
          'Destino · XYZ',
          '',
          'null VARGAS',
          'Vargas',
          'Vargas',
        ),
      ]) {
    testWidgets(
      'Pilo shows $tripLabel and keeps links reachable at $size / $scale',
      (tester) async {
        tester.view.physicalSize = size;
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
            home: FamilyNavigation(
              pilo: true,
              immersiveMap: true,
              builders: {
                for (final section in FamilySection.values)
                  section: (context) {
                    final nav = FamilyNavigationScope.maybeOf(context)!;
                    return Scaffold(
                      body: section == FamilySection.home
                          ? FamilyHome(
                              showNavigation: false,
                              givenNames: givenNames,
                              surnames: surnames,
                              rut: 'LAB-910011',
                              school: 'COLEGIO DE PRUEBA DEL RÍO',
                              course: '3° Medio B',
                              year: '2026',
                              departure: '2026-12-29',
                              returnDate: '2027-01-04',
                              tourCode: tourCode,
                              avatar: const CircleAvatar(radius: 36),
                              map: GestureDetector(
                                onTap: () => nav.select(FamilySection.map),
                                child: const ColoredBox(color: Colors.black),
                              ),
                              onMedical: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const Scaffold(
                                    body: Text('Ficha ficticia'),
                                  ),
                                ),
                              ),
                              onDiary: () => nav.select(FamilySection.diary),
                              onCrew: () => nav.select(FamilySection.crew),
                              onDocuments: () =>
                                  nav.select(FamilySection.documents),
                              onMap: () => nav.select(FamilySection.map),
                              onGallery: () =>
                                  nav.select(FamilySection.gallery),
                            )
                          : section == FamilySection.map
                          ? TextButton(
                              key: const ValueKey('back-from-map'),
                              onPressed: nav.back,
                              child: const Text('Sección map'),
                            )
                          : Text('Sección ${section.name}'),
                    );
                  },
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final name = find.text(shortName);
        final trip = find.text('Colegio de Prueba del Río · 3° Medio B · 2026');
        final departure = find.byKey(const ValueKey('family-trip-departure'));
        final returnDate = find.byKey(const ValueKey('family-trip-return'));
        final map = find.byKey(const ValueKey('family-map-card'));
        final destination = find.text(tripLabel);
        for (final element in [
          name,
          destination,
          trip,
          departure,
          returnDate,
          map,
        ]) {
          expect(element, findsOneWidget);
        }
        expect(
          tester.getTopLeft(name).dy,
          lessThan(tester.getTopLeft(trip).dy),
        );
        expect(
          tester.getTopLeft(trip).dy,
          lessThan(tester.getTopLeft(departure).dy),
        );
        expect(
          tester.getBottomLeft(returnDate).dy,
          lessThan(tester.getTopLeft(map).dy),
        );

        Future<void> tap(String key, {bool scroll = false}) async {
          final target = find.byKey(ValueKey(key));
          if (scroll) await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        expect(find.byKey(const ValueKey('family-tab-crew')), findsNothing);
        expect(
          find.byKey(const ValueKey('family-tab-documents')),
          findsNothing,
        );
        for (final section in ['diary', 'map', 'gallery']) {
          await tap('family-tab-$section');
          expect(find.text('Sección $section').hitTestable(), findsOneWidget);
          if (section == 'map') {
            expect(
              find.byKey(const ValueKey('family-navigation-bar')),
              findsNothing,
            );
            await tap('back-from-map');
            expect(find.text('Sección diary').hitTestable(), findsOneWidget);
          }
        }
        await tap('family-tab-home');
        for (final section in ['crew', 'documents']) {
          await tap('family-trip-details', scroll: true);
          expect(find.text('Datos de la gira'), findsOneWidget);
          final sheet = find.byType(BottomSheet);

          expect(find.descendant(of: sheet, matching: trip), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(ValueKey('family-action-$section')),
              matching: find.byIcon(
                section == 'crew'
                    ? Icons.people_outline_rounded
                    : Icons.description_outlined,
              ),
            ),
            findsOneWidget,
          );
          await tap('family-action-$section', scroll: true);
          expect(find.text('Sección $section').hitTestable(), findsOneWidget);
          await tap('family-tab-home');
        }
        await tap('family-medical', scroll: true);
        expect(find.text('Ficha ficticia').hitTestable(), findsOneWidget);
        await tap('family-tab-diary');
        await tap('family-tab-home');
        expect(find.text('Ficha ficticia').hitTestable(), findsOneWidget);
      },
    );
  }
}
