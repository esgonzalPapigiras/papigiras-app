import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/special_diet_passengers.dart';
import 'package:papigiras_app/dto/PassengerList.dart';

PassengerList person(int id, String name, String? diet, {String sex = 'F'}) =>
    PassengerList.fromJson({
      'passengerId': id,
      'passengerName': name,
      'passengerIdentification': '99.000.${id % 1000}-K',
      'passengerSex': sex,
      'passengerDiet': diet,
    });

void main() {
  test('counts all nonempty nontraditional diets, including companions', () {
    final people = [
      person(910011, 'Sofía Ejemplo LAB', 'Vegetariana'),
      person(910012, 'Mateo Ejemplo LAB', ' VEGANO ', sex: 'AM'),
      person(910013, 'Valentina Ejemplo LAB', 'Celíaca'),
      for (final diet in [
        null,
        '',
        ' ',
        '\t\n',
        '\u00a0',
        'tradicional',
        ' TRADICIONAL ',
      ])
        person(910020, 'Tradicional o sin dieta LAB', diet),
      person(910014, 'Álvaro Ejemplo LAB', 'Sin lactosa', sex: 'PM'),
    ];
    final selected = specialDietPassengers(people);
    expect(selected.map((p) => p.passengerId), [
      910014,
      910012,
      910011,
      910013,
    ]);
    expect(
      people[1].passengerDiet,
      ' VEGANO ',
    ); // Stored text is not rewritten.
  });

  test('missing server field differs from a stored null and roundtrips', () {
    final older = PassengerList.fromJson({'passengerId': 910011});
    final storedNull = person(910011, 'Sofía Ejemplo LAB', null);
    expect(older.hasDietInformation, false);
    expect(older.toJson().containsKey('passengerDiet'), false);
    expect(storedNull.hasDietInformation, true);
    expect(storedNull.toJson()['passengerDiet'], null);
    expect(
      PassengerList.fromJson(storedNull.toJson()).hasDietInformation,
      true,
    );
  });

  Future<void> show(
    WidgetTester tester,
    Future<List<PassengerList>> Function() load, {
    double scale = 1,
    TargetPlatform platform = TargetPlatform.iOS,
  }) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: SpecialDietPassengersScreen(loadPassengers: load),
      ),
    );
  }

  testWidgets(
    'shows only qualifying names, RUT and stored diet in alphabetic order',
    (tester) async {
      var calls = 0;
      await show(tester, () async {
        calls++;
        return [
          person(910011, 'Sofía Ejemplo LAB', 'Vegetariana'),
          person(910012, 'Mateo Ejemplo LAB', 'Vegano', sex: 'AM'),
          person(910013, 'Perfil tradicional LAB', 'Tradicional'),
        ];
      });
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('2 pasajeros'), findsOneWidget);
      expect(find.text('Mateo Ejemplo LAB'), findsOneWidget);
      expect(find.text('RUT: 99.000.12-K'), findsOneWidget);
      expect(find.text('Vegano'), findsOneWidget);
      expect(find.text('Perfil tradicional LAB'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Mateo Ejemplo LAB')).dy,
        lessThan(tester.getTopLeft(find.text('Sofía Ejemplo LAB')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading does not display a false zero', (tester) async {
    final load = Completer<List<PassengerList>>();
    await show(tester, () => load.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('0 pasajeros'), findsNothing);
    load.complete([person(910011, 'Sofía Ejemplo LAB', 'Vegetariana')]);
    await tester.pumpAndSettle();
    expect(find.text('1 pasajero'), findsOneWidget);
  });

  testWidgets('empty excludes traditional and blank values', (tester) async {
    await show(
      tester,
      () async => [
        person(910011, 'Perfil LAB', ' Tradicional '),
        person(910012, 'Otro LAB', null),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('0 pasajeros'), findsOneWidget);
    expect(
      find.text('No hay dietas especiales registradas en esta gira.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'errors and missing fields offer retry without displaying medical or technical details',
    (tester) async {
      var calls = 0;
      await show(tester, () async {
        calls++;
        if (calls == 1) throw StateError('private response must not reach UI');
        if (calls == 2)
          return [
            PassengerList.fromJson({'passengerId': 910011}),
          ];
        return [person(910011, 'Sofía Ejemplo LAB', 'Vegetariana')];
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('private response'), findsNothing);
      for (var i = 0; i < 2; i++) {
        expect(
          find.text('No pudimos cargar las dietas de los pasajeros.'),
          findsOneWidget,
        );
        expect(find.text('0 pasajeros'), findsNothing);
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Sofía Ejemplo LAB'), findsOneWidget);
      expect(calls, 3);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'long names and diet remain readable on $platform text $scale',
        (tester) async {
          const name = 'María de los Ángeles Apellidos Extensos Ejemplo LAB';
          const diet =
              'Dieta especial con una descripción extensa registrada en la gira LAB';
          await show(
            tester,
            () async => [person(910011, name, diet)],
            scale: scale,
            platform: platform,
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text(diet), 150);
          await Scrollable.ensureVisible(
            tester.element(find.text(diet)),
            alignment: 1,
          );
          await tester.pumpAndSettle();
          expect(
            tester.getBottomRight(find.text(diet)).dy,
            lessThanOrEqualTo(
              tester.getBottomRight(find.byType(ListView)).dy + 1,
            ),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
