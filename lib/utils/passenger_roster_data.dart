import 'package:papigiras_app/dto/PassengerList.dart';

enum RosterFilter {
  all,
  students,
  companions,
  studentsMale,
  studentsFemale,
  companionsMale,
  companionsFemale,
  other,
}

/// Independent of the passenger category and diet filters. "Missing" means
/// the response does not mark a saved record; it does not assess medical data.
enum RosterMedicalFilter { all, missing, saved }

/// Sex can be combined with students/companions without replacing that filter.
/// Only the explicit category codes determine this value.
enum RosterSexFilter { all, male, female }

/// Classification follows the explicit codes confirmed by the user. PM/PF
/// are legacy companions; APM/APF are the accepted P-in-the-middle variants.
/// Names, age and stale passengerType values never infer sex or category.
RosterFilter rosterCategory(PassengerList person) =>
    _categoryForCode(person.passengerSex);

RosterFilter _categoryForCode(String? code) =>
    switch (code?.trim().toUpperCase()) {
      'M' => RosterFilter.studentsMale,
      'F' => RosterFilter.studentsFemale,
      'AM' || 'PM' || 'APM' => RosterFilter.companionsMale,
      'AF' || 'PF' || 'APF' => RosterFilter.companionsFemale,
      _ => RosterFilter.other,
    };

/// Uses the same category mapping for the dashboard's existing grouped totals.
/// Student M/F counters remain unchanged; other codes do not become companions.
int rosterCompanionCount(Map<String, int> counts, {required bool male}) {
  final category = male
      ? RosterFilter.companionsMale
      : RosterFilter.companionsFemale;
  return counts.entries
      .where((entry) => _categoryForCode(entry.key) == category)
      .fold(0, (total, entry) => total + entry.value);
}

String rosterFilterLabel(RosterFilter filter) => switch (filter) {
  RosterFilter.all => 'Todos',
  RosterFilter.students => 'Alumnos',
  RosterFilter.companions => 'Acompañantes',
  RosterFilter.studentsMale => 'Alumnos · hombres',
  RosterFilter.studentsFemale => 'Alumnas · mujeres',
  RosterFilter.companionsMale => 'Acompañantes · hombres',
  RosterFilter.companionsFemale => 'Acompañantes · mujeres',
  RosterFilter.other => 'Sin clasificar',
};

String rosterName(PassengerList person) =>
    person.passengerName?.trim().isNotEmpty == true
    ? person.passengerName!.trim()
    : 'Nombre no disponible';

/// Server status means a medical record was saved and is available. It is not
/// a clinical completeness/approval claim; do not infer it from field contents.
bool hasSavedMedicalRecord(PassengerList person) =>
    person.statusMedicalRecord == 'Lleno';

/// Older API responses omit this field entirely. Do not turn missing
/// classification into a factual zero-student/zero-companion summary.
bool rosterClassificationAvailable(Iterable<PassengerList> people) =>
    people.isEmpty ||
    people.any((person) => person.passengerSex?.trim().isNotEmpty == true);

/// Counts are derived from the current response, not dashboard aggregates.
class RosterCounts {
  RosterCounts(Iterable<PassengerList> people) {
    for (final person in people) {
      final category = rosterCategory(person);
      _counts[category] = (_counts[category] ?? 0) + 1;
      if (hasSavedMedicalRecord(person)) {
        _savedMedical++;
      } else {
        _missingMedical++;
      }
      if (hasSpecialDiet(person)) _specialDiets++;
    }
  }

  final Map<RosterFilter, int> _counts = {};
  int _savedMedical = 0;
  int _missingMedical = 0;
  int _specialDiets = 0;

  int get savedMedical => _savedMedical;
  int get missingMedical => _missingMedical;

  /// Counts only the diets supplied by this response. Callers must preserve
  /// the unavailable state when the API omits diet information altogether.
  int get specialDiets => _specialDiets;

  int count(RosterFilter filter) => switch (filter) {
    RosterFilter.all => _counts.values.fold(0, (total, value) => total + value),
    RosterFilter.students => students,
    RosterFilter.companions => companions,
    _ => _counts[filter] ?? 0,
  };
  int get students =>
      count(RosterFilter.studentsMale) + count(RosterFilter.studentsFemale);
  int get companions =>
      count(RosterFilter.companionsMale) + count(RosterFilter.companionsFemale);
  int get male =>
      count(RosterFilter.studentsMale) + count(RosterFilter.companionsMale);
  int get female =>
      count(RosterFilter.studentsFemale) + count(RosterFilter.companionsFemale);
}

List<PassengerList> rosterPeople(
  Iterable<PassengerList> people, {
  RosterFilter filter = RosterFilter.all,
  RosterMedicalFilter medicalFilter = RosterMedicalFilter.all,
  RosterSexFilter sexFilter = RosterSexFilter.all,
  bool specialDietOnly = false,
  bool ascending = true,
  String query = '',
}) {
  final visible = people
      .where(
        (person) =>
            _matchesFilter(person, filter) &&
            _matchesMedicalFilter(person, medicalFilter) &&
            _matchesSexFilter(person, sexFilter) &&
            (!specialDietOnly || hasSpecialDiet(person)) &&
            rosterMatchesQuery(person, query),
      )
      .toList();
  visible.sort((a, b) {
    var order = _nameForSort(
      rosterName(a),
    ).compareTo(_nameForSort(rosterName(b)));
    if (order == 0) order = a.passengerId.compareTo(b.passengerId);
    return ascending ? order : -order;
  });
  return visible;
}

String _nameForSort(String value) {
  var name = value.toLowerCase();
  const accents = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
  };
  for (final accent in accents.entries) {
    name = name.replaceAll(accent.key, accent.value);
  }
  return name;
}

/// Read-only search over the existing roster. No requests, persistence or logs.
/// Names include the separately supplied surname; RUT punctuation is optional.
bool rosterMatchesQuery(PassengerList person, String query) {
  final terms = _searchText(query).trim().split(RegExp(r'\s+'));
  if (terms.length == 1 && terms.first.isEmpty) return true;
  final name = _searchText(
    '${person.passengerName ?? ''} ${person.passengerApellidos ?? ''}',
  );
  final rut = person.passengerIdentification.toLowerCase().replaceAll(
    RegExp(r'[^0-9k]'),
    '',
  );
  return terms.every((term) {
    final rutTerm = term.replaceAll(RegExp(r'[.\-]'), '');
    return name.contains(term) ||
        (RegExp(r'^[0-9]+k?$|^k$').hasMatch(rutTerm) && rut.contains(rutTerm));
  });
}

String _searchText(String value) => _nameForSort(
  value,
).replaceAll('ñ', 'n').replaceAll(RegExp(r'[\u0300-\u036f]'), '');

bool _matchesFilter(PassengerList person, RosterFilter filter) {
  final category = rosterCategory(person);
  return switch (filter) {
    RosterFilter.all => true,
    RosterFilter.students =>
      category == RosterFilter.studentsMale ||
          category == RosterFilter.studentsFemale,
    RosterFilter.companions =>
      category == RosterFilter.companionsMale ||
          category == RosterFilter.companionsFemale,
    _ => category == filter,
  };
}

bool _matchesMedicalFilter(PassengerList person, RosterMedicalFilter filter) =>
    switch (filter) {
      RosterMedicalFilter.all => true,
      RosterMedicalFilter.missing => !hasSavedMedicalRecord(person),
      RosterMedicalFilter.saved => hasSavedMedicalRecord(person),
    };

bool _matchesSexFilter(PassengerList person, RosterSexFilter filter) {
  final category = rosterCategory(person);
  return switch (filter) {
    RosterSexFilter.all => true,
    RosterSexFilter.male =>
      category == RosterFilter.studentsMale ||
          category == RosterFilter.companionsMale,
    RosterSexFilter.female =>
      category == RosterFilter.studentsFemale ||
          category == RosterFilter.companionsFemale,
  };
}

/// PG-023-R1 rule, shared by the home diet list and the passenger badge.
/// An absent/blank diet is not a special diet; retain the stored description.
bool hasSpecialDiet(PassengerList person) {
  final diet = person.passengerDiet?.trim().toLowerCase();
  return diet != null && diet.isNotEmpty && diet != 'tradicional';
}
