import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/utils/passenger_roster_data.dart';

PassengerList person(
  int id,
  String? sex, {
  String? name,
  String? type,
  String medical = '',
  String surname = '',
  String? rut,
  String? diet,
}) => PassengerList(
  passengerName: name ?? 'Persona ficticia $id',
  passengerId: id,
  passengerIdentification: rut ?? 'LAB-$id',
  passengerverificate: false,
  passengerApellidos: surname,
  countMedicalRecordOk: 0,
  countMedicalRecordNoOk: 0,
  statusMedicalRecord: medical,
  passengerSex: sex,
  passengerType: type,
  passengerDiet: diet,
);

void main() {
  test('sexo y categoría se combinan sin inferir códigos desconocidos', () {
    final rows = [
      for (final (index, code) in [
        'M',
        'F',
        'AM',
        'AF',
        'PM',
        'PF',
        'APM',
        'APF',
        'MC',
        'FC',
        'hombre',
        'mujer',
        '',
        null,
      ].indexed)
        person(
          910011 + index,
          code == null ? null : ' ${code.toLowerCase()} ',
          name: 'Persona Demo $index',
          type: index.isEven ? 'M' : 'F',
        ),
    ];
    final counts = RosterCounts(rows);
    expect(counts.male, 4);
    expect(counts.female, 4);
    expect(counts.count(RosterFilter.other), 6);
    expect(rosterPeople(rows).length, 14);
    for (final (category, sex, expected) in [
      (RosterFilter.students, RosterSexFilter.male, {910011}),
      (RosterFilter.students, RosterSexFilter.female, {910012}),
      (RosterFilter.companions, RosterSexFilter.male, {910013, 910015, 910017}),
      (
        RosterFilter.companions,
        RosterSexFilter.female,
        {910014, 910016, 910018},
      ),
      (
        RosterFilter.all,
        RosterSexFilter.male,
        {910011, 910013, 910015, 910017},
      ),
      (
        RosterFilter.all,
        RosterSexFilter.female,
        {910012, 910014, 910016, 910018},
      ),
    ]) {
      expect(
        rosterPeople(
          rows,
          filter: category,
          sexFilter: sex,
        ).map((person) => person.passengerId).toSet(),
        expected,
      );
    }
    for (final sex in [RosterSexFilter.male, RosterSexFilter.female]) {
      expect(
        rosterPeople(rows, filter: RosterFilter.other, sexFilter: sex),
        isEmpty,
      );
    }
    expect(RosterCounts(const []).male, 0);
    expect(RosterCounts(const []).female, 0);
  });

  test(
    'sexo se intersecta con ficha, dieta y búsqueda, sin modificar datos',
    () {
      final rows = [
        person(910011, 'APF', name: 'Alicia Demo', diet: 'Vegetariana'),
        person(910012, 'APF', name: 'Beatriz Demo', diet: 'Sin gluten'),
        person(910013, 'APM', name: 'Carlos Demo', diet: 'Vegetariana'),
        person(
          910014,
          'APF',
          name: 'Diana Demo',
          medical: 'Lleno',
          diet: 'Vegetariana',
        ),
        person(910015, 'APF', name: 'Elena Demo', diet: 'Tradicional'),
        person(910016, 'F', name: 'Flora Demo', diet: 'Vegetariana'),
        person(910017, 'APF', name: 'Gabriela Ensayo', diet: 'Vegetariana'),
      ];
      final originals = rows.map((person) => person.toJson()).toList();
      expect(
        rosterPeople(
          rows,
          filter: RosterFilter.companions,
          sexFilter: RosterSexFilter.female,
          medicalFilter: RosterMedicalFilter.missing,
          specialDietOnly: true,
          query: 'Demo',
          ascending: false,
        ).map((person) => person.passengerId),
        [910012, 910011],
      );
      expect(rows.map((person) => person.toJson()).toList(), originals);
    },
  );

  test(
    'clasifica los códigos confirmados y variantes P sin inferir del nombre ni del tipo',
    () {
      final expected = {
        'M': RosterFilter.studentsMale,
        'F': RosterFilter.studentsFemale,
        'AM': RosterFilter.companionsMale,
        'AF': RosterFilter.companionsFemale,
        'PM': RosterFilter.companionsMale,
        'APM': RosterFilter.companionsMale,
        'PF': RosterFilter.companionsFemale,
        'APF': RosterFilter.companionsFemale,
      };
      for (final entry in expected.entries) {
        expect(
          rosterCategory(person(1, entry.key, type: 'dato desactualizado')),
          entry.value,
        );
      }
      for (final unknown in [null, '', 'MC', 'FC', 'hombre', 'mujer', 'otro']) {
        expect(
          rosterCategory(
            person(1, unknown, name: 'Nombre femenino de prueba', type: 'F'),
          ),
          RosterFilter.other,
        );
      }
    },
  );

  test(
    'cuenta grupos de respuesta actual y conserva todos los sin clasificar',
    () {
      final rows = [
        person(1, 'M'),
        person(2, 'M'),
        person(3, 'F'),
        person(4, 'AM'),
        person(5, 'AF'),
        person(6, 'AF'),
        person(7, 'PM'),
        person(8, 'PF'),
        person(9, 'MC'),
        person(10, null),
      ];
      final counts = RosterCounts(rows);
      expect(counts.students, 3);
      expect(counts.companions, 5);
      expect(counts.count(RosterFilter.other), 2);
      expect(counts.count(RosterFilter.all), 10);
      expect(
        rosterPeople(
          rows,
          filter: RosterFilter.other,
        ).map((p) => p.passengerId).toSet(),
        {9, 10},
      );
      expect(rosterPeople(rows).length, rows.length);
    },
  );

  test('ordena A–Z y Z–A sin mutar los datos ni perder acentos', () {
    final rows = [
      person(1, 'M', name: 'Zeta Demo'),
      person(2, 'F', name: 'Álvaro Demo'),
      person(3, 'AF', name: 'Bea Demo'),
    ];
    expect(rosterPeople(rows).map(rosterName), [
      'Álvaro Demo',
      'Bea Demo',
      'Zeta Demo',
    ]);
    expect(rosterPeople(rows, ascending: false).map(rosterName), [
      'Zeta Demo',
      'Bea Demo',
      'Álvaro Demo',
    ]);
    expect(rows.first.passengerId, 1);
    expect(rosterName(person(4, null, name: '  ')), 'Nombre no disponible');
  });

  test('disponibilidad médica requiere exactamente el estado Lleno', () {
    expect(hasSavedMedicalRecord(person(1, 'M', medical: 'Lleno')), isTrue);
    for (final status in ['', 'lleno', 'Lleno ', 'Completo', 'Vacío']) {
      expect(hasSavedMedicalRecord(person(1, 'M', medical: status)), isFalse);
    }
  });

  test(
    'campos ausentes siguen siendo compatibles y no clasifican por tipo',
    () {
      final parsed = PassengerList.fromJson(
        person(1, null).toJson()
          ..remove('passengerSex')
          ..remove('passengerType'),
      );
      expect(parsed.passengerSex, isNull);
      expect(parsed.passengerType, isNull);
      expect(rosterCategory(parsed), RosterFilter.other);
    },
  );

  test(
    'inicio suma AM+PM+APM y AF+PF+APF sin incluir alumnos ni otros códigos',
    () {
      final counts = {
        'M': 21,
        'F': 24,
        'AM': 2,
        'PM': 3,
        'APM': 4,
        'AF': 5,
        'PF': 6,
        'APF': 7,
        'MC': 30,
        'FC': 40,
        'otro': 50,
      };
      expect(rosterCompanionCount(counts, male: true), 9);
      expect(rosterCompanionCount(counts, male: false), 18);
      expect(rosterCompanionCount(const {}, male: true), 0);
      expect(counts['M'], 21);
      expect(counts['F'], 24);
      expect(counts['MC'], 30);
      expect(counts['FC'], 40);
    },
  );

  test('búsqueda por nombre, apellido separado y RUT con o sin formato', () {
    final row = person(
      910011,
      'F',
      name: 'Sofía',
      surname: 'Núñez Ejemplo LAB',
      rut: '99.000.115-K',
    );
    for (final term in [
      '',
      '   ',
      'SOFIA',
      'núñez',
      'nunez',
      'NÚÑEZ',
      'Ejemplo Sofía',
      '99.000.115-k',
      '99000115K',
      '99 000 115 k',
      '000115',
    ]) {
      expect(rosterMatchesQuery(row, term), isTrue, reason: term);
    }
    for (final term in ['Mateo', '910011', 'Sofia inexistente', '99000116']) {
      expect(rosterMatchesQuery(row, term), isFalse, reason: term);
    }
  });

  test('buscador combina categorías, orden y totales sin mutar pasajeros', () {
    final rows = [
      person(910011, 'F', name: 'Sofía Demo'),
      person(910012, 'M', name: 'Mateo Demo'),
      person(910013, 'APF', name: 'Valentina Demo'),
    ];
    final counts = RosterCounts(rows);
    expect(counts.count(RosterFilter.students), 2);
    expect(counts.count(RosterFilter.companions), 1);
    expect(
      rosterPeople(
        rows,
        query: 'DEMO',
        filter: RosterFilter.students,
      ).map((p) => p.passengerId),
      [910012, 910011],
    );
    expect(
      rosterPeople(rows, query: 'sofia', filter: RosterFilter.companions),
      isEmpty,
    );
    expect(
      rosterPeople(rows, filter: RosterFilter.companions).single.passengerId,
      910013,
    );
    expect(rows.map((p) => p.passengerId), [910011, 910012, 910013]);
    expect(counts.count(RosterFilter.all), 3);
  });

  test(
    'indicador de dieta excluye tradicional y vacíos, mantiene otras dietas',
    () {
      for (final diet in [null, '', '  ', 'tradicional', ' TRADICIONAL ']) {
        expect(hasSpecialDiet(person(910011, 'F', diet: diet)), isFalse);
      }
      for (final diet in ['Vegetariana', 'vegano', 'Celíaco', 'Sin lactosa']) {
        expect(hasSpecialDiet(person(910011, 'F', diet: diet)), isTrue);
      }
    },
  );

  test(
    'categoría, ficha, dieta y búsqueda se intersectan sin perder datos',
    () {
      final rows = [
        person(
          910011,
          'M',
          name: 'Álvaro Ensayo',
          medical: 'Lleno',
          diet: 'Vegetariana',
        ),
        person(910012, 'F', name: 'Bea Ensayo', diet: 'Vegetariana'),
        person(
          910013,
          'APM',
          name: 'Carla Ensayo',
          medical: 'Lleno',
          diet: 'Sin gluten',
        ),
        person(
          910014,
          'APF',
          name: 'Dora Ensayo',
          medical: 'Lleno ',
          diet: 'Tradicional',
        ),
        person(
          910015,
          null,
          name: 'Elsa Ensayo',
          medical: 'lleno',
          diet: 'Sin lactosa',
        ),
        person(910016, 'FC', name: 'Fabi Ensayo', medical: 'Lleno'),
      ];
      final originals = rows.map((person) => person.toJson()).toList();
      expect(
        rosterPeople(
          rows,
          filter: RosterFilter.students,
          medicalFilter: RosterMedicalFilter.saved,
          specialDietOnly: true,
          query: 'alvaro ENSAYO',
        ).map((person) => person.passengerId),
        [910011],
      );
      expect(
        rosterPeople(
          rows,
          filter: RosterFilter.companions,
          medicalFilter: RosterMedicalFilter.saved,
          specialDietOnly: true,
        ).map((person) => person.passengerId),
        [910013],
      );
      expect(
        rosterPeople(
          rows,
          filter: RosterFilter.companions,
          medicalFilter: RosterMedicalFilter.missing,
          specialDietOnly: true,
        ),
        isEmpty,
      );
      expect(
        rosterPeople(
          rows,
          filter: RosterFilter.other,
          medicalFilter: RosterMedicalFilter.missing,
          specialDietOnly: true,
          query: 'ENSAYO',
        ).single.passengerId,
        910015,
      );
      expect(
        rosterPeople(
          rows,
          medicalFilter: RosterMedicalFilter.missing,
          specialDietOnly: true,
          ascending: false,
        ).map((person) => person.passengerId),
        [910015, 910012],
      );
      expect(rosterPeople(rows).length, rows.length);
      expect(rows.map((person) => person.toJson()).toList(), originals);

      final counts = RosterCounts(rows);
      expect(counts.count(RosterFilter.all), 6);
      expect(counts.students, 2);
      expect(counts.companions, 2);
      expect(counts.count(RosterFilter.other), 2);
      expect(counts.savedMedical, 3);
      expect(counts.missingMedical, 3);
      expect(counts.specialDiets, 4);
    },
  );

  test(
    'alias de acompañante conservan filtros médicos y dietas independientes',
    () {
      final rows = [
        for (final (index, code) in [
          'AM',
          'PM',
          'APM',
          'AF',
          'PF',
          'APF',
        ].indexed)
          person(
            910011 + index,
            ' ${code.toLowerCase()} ',
            medical: index.isEven ? 'Lleno' : '',
            diet: 'Vegetariana',
          ),
        person(910020, 'MC', type: 'AM', medical: 'Lleno', diet: 'Vegetariana'),
        person(910021, null, type: 'AF', medical: 'Lleno', diet: 'Vegetariana'),
      ];
      expect(
        rosterPeople(
          rows,
          filter: RosterFilter.companions,
          medicalFilter: RosterMedicalFilter.saved,
          specialDietOnly: true,
        ).map((person) => person.passengerId).toSet(),
        {910011, 910013, 910015},
      );
      expect(
        rosterPeople(
          rows,
          filter: RosterFilter.companions,
          medicalFilter: RosterMedicalFilter.missing,
          specialDietOnly: true,
        ).map((person) => person.passengerId).toSet(),
        {910012, 910014, 910016},
      );
      expect(
        rosterPeople(
          rows,
          filter: RosterFilter.other,
          medicalFilter: RosterMedicalFilter.saved,
          specialDietOnly: true,
        ).map((person) => person.passengerId).toSet(),
        {910020, 910021},
      );
    },
  );

  test(
    'sin ficha usa el estado guardado exacto sin afirmar validez clínica',
    () {
      final rows = [
        for (final (index, status) in [
          'Lleno',
          '',
          'lleno',
          'Lleno ',
          'Completo',
          'Vacío',
        ].indexed)
          person(910011 + index, 'M', medical: status),
      ];
      expect(
        rosterPeople(
          rows,
          medicalFilter: RosterMedicalFilter.saved,
        ).single.passengerId,
        910011,
      );
      expect(
        rosterPeople(rows, medicalFilter: RosterMedicalFilter.missing).length,
        5,
      );
      final counts = RosterCounts(rows);
      expect(counts.savedMedical + counts.missingMedical, rows.length);
      expect(counts.savedMedical, 1);
      expect(counts.missingMedical, 5);
    },
  );

  test(
    'campos ausentes siguen desconocidos y no se infiere dieta o categoría',
    () {
      final older = PassengerList.fromJson({'passengerId': 910011});
      final storedNull = PassengerList.fromJson({
        'passengerId': 910012,
        'passengerDiet': null,
      });
      final rows = [older, storedNull];
      final counts = RosterCounts(rows);
      expect(counts.savedMedical, 0);
      expect(counts.missingMedical, 2);
      expect(counts.specialDiets, 0);
      expect(counts.count(RosterFilter.other), 2);
      expect(rosterClassificationAvailable(rows), isFalse);
      expect(rosterPeople(rows, specialDietOnly: true), isEmpty);
      expect(older.hasDietInformation, isFalse);
      expect(older.toJson().containsKey('passengerDiet'), isFalse);
      expect(storedNull.hasDietInformation, isTrue);
      expect(storedNull.toJson()['passengerDiet'], isNull);
    },
  );
}
