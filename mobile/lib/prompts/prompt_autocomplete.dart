// Pure text helpers for the prompt editor's tag autocomplete, kept apart for
// testing. They follow the desktop app's src/text-utils.ts.

/// Formats a Danbooru post count compactly (1900000 -> "1.9M").
String formatTagCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}k';
  return '$count';
}

// Word characters for autocomplete. Includes CJK so Chinese input (e.g. "蓝眼")
// gets suggestions, plus Latin word characters and the hyphen.
final _wordChar = RegExp(r'[\w㐀-鿿-]');

/// The word immediately left of [cursor] and where it starts.
({String word, int start}) wordAtCursor(String text, int cursor) {
  var start = cursor;
  while (start > 0 && _wordChar.hasMatch(text[start - 1])) {
    start--;
  }
  return (word: text.substring(start, cursor), start: start);
}

/// Where an autocomplete session started: the word typed before the caret.
typedef AutocompleteAnchor = ({int start, int cursor, String word});

// The rest of a partly typed Latin word after the caret is replaced with the
// tag. Chinese text there is kept: it has no spaces, so it is the next phrase.
final _wordTailChar = RegExp(r'[\w-]');
// Spaces between the words of a multi-word tag; a line break ends the phrase.
final _wordGap = RegExp(r'[^\S\r\n]');
// Spaces and one comma left on the caret's line give way to the inserted ", ".
final _separatorAfter = RegExp(r'^[^\S\r\n]*(?:,[^\S\r\n]*)?');

/// Tag text compared loosely: case, repeated spaces and "_" for " " do not
/// matter.
String _tagKey(String text) =>
    text.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Replaces the anchored word with a chosen [tag]. The anchor is the position
/// the suggestions were requested for, so a caret that has since moved
/// elsewhere never decides where the tag goes. Returns null when the anchored
/// text has changed and the suggestion no longer applies. A multi-word tag
/// that starts with the words typed before the anchored one ("long ha" ->
/// "long hair") replaces the longest such run instead of repeating it. The run
/// never crosses a separator (",", "，", "、", a line break) or weight and
/// bracket syntax such as "{{", "(" or "1.2::", which stays in front of the
/// tag.
({String value, int caret})? applyAutocompleteTag(
  String value,
  AutocompleteAnchor anchor,
  String tag,
) {
  if (tag.isEmpty ||
      anchor.start < 0 ||
      anchor.start > anchor.cursor ||
      anchor.cursor > value.length ||
      value.substring(anchor.start, anchor.cursor) != anchor.word) {
    return null;
  }
  var end = anchor.cursor;
  while (end < value.length && _wordTailChar.hasMatch(value[end])) {
    end++;
  }
  final target = _tagKey(tag);
  var start = anchor.start;
  // Walk back one whole space-separated word at a time; any other character
  // ends the walk.
  var wordEnd = anchor.start;
  while (true) {
    var gap = wordEnd;
    while (gap > 0 && _wordGap.hasMatch(value[gap - 1])) {
      gap--;
    }
    var wordStart = gap;
    while (wordStart > 0 && _wordChar.hasMatch(value[wordStart - 1])) {
      wordStart--;
    }
    if (gap == wordEnd || wordStart == gap) break;
    final phrase = _tagKey(value.substring(wordStart, anchor.cursor));
    if (phrase.length > target.length) break;
    if (target.startsWith(phrase)) start = wordStart;
    wordEnd = wordStart;
  }
  // Line breaks after the caret stay.
  final after = value.substring(end).replaceFirst(_separatorAfter, '');
  return (
    value: '${value.substring(0, start)}$tag, $after',
    caret: start + tag.length + 2
  );
}
