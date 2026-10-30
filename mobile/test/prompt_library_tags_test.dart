import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/prompts/prompt_append.dart';
import 'package:novelai_mobile/prompts/prompt_library_tags.dart';

// Mirrors the desktop app's src/prompt-library-tags.test.tsx.
void main() {
  group('saved prompt tags', () {
    test('normalizes typed or stored tags without touching their spelling', () {
      expect(normalizePromptTags(' 角色, #服装，夜景 ; night  sky\n角色 '),
          ['角色', '服装', '夜景', 'night sky']);
      expect(normalizePromptTags(['Outfit', 'outfit', '', 3, null, '#  Night']),
          ['Outfit', 'Night']);
      expect(normalizePromptTags(null), isEmpty);
      expect(normalizePromptTags({'tags': ['x']}), isEmpty);
      expect(normalizePromptTags(['x' * 80]).single,
          hasLength(promptTagMaxLength));
      expect(normalizePromptTags([for (var i = 0; i < 40; i++) 't$i']),
          hasLength(promptTagLimit));
      expect(normalizePromptTags('a、b；c;d\r\ne'), ['a', 'b', 'c', 'd', 'e']);
    });

    test('omits the field for untagged entries so their stored shape is unchanged',
        () {
      expect(promptTagField(<String>[]), isEmpty);
      expect(promptTagField(' , '), isEmpty);
      expect(promptTagField('a, b'), {
        'tags': ['a', 'b']
      });
      expect(
          mergePromptTags([
            ['a', 'B'],
            null,
            ['b', 'c']
          ]),
          ['a', 'B', 'c']);
    });

    test('adds a suggested tag to the editor text once', () {
      expect(addPromptTagToInput('', '角色'), '角色');
      expect(addPromptTagToInput('角色, 服装', '夜景'), '角色, 服装, 夜景');
      expect(addPromptTagToInput('角色, 服装', '服装'), '角色, 服装');
      expect(formatPromptTagInput(['角色', 'night sky']), '角色, night sky');
      expect(formatPromptTagInput(null), '');
    });

    test('counts tags across a library, most used first', () {
      expect(
          collectPromptTags([
            ['b', 'a'],
            ['A'],
            [],
            ['c', 'a'],
          ]),
          [
            (tag: 'a', count: 3),
            (tag: 'b', count: 1),
            (tag: 'c', count: 1),
          ]);
      expect(
          collectPromptTags([
            ['夜景'],
            ['夜景', 'city'],
          ]),
          [(tag: '夜景', count: 2), (tag: 'city', count: 1)]);
      // Ties are alphabetical without regard to case.
      expect(
          collectPromptTags([
            ['Banana', 'apple']
          ]).map((item) => item.tag),
          ['apple', 'Banana']);
    });

    test('filters by chip, #tag token and phrase', () {
      const tags = ['服装', 'Night'];
      const fields = ['夜景少女', '1girl, blue hair, white dress'];
      expect(matchesPromptLibraryEntry(tags, fields, ''), isTrue);
      expect(matchesPromptLibraryEntry(tags, fields, 'blue hair'), isTrue);
      expect(matchesPromptLibraryEntry(tags, fields, 'hair blue'), isFalse);
      expect(matchesPromptLibraryEntry(tags, fields, 'night'), isTrue);
      expect(matchesPromptLibraryEntry(tags, fields, '#服装'), isTrue);
      expect(matchesPromptLibraryEntry(tags, fields, '#服'), isFalse);
      expect(
          matchesPromptLibraryEntry(tags, fields, '#night white dress'), isTrue);
      expect(
          matchesPromptLibraryEntry(tags, fields, '#night red dress'), isFalse);
      expect(matchesPromptLibraryEntry(tags, fields, '', '服装'), isTrue);
      expect(matchesPromptLibraryEntry(tags, fields, '', '角色'), isFalse);
      expect(matchesPromptLibraryEntry(tags, fields, '', untaggedPromptFilter),
          isFalse);
      expect(matchesPromptLibraryEntry([], fields, '', untaggedPromptFilter),
          isTrue);
      expect(matchesPromptLibraryEntry([], ['c# notes'], '#'), isTrue);
    });

    test('matches #tags that contain spaces, preferring the longest tag', () {
      final tags = normalizePromptTags('night sky, 服装');
      expect(matchesPromptLibraryEntry(tags, ['x'], '#night sky'), isTrue);
      expect(matchesPromptLibraryEntry(tags, ['x'], '#Night  Sky #服装'), isTrue);
      expect(matchesPromptLibraryEntry(tags, ['city'], '#night sky city'),
          isTrue);
      expect(
          matchesPromptLibraryEntry(tags, ['x'], '#night sky city'), isFalse);
      expect(matchesPromptLibraryEntry(tags, ['x'], '#night'), isFalse);
      expect(matchesPromptLibraryEntry(tags, ['x'], '#night skyline'), isFalse);
      // Words after a shorter tag stay part of the text search.
      expect(matchesPromptLibraryEntry(['night'], ['sky blue'], '#night sky'),
          isTrue);
      expect(matchesPromptLibraryEntry(['night'], ['x'], '#night sky'), isFalse);
    });

    test('detects a selected filter whose tag or untagged entries are gone', () {
      final items = [
        ['夜景', 'Night Sky'],
        <String>[],
      ];
      expect(isStalePromptTagFilter(items, ''), isFalse);
      expect(isStalePromptTagFilter(items, '夜景'), isFalse);
      expect(isStalePromptTagFilter(items, 'night sky'), isFalse);
      expect(isStalePromptTagFilter(items, untaggedPromptFilter), isFalse);
      expect(isStalePromptTagFilter(items, '角色'), isTrue);
      expect(
          isStalePromptTagFilter([
            ['夜景'],
            ['角色']
          ], untaggedPromptFilter),
          isTrue);
      expect(isStalePromptTagFilter([<String>[]], '夜景'), isTrue);
      expect(isStalePromptTagFilter([], '夜景'), isTrue);
      expect(isStalePromptTagFilter([], untaggedPromptFilter), isTrue);
      expect(isStalePromptTagFilter([], ''), isFalse);
    });

    test('has complete labels', () {
      for (final value in [
        promptTagText.tags,
        promptTagText.tagsHint,
        promptTagText.tagsPlaceholder,
        promptTagText.filter,
        promptTagText.all,
        promptTagText.untagged,
        promptTagText.addTag,
        promptTagText.searchHint,
      ]) {
        expect(value.trim(), isNotEmpty);
      }
    });
  });

  group('appending saved prompt text', () {
    test('joins with one comma and keeps the saved text literal', () {
      expect(appendPromptText('1girl', '1.2::blue hair::, smile'),
          '1girl, 1.2::blue hair::, smile');
      expect(appendPromptText('1girl,', 'smile'), '1girl, smile');
      expect(appendPromptText('1girl,  \n', 'smile'), '1girl, smile');
      expect(appendPromptText('1girl，', 'smile'), '1girl， smile');
      expect(appendPromptText('  ', 'smile'), 'smile');
      expect(appendPromptText('1girl', '  '), '1girl');
      expect(appendPromptText('line one\nline two', 'a\nb'),
          'line one\nline two, a\nb');
    });

    test('inserts a prompt chunk with a trailing separator', () {
      expect(appendPromptChunk('', 'white dress'), 'white dress, ');
      expect(appendPromptChunk('1girl', 'white dress'), '1girl, white dress, ');
      expect(appendPromptChunk('1girl, ', ', white dress,'),
          '1girl, white dress, ');
      expect(appendPromptChunk('1girl', ' , '), '1girl');
    });
  });
}
