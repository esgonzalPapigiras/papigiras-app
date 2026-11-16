import '../lab/media.dart';

/// Public export names only. Private previews retain opaque temporary names.
abstract final class MedicalPdfName {
  static String forPassenger(String name, String identification) {
    String part(String value, int max) {
      var ascii = value;
      for (final entry in const {
        'A': 'ÀÁÂÃÄÅ',
        'a': 'àáâãäå',
        'E': 'ÈÉÊË',
        'e': 'èéêë',
        'I': 'ÌÍÎÏ',
        'i': 'ìíîï',
        'O': 'ÒÓÔÕÖ',
        'o': 'òóôõö',
        'U': 'ÙÚÛÜ',
        'u': 'ùúûü',
        'N': 'Ñ',
        'n': 'ñ',
        'C': 'Ç',
        'c': 'ç',
      }.entries) {
        ascii = ascii.replaceAll(RegExp('[${entry.value}]'), entry.key);
      }
      final clean = ascii
          .replaceAll(RegExp(r'[^A-Za-z0-9. -]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return clean.length <= max ? clean : clean.substring(0, max).trimRight();
    }

    final person = part(name, 55);
    final rut = part(identification, 20);
    return LabMedia.safePdfName(
      [
        'Ficha medica',
        if (person.isNotEmpty) person,
        if (rut.isNotEmpty) rut,
      ].join(' - '),
    );
  }

  /// RFC5987 UTF-8 takes precedence over the ASCII Content-Disposition fallback.
  static String fromContentDisposition(String? header, String identification) {
    if (header != null && header.length <= 2048) {
      final encoded = RegExp(
        r"(?:^|;)\s*filename\*\s*=\s*UTF-8''([^;]+)",
        caseSensitive: false,
      ).firstMatch(header)?.group(1);
      if (encoded != null) {
        try {
          return LabMedia.safePdfName(Uri.decodeComponent(encoded.trim()));
        } on FormatException {
          // Invalid UTF-8: use the plain fallback below.
        } on ArgumentError {
          // Invalid percent encoding: use the plain fallback below.
        }
      }
      final plain = RegExp(
        r'(?:^|;)\s*filename\s*=\s*(?:"([^"]+)"|([^;]+))',
        caseSensitive: false,
      ).firstMatch(header);
      final value = plain?.group(1) ?? plain?.group(2);
      if (value != null && value.trim().isNotEmpty) {
        return LabMedia.safePdfName(value.trim());
      }
    }
    return forPassenger('', identification);
  }
}
