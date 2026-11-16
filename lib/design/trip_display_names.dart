import 'package:intl/intl.dart';

const _nameParticles = {'de', 'del', 'el', 'la', 'las', 'los', 'y'};
final _nameWhitespace = RegExp(r'\s+');
final _nameJoiners = RegExp("[-'’]");

/// Formats passenger names for display. The values used by the API and forms
/// remain the original data. The compact home heading uses the first surname.
String formatStudentName(
  String? givenNames,
  String? surnames, {
  bool short = false,
}) {
  final given = _nameWords(givenNames);
  final family = _nameWords(surnames);
  if (!short) {
    return [
      _formatNameWords(given),
      _formatNameWords(family),
    ].where((part) => part.isNotEmpty).join(' ');
  }

  final firstSurname = <String>[];
  for (final word in family) {
    firstSurname.add(word);
    if (!_nameParticles.contains(word)) break;
  }
  return [
    if (given.isNotEmpty) _capitalizeNameWord(given.first),
    if (firstSurname.isNotEmpty) _formatNameWords(firstSurname),
  ].join(' ');
}

String formatSchoolName(String? name) => _formatNameWords(_nameWords(name));

List<String> _nameWords(String? value) => (value ?? '')
    .trim()
    .toLowerCase()
    .split(_nameWhitespace)
    .where((word) => word.isNotEmpty && word != 'null')
    .toList();

String _formatNameWords(List<String> words) => [
  for (final (index, word) in words.indexed)
    if (index > 0 && _nameParticles.contains(word))
      word
    else
      _capitalizeNameWord(word),
].join(' ');

String _capitalizeNameWord(String word) {
  final capitalized = StringBuffer();
  var start = 0;
  for (final joiner in _nameJoiners.allMatches(word)) {
    capitalized
      ..write(toBeginningOfSentenceCase(word.substring(start, joiner.start)))
      ..write(joiner.group(0)!);
    start = joiner.end;
  }
  capitalized.write(toBeginningOfSentenceCase(word.substring(start)));
  return capitalized.toString();
}
