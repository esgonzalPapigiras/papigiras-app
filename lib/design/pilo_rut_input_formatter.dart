import 'package:flutter/services.dart';

/// Formats presentation only: the final entered character remains the DV.
/// Never calculates a DV, modifies a credential or truncates an identity.
class PiloRutInputFormatter extends TextInputFormatter {
  const PiloRutInputFormatter();

  static final _separators = RegExp(r'[.\-\s]');
  static final _rutCharacters = RegExp(r'^[0-9]*K?$');

  /// Also useful for an explicitly restored/autofilled value. Invalid text
  /// stays visible for validation instead of silently becoming another RUT.
  static String formatDisplay(String value) {
    final raw = value.replaceAll(_separators, '').toUpperCase();
    if (!_rutCharacters.hasMatch(raw)) return value;
    if (raw.length < 2) return raw;
    final body = raw.substring(0, raw.length - 1);
    final result = StringBuffer();
    for (var i = 0; i < body.length; i++) {
      if (i > 0 && (body.length - i) % 3 == 0) result.write('.');
      result.write(body[i]);
    }
    return '${result.toString()}-${raw[raw.length - 1]}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Respect the keyboard/IME until it commits its composing region.
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final formatted = formatDisplay(newValue.text);
    if (formatted == newValue.text) return newValue;

    int mapOffset(int offset) {
      if (offset < 0) return offset;
      final prefix = newValue.text.substring(
        0,
        offset.clamp(0, newValue.text.length),
      );
      final meaningful = prefix.replaceAll(_separators, '').length;
      var count = 0;
      var result = 0;
      while (result < formatted.length && count < meaningful) {
        if (!_separator(formatted[result])) count++;
        result++;
      }
      // Preserve the side of an already present separator for mid-text edits.
      if (prefix.isNotEmpty && _separator(prefix[prefix.length - 1])) {
        while (result < formatted.length && _separator(formatted[result])) {
          result++;
        }
      }
      return result;
    }

    var selection = newValue.selection;
    if (selection.isValid) {
      var base = mapOffset(selection.baseOffset);
      var extent = mapOffset(selection.extentOffset);
      // A formatting mark is restored after Delete. Move past it so the next
      // Delete removes the next entered character rather than getting stuck.
      // Backspace naturally stays on its left; neither action drops a digit.
      if (_forwardDeletedSeparator(oldValue, newValue)) {
        while (base < formatted.length && _separator(formatted[base])) {
          base++;
        }
        extent = base;
      }
      selection = TextSelection(
        baseOffset: base,
        extentOffset: extent,
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      );
    }
    final composing = newValue.composing.isValid
        ? TextRange.collapsed(mapOffset(newValue.composing.start))
        : TextRange.empty;
    return TextEditingValue(
      text: formatted,
      selection: selection,
      composing: composing,
    );
  }

  static bool _separator(String character) =>
      character == '.' || character == '-' || character.trim().isEmpty;

  static bool _forwardDeletedSeparator(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursor = oldValue.selection.baseOffset;
    return oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        cursor >= 0 &&
        cursor < oldValue.text.length &&
        newValue.selection.baseOffset == cursor &&
        _separator(oldValue.text[cursor]) &&
        oldValue.text.length == newValue.text.length + 1 &&
        oldValue.text.replaceRange(cursor, cursor + 1, '') == newValue.text;
  }
}
