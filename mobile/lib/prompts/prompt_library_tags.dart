// Tags shared by the positive preset library, the negative prompt library and
// the custom prompt chunks. Tags only organize saved entries; they never enter
// a prompt. Mirrors the desktop app's src/prompt-library-tags.ts, so both apps
// store and read the same `tags` arrays.

const promptTagLimit = 12;
const promptTagMaxLength = 24;

/// Filter value for entries without any tag. Not a valid tag itself.
const untaggedPromptFilter = '\u0000untagged';

final _tagSeparators = RegExp(r'[,，、;；\n\r]+');

String _cleanTag(Object? value) {
  if (value is! String) return '';
  final tag = value
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(RegExp(r'^#+\s*'), '')
      .trim();
  return (tag.length > promptTagMaxLength
          ? tag.substring(0, promptTagMaxLength)
          : tag)
      .trim();
}

/// Trims, drops empty values, de-duplicates case-insensitively (the first
/// spelling wins) and keeps at most [promptTagLimit] tags. Accepts a stored
/// list or comma-separated editor text.
List<String> normalizePromptTags(Object? value) {
  final raw = value is String
      ? value.split(_tagSeparators)
      : value is Iterable
          ? value
          : const [];
  final seen = <String>{};
  final tags = <String>[];
  for (final item in raw) {
    final tag = _cleanTag(item);
    if (tag.isEmpty || !seen.add(tag.toLowerCase())) continue;
    tags.add(tag);
    if (tags.length >= promptTagLimit) break;
  }
  return tags;
}

/// The `tags` entry of a saved entry's JSON. Omitted when there is no tag, so
/// untagged entries keep their previous stored shape.
Map<String, List<String>> promptTagField(Object? value) {
  final tags = normalizePromptTags(value);
  return tags.isEmpty ? const {} : {'tags': tags};
}

String formatPromptTagInput(Iterable<String>? tags) =>
    (tags ?? const <String>[]).join(', ');

/// Appends one tag to comma-separated editor text unless it is already there.
String addPromptTagToInput(String text, String tag) =>
    formatPromptTagInput(normalizePromptTags([...normalizePromptTags(text), tag]));

List<String> mergePromptTags(Iterable<Iterable<Object?>?> lists) =>
    normalizePromptTags([for (final list in lists) ...?list]);

typedef PromptTagCount = ({String tag, int count});

/// Every tag in use with its entry count, most used first, then alphabetical.
/// [entries] holds the tags of each saved entry.
List<PromptTagCount> collectPromptTags(Iterable<List<String>> entries) {
  final spellings = <String, String>{};
  final counts = <String, int>{};
  for (final entry in entries) {
    for (final tag in normalizePromptTags(entry)) {
      final key = tag.toLowerCase();
      spellings.putIfAbsent(key, () => tag);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final result = [
    for (final key in counts.keys) (tag: spellings[key]!, count: counts[key]!)
  ];
  result.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    final byName = a.tag.toLowerCase().compareTo(b.tag.toLowerCase());
    return byName != 0 ? byName : a.tag.compareTo(b.tag);
  });
  return result;
}

/// True when the selected filter chip no longer exists: no entry carries that
/// tag any more, or it is the untagged filter and every entry now has a tag.
bool isStalePromptTagFilter(Iterable<List<String>> entries, String value) {
  if (value.isEmpty) return false;
  if (value == untaggedPromptFilter) {
    return entries.every((tags) => normalizePromptTags(tags).isNotEmpty);
  }
  final key = value.toLowerCase();
  return !entries.any((tags) =>
      normalizePromptTags(tags).any((tag) => tag.toLowerCase() == key));
}

/// Library search. `#tag` tokens must match one of the entry's [tags] (exact,
/// case-insensitive; a tag with spaces takes the following words, as in
/// `#night sky`). The remaining text is matched as one phrase against [fields]
/// and the tags. [activeTag] is the selected filter chip, or
/// [untaggedPromptFilter].
bool matchesPromptLibraryEntry(
  List<String> tags,
  List<String> fields,
  String query, [
  String activeTag = '',
]) {
  final keys = normalizePromptTags(tags).map((tag) => tag.toLowerCase()).toList();
  if (activeTag == untaggedPromptFilter) {
    if (keys.isNotEmpty) return false;
  } else if (activeTag.isNotEmpty && !keys.contains(activeTag.toLowerCase())) {
    return false;
  }
  final words = <String>[];
  final tokens = query
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
  for (var index = 0; index < tokens.length; index++) {
    final word = tokens[index];
    if (word.length > 1 && word.startsWith('#')) {
      // The longest run of words that names one of the entry's tags.
      var candidate = _cleanTag(word).toLowerCase();
      var last = keys.contains(candidate) ? index : -1;
      for (var next = index + 1;
          next < tokens.length &&
              keys.any((tag) => tag.startsWith('$candidate '));
          next++) {
        candidate += ' ${tokens[next].toLowerCase()}';
        if (keys.contains(candidate)) last = next;
      }
      if (last < 0) return false;
      index = last;
    } else {
      words.add(word);
    }
  }
  final phrase = words.join(' ').toLowerCase();
  if (phrase.isEmpty) return true;
  return [...fields, ...keys]
      .any((field) => field.toLowerCase().contains(phrase));
}

typedef PromptTagText = ({
  String tags,
  String tagsHint,
  String tagsPlaceholder,
  String filter,
  String all,
  String untagged,
  String addTag,
  String searchHint,
});

const PromptTagText promptTagText = (
  tags: '标签',
  tagsHint: '用逗号分隔多个标签；标签只用于整理和筛选，不会写入提示词。',
  tagsPlaceholder: '例如：角色, 服装, 夜景',
  filter: '按标签浏览',
  all: '全部',
  untagged: '未加标签',
  addTag: '添加标签',
  searchHint: '搜索名称、内容或标签；输入 #标签 可精确筛选',
);
