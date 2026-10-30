import '../models/nai_models.dart';
import 'prompt_append.dart';

const positivePromptPresetImageLimit = 3;

String positivePromptPresetStorageId(String id) =>
    'positive-prompt-${id.trim()}';

String defaultPositivePromptPresetName(String prompt, [int fallbackIndex = 1]) {
  final compact = prompt.replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(
        RegExp(r'^[,，、;；]+|[,，、;；]+$'),
        '',
      );
  if (compact.isEmpty) return '正面提示词 ${fallbackIndex < 1 ? 1 : fallbackIndex}';
  final parts = compact
      .split(RegExp(r'[,，、;；]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  var candidate = parts.isEmpty ? compact : parts.first;
  for (final part in parts.skip(1)) {
    final next = '$candidate, $part';
    if (next.length > 28) break;
    candidate = next;
  }
  if (candidate.length > 28) candidate = candidate.substring(0, 28).trimRight();
  return candidate.isEmpty
      ? '正面提示词 ${fallbackIndex < 1 ? 1 : fallbackIndex}'
      : candidate;
}

String uniquePositivePromptPresetName(
  Iterable<PositivePromptPreset> presets,
  String requested, {
  String excludeId = '',
}) {
  final base = requested.trim().isEmpty ? '正面提示词' : requested.trim();
  final names = presets
      .where((preset) => preset.id != excludeId)
      .map((preset) => preset.name.trim().toLowerCase())
      .toSet();
  var candidate = base;
  var index = 1;
  while (names.contains(candidate.toLowerCase())) {
    candidate = '$base (${index++})';
  }
  return candidate;
}

enum PositivePresetApplyMode { replace, append }

/// What applying a saved positive preset does; see
/// [resolvePositivePresetApplication].
sealed class PositivePresetApplication {
  const PositivePresetApplication();
}

/// A plain preset: the new text of the prompt it was applied to.
final class PositivePresetPrompt extends PositivePresetApplication {
  final String prompt;
  final bool appended;
  const PositivePresetPrompt(this.prompt, {required this.appended});
}

/// A character preset: the new character list, or with [row] the updated
/// character row the preset was appended into.
final class PositivePresetCharacters extends PositivePresetApplication {
  final List<CharCaptionItem> captions;
  final bool appended;
  final bool row;
  const PositivePresetCharacters(this.captions,
      {required this.appended, required this.row});
}

/// The characters would exceed what the model accepts; nothing is applied.
final class PositivePresetOverCapacity extends PositivePresetApplication {
  const PositivePresetOverCapacity();
}

CharCaptionItem _copyCaption(CharCaptionItem caption) =>
    CharCaptionItem.fromJson(caption.toJson());

/// Decides what applying a saved positive preset does, as on the desktop app.
/// Plain presets replace [value] or are appended after it; character presets
/// replace the characters or are added after [currentCaptions], within
/// [maxCharacters]; one saved character appended inside a character row
/// ([character], whose prompt is [value]) extends that row's own prompts
/// instead of adding a character. Existing characters keep their identity;
/// saved ones are copied.
PositivePresetApplication resolvePositivePresetApplication(
  PositivePromptPreset preset,
  PositivePresetApplyMode mode, {
  required String value,
  CharCaptionItem? character,
  required List<CharCaptionItem> currentCaptions,
  required int maxCharacters,
}) {
  final append = mode == PositivePresetApplyMode.append;
  final captions = preset.captions;
  if (append && character != null && captions.length == 1) {
    final saved = captions.single;
    return PositivePresetCharacters([
      CharCaptionItem.fromJson({
        ...character.toJson(),
        'prompt': appendPromptText(value, saved.prompt),
        'negativePrompt':
            appendPromptText(character.negativePrompt, saved.negativePrompt),
      })
    ], appended: true, row: true);
  }
  if (captions.isNotEmpty) {
    final next = [
      if (append) ...currentCaptions,
      ...captions.map(_copyCaption),
    ];
    if (next.length > maxCharacters) return const PositivePresetOverCapacity();
    return PositivePresetCharacters(next, appended: append, row: false);
  }
  return PositivePresetPrompt(
      append ? appendPromptText(value, preset.prompt) : preset.prompt,
      appended: append);
}
