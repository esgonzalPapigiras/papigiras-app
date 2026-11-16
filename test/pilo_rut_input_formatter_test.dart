import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/design/pilo_rut_input_formatter.dart';

const formatter = PiloRutInputFormatter();
TextEditingValue value(String text, [int? caret]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret ?? text.length),
);
String significant(String text) =>
    text.replaceAll(RegExp(r'[.\-\s]'), '').toUpperCase();
TextEditingValue edit(TextEditingValue old, String text, [int? caret]) =>
    formatter.formatEditUpdate(old, value(text, caret));

void main() {
  test(
    'typing progressively inserts punctuation and keeps caret at the end',
    () {
      var current = value('');
      const input = '990000018'; // Synthetic LAB identity, never queried.
      const expected = [
        '9',
        '9-9',
        '99-0',
        '990-0',
        '9.900-0',
        '99.000-0',
        '990.000-0',
        '9.900.000-1',
        '99.000.001-8',
      ];
      for (var i = 0; i < input.length; i++) {
        current = edit(current, current.text + input[i]);
        expect(current.text, expected[i]);
        expect(current.selection.baseOffset, current.text.length);
      }
    },
  );

  test('pasted raw, formatted and whitespace wrapped RUTs agree', () {
    for (final input in ['990000018', '99.000.001-8', ' 99.000.001-8\n']) {
      final result = edit(value(''), input);
      expect(result.text, '99.000.001-8');
      expect(result.selection.baseOffset, 12);
    }
  });

  test('accepts lowercase K, preserves DV, and retains leading zeros', () {
    expect(edit(value(''), '99000001k').text, '99.000.001-K');
    expect(edit(value(''), '00000001k').text, '00.000.001-K');
    expect(edit(value(''), 'k').text, 'K');
    for (final dv in '0123456789K'.split('')) {
      expect(
        PiloRutInputFormatter.formatDisplay('99000001$dv'),
        '99.000.001-$dv',
      );
    }
  });

  test(
    'invalid characters stay visible rather than forming a different identity',
    () {
      for (final input in [
        '99O000018',
        '99.000.001-x',
        '99K000018',
        '99.000.001-KK',
        '９９０００００１８',
        '99/000/001/8',
      ]) {
        final proposed = value(input);
        expect(
          formatter.formatEditUpdate(value('99.000.001-8'), proposed),
          proposed,
        );
      }
    },
  );

  test(
    'overlong input is never silently truncated or assigned a different DV',
    () {
      final input = '${List.filled(20, '0').join()}99000001k';
      final result = edit(value(''), input);
      expect(significant(result.text), input.toUpperCase());
      expect(result.text.endsWith('-K'), isTrue);
      expect(result.selection.extentOffset, result.text.length);
    },
  );

  test('middle replacement and insertion retain logical caret', () {
    final old = value('99.000.001-8', 4);
    final replacement = edit(old, '99.020.001-8', 5);
    expect(replacement.text, '99.020.001-8');
    expect(replacement.selection.baseOffset, 5);
    final insertion = edit(old, '99.0700.001-8', 5);
    expect(insertion.text, '990.700.001-8');
    expect(insertion.selection.baseOffset, 5);
    expect(
      significant(insertion.text.substring(0, insertion.selection.baseOffset)),
      '9907',
    );
  });

  test('reversed range and affinity survive newly inserted separators', () {
    final result = formatter.formatEditUpdate(
      value(''),
      const TextEditingValue(
        text: '990000018',
        selection: TextSelection(
          baseOffset: 7,
          extentOffset: 2,
          affinity: TextAffinity.upstream,
          isDirectional: true,
        ),
      ),
    );
    expect(result.text, '99.000.001-8');
    expect(result.selection.baseOffset, 9);
    expect(result.selection.extentOffset, 2);
    expect(result.selection.affinity, TextAffinity.upstream);
    expect(result.selection.isDirectional, isTrue);
  });

  test(
    'selecting and replacing all text preserves pasted content and cursor',
    () {
      final old = const TextEditingValue(
        text: '99.000.001-8',
        selection: TextSelection(baseOffset: 0, extentOffset: 12),
      );
      final result = edit(old, '99000011k');
      expect(result.text, '99.000.011-K');
      expect(result.selection.baseOffset, 12);
      expect(edit(old, '').text, isEmpty);
    },
  );

  test(
    'backspace next to a dot crosses it then deletes only the intended digit',
    () {
      final old = value('99.000.001-8', 3);
      final crossing = edit(old, '99000.001-8', 2);
      expect(crossing.text, old.text);
      expect(crossing.selection.baseOffset, 2);
      final deletion = edit(crossing, '9.000.001-8', 1);
      expect(deletion.text, '9.000.001-8');
      expect(deletion.selection.baseOffset, 1);
      expect(significant(deletion.text), '90000018');
    },
  );

  test(
    'forward delete crosses a dot and does not get trapped on formatting',
    () {
      final old = value('99.000.001-8', 2);
      final crossing = edit(old, '99000.001-8', 2);
      expect(crossing.text, old.text);
      expect(crossing.selection.baseOffset, 3);
      final deletion = edit(crossing, '99.00.001-8', 3);
      expect(significant(deletion.text), '99000018');
      expect(
        significant(deletion.text.substring(0, deletion.selection.baseOffset)),
        '99',
      );
    },
  );

  test('backspace and forward delete cross a hyphen without losing DV', () {
    final back = edit(value('99.000.001-8', 11), '99.000.0018', 10);
    expect(back.text, '99.000.001-8');
    expect(back.selection.baseOffset, 10);
    final forward = edit(value('99.000.001-8', 10), '99.000.0018', 10);
    expect(forward.text, '99.000.001-8');
    expect(forward.selection.baseOffset, 11);
  });

  test('repeated end backspace can clear the whole field', () {
    var current = value('99.000.001-8');
    var count = 0;
    while (current.text.isNotEmpty && count < 20) {
      final cursor = current.selection.baseOffset;
      current = edit(
        current,
        current.text.replaceRange(cursor - 1, cursor, ''),
        cursor - 1,
      );
      count++;
    }
    expect(current.text, isEmpty);
    expect(current.selection.baseOffset, 0);
    expect(count, lessThan(20));
  });

  test('active composing input is untouched until IME commits', () {
    const proposed = TextEditingValue(
      text: '99000001k',
      selection: TextSelection.collapsed(offset: 9),
      composing: TextRange(start: 0, end: 9),
    );
    expect(formatter.formatEditUpdate(value(''), proposed), proposed);
    final committed = formatter.formatEditUpdate(
      proposed,
      proposed.copyWith(composing: TextRange.empty),
    );
    expect(committed.text, '99.000.001-K');
    expect(committed.composing, TextRange.empty);
  });

  test('caret-only movement and unknown selection are preserved', () {
    final old = value('99.000.001-8');
    final moved = value(old.text, 2);
    expect(formatter.formatEditUpdate(old, moved), moved);
    final unknown = formatter.formatEditUpdate(
      value(''),
      const TextEditingValue(text: '990000018'),
    );
    expect(unknown.text, '99.000.001-8');
    expect(unknown.selection.isValid, isFalse);
  });

  test(
    'formatting is idempotent and preserves every entered symbol across lengths',
    () {
      final random = Random(420);
      for (var length = 1; length <= 40; length++) {
        for (var sample = 0; sample < 12; sample++) {
          final digits = List.generate(
            length,
            (_) => random.nextInt(10),
          ).join();
          final raw = sample.isEven ? '${digits}k' : digits;
          final caret = random.nextInt(raw.length + 1);
          final output = edit(value(''), raw, caret);
          expect(significant(output.text), raw.toUpperCase());
          expect(
            significant(output.text.substring(0, output.selection.baseOffset)),
            raw.substring(0, caret).toUpperCase(),
          );
          expect(PiloRutInputFormatter.formatDisplay(output.text), output.text);
        }
      }
    },
  );
}
