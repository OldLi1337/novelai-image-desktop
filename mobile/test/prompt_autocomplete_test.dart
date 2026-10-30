import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/prompts/prompt_autocomplete.dart';

// Mirrors the desktop app's src/text-utils.test.ts.
AutocompleteAnchor anchorFor(String value, int cursor) {
  final word = wordAtCursor(value, cursor);
  return (start: word.start, cursor: cursor, word: word.word);
}

String? complete(String value, String tag) =>
    applyAutocompleteTag(value, anchorFor(value, value.length), tag)?.value;

void main() {
  group('formatTagCount', () {
    test('formats millions', () => expect(formatTagCount(1900000), '1.9M'));
    test('formats thousands', () => expect(formatTagCount(12000), '12k'));
    test('leaves small numbers', () => expect(formatTagCount(420), '420'));
  });

  group('wordAtCursor', () {
    test('returns the latin word left of the cursor', () {
      expect(wordAtCursor('1girl, blue', 11), (word: 'blue', start: 7));
    });

    test('captures CJK runs so Chinese gets suggestions', () {
      expect(wordAtCursor('1girl, 蓝眼', 9).word, '蓝眼');
    });

    test('stops at commas and spaces', () {
      expect(wordAtCursor('a, b', 4).word, 'b');
    });

    test('returns empty at a boundary', () {
      expect(wordAtCursor('a, ', 3).word, '');
    });
  });

  group('applyAutocompleteTag', () {
    test('replaces the word the suggestions were made for, wherever the caret is now',
        () {
      const value = '1girl, blu, smile';
      expect(applyAutocompleteTag(value, anchorFor(value, 10), 'blue hair'),
          (value: '1girl, blue hair, smile', caret: 18));
    });

    test('completes the rest of a partial word and keeps a single separator',
        () {
      expect(
          applyAutocompleteTag('1girl, bluxx , smile',
              anchorFor('1girl, bluxx , smile', 10), 'blue hair'),
          (value: '1girl, blue hair, smile', caret: 18));
      expect(
          applyAutocompleteTag(
              '1girl, blu', anchorFor('1girl, blu', 10), 'blue hair'),
          (value: '1girl, blue hair, ', caret: 18));
      expect(
          applyAutocompleteTag('1girl, blusmile',
                  anchorFor('1girl, blusmile', 10), 'blue hair')
              ?.value,
          '1girl, blue hair, ');
    });

    test('keeps line breaks after the caret', () {
      const value = '1girl, blu\nsmile';
      final next = applyAutocompleteTag(value, anchorFor(value, 10), 'blue hair');
      expect(next, (value: '1girl, blue hair, \nsmile', caret: 18));
      // The caret stays on the first line, right after the inserted ", ".
      expect(next!.value.substring(0, next.caret), '1girl, blue hair, ');
      const blank = '1girl, blu\n\nsmile, red eyes';
      expect(applyAutocompleteTag(blank, anchorFor(blank, 10), 'blue hair'),
          (value: '1girl, blue hair, \n\nsmile, red eyes', caret: 18));
      // Only spaces, tabs and one comma on the caret's line give way.
      const spaced = '1girl, blu ,\t\n  smile';
      expect(
          applyAutocompleteTag(spaced, anchorFor(spaced, 10), 'blue hair')
              ?.value,
          '1girl, blue hair, \n  smile');
      const windows = '1girl, blu \r\nsmile';
      expect(
          applyAutocompleteTag(windows, anchorFor(windows, 10), 'blue hair')
              ?.value,
          '1girl, blue hair, \r\nsmile');
      const nextLineComma = '1girl, blu\n, smile';
      expect(
          applyAutocompleteTag(
                  nextLineComma, anchorFor(nextLineComma, 10), 'blue hair')
              ?.value,
          '1girl, blue hair, \n, smile');
    });

    test('keeps Chinese text right after the caret', () {
      expect(applyAutocompleteTag('蓝眼', anchorFor('蓝眼', 1), 'blue eyes'),
          (value: 'blue eyes, 眼', caret: 11));
      expect(
          applyAutocompleteTag(
              '1girl, 蓝眼微笑', anchorFor('1girl, 蓝眼微笑', 9), 'blue eyes'),
          (value: '1girl, blue eyes, 微笑', caret: 18));
      expect(
          applyAutocompleteTag(
                  '1girl, blu微笑', anchorFor('1girl, blu微笑', 10), 'blue hair')
              ?.value,
          '1girl, blue hair, 微笑');
    });

    test('replaces an already typed multi-word phrase instead of repeating it',
        () {
      expect(
          applyAutocompleteTag(
              '1girl, long ha', anchorFor('1girl, long ha', 14), 'long hair'),
          (value: '1girl, long hair, ', caret: 18));
      expect(complete('1girl，long ha', 'long hair'), '1girl，long hair, ');
      expect(complete('1girl, very ha', 'hat'), '1girl, very hat, ');
      expect(complete('1girl、long ha', 'long hair'), '1girl、long hair, ');
      expect(complete('a girl with long ha', 'long hair'),
          'a girl with long hair, ');
      expect(complete('1girl, Long  ha', 'long hair'), '1girl, long hair, ');
      expect(complete('1girl, long ha', 'long_hair'), '1girl, long_hair, ');
      expect(complete('1girl\nlong ha', 'long hair'), '1girl\nlong hair, ');
    });

    test('keeps weight and bracket syntax in front of a multi-word tag', () {
      expect(complete('{{long ha', 'long hair'), '{{long hair, ');
      expect(complete('1girl, {long ha', 'long hair'), '1girl, {long hair, ');
      expect(complete('1.2::long ha', 'long hair'), '1.2::long hair, ');
      expect(complete('1girl, -1::long ha', 'long hair'),
          '1girl, -1::long hair, ');
      expect(complete('[long ha', 'long hair'), '[long hair, ');
      expect(complete('(very long ha', 'very long hair'), '(very long hair, ');
      expect(complete('1.2::blue hair:: long ha', 'long hair'),
          '1.2::blue hair:: long hair, ');
    });

    test('refuses to insert when the anchored text has changed', () {
      final anchor = anchorFor('1girl, blu', 10);
      expect(applyAutocompleteTag('1girl, red', anchor, 'blue hair'), isNull);
      expect(applyAutocompleteTag('', anchor, 'blue hair'), isNull);
      expect(applyAutocompleteTag('1girl, blu', anchor, ''), isNull);
    });
  });
}
