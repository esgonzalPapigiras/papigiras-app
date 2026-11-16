import 'dart:convert';
import 'dart:typed_data';

/// Images arrive only as bytes/base64 from the authenticated local API.
/// Stored remote links are never followed, even when returned by the server.
abstract final class LocalImageData {
  static const maxEncodedLength = 20 * 1024 * 1024;

  static Uint8List? decode(dynamic value) {
    if (value is! String || value.isEmpty || value.length > maxEncodedLength)
      return null;
    var encoded = value.trim();
    if (encoded.startsWith('data:')) {
      final separator = encoded.indexOf(',');
      if (separator < 0 ||
          !RegExp(
            r'^data:image/(?:jpeg|jpg|png|gif|webp|bmp);base64$',
          ).hasMatch(encoded.substring(0, separator)))
        return null;
      encoded = encoded.substring(separator + 1);
    } else if (encoded.contains(':') || encoded.startsWith('//')) {
      return null;
    }
    try {
      final bytes = base64Decode(encoded);
      if (bytes.length < 4) return null;
      final png =
          bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 && bytes[3] == 71;
      final jpeg = bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255;
      final gif =
          bytes[0] == 71 && bytes[1] == 73 && bytes[2] == 70 && bytes[3] == 56;
      final bmp = bytes[0] == 66 && bytes[1] == 77;
      final webp =
          bytes.length >= 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
      return png || jpeg || gif || bmp || webp ? bytes : null;
    } on FormatException {
      return null;
    }
  }

  static String encoded(dynamic value) =>
      decode(value) == null ? '' : value as String;
}
