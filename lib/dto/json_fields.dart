/// Tolerant parsing of optional legacy fields; identities stay mandatory.
/// Error messages never include the returned value or a person's information.
abstract final class JsonFields {
  static String text(dynamic value, [String fallback = '']) => value is String
      ? value
      : value is num
      ? value.toString()
      : fallback;

  static int? optionalInt(dynamic value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return value is String ? int.tryParse(value.trim()) : null;
  }

  static int integer(dynamic value, [int fallback = 0]) =>
      optionalInt(value) ?? fallback;

  static int id(dynamic value) {
    final parsed = optionalInt(value);
    if (parsed == null || parsed <= 0) {
      throw const FormatException(
        'La respuesta local no contiene un identificador válido.',
      );
    }
    return parsed;
  }

  static bool boolean(dynamic value) =>
      value == true ||
      value == 1 ||
      value == '1' ||
      (value is String && value.toLowerCase() == 'true');

  static double decimal(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(text(value)) ?? double.nan;

  static String dateText(dynamic value) {
    if (value is List && value.length >= 3) {
      final y = optionalInt(value[0]);
      final m = optionalInt(value[1]);
      final d = optionalInt(value[2]);
      if (y == null ||
          m == null ||
          d == null ||
          y < 1 ||
          y > 9999 ||
          m < 1 ||
          m > 12 ||
          d < 1 ||
          d > DateTime.utc(y, m + 1, 0).day)
        return '';
      return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    }
    return text(value);
  }

  static List<Map<String, dynamic>> records(dynamic value) {
    if (value == null) return const [];
    if (value is! List ||
        value.any((item) => item != null && item is! Map<String, dynamic>)) {
      throw const FormatException(
        'La respuesta local no contiene una lista válida.',
      );
    }
    return value.whereType<Map<String, dynamic>>().toList();
  }

  static List<String> strings(dynamic value) => value is List
      ? value
            .whereType<String>()
            .where((item) => item.trim().isNotEmpty)
            .toList()
      : const [];
}
