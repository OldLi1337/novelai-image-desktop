import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../prompts/prompt_library_tags.dart';
import 'studio_theme.dart';

/// Single-select tag chips for a saved-prompt library: 全部, every tag with its
/// entry count, and 未加标签. Hidden until an entry has a tag. [entries] holds
/// the tags of each saved entry. Libraries reset a selected filter whose tag
/// disappeared (isStalePromptTagFilter) before building this.
class PromptTagFilter extends StatelessWidget {
  final List<List<String>> entries;
  final String value;
  final ValueChanged<String> onChanged;
  final EdgeInsetsGeometry padding;

  const PromptTagFilter({
    super.key,
    required this.entries,
    required this.value,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final tags = collectPromptTags(entries);
    if (tags.isEmpty) return const SizedBox.shrink();
    final untagged =
        entries.where((tags) => normalizePromptTags(tags).isEmpty).length;
    final selected = value.toLowerCase();
    final countStyle = Theme.of(context).textTheme.labelSmall;
    Widget chip(String key, String label, int count) {
      final active = selected == key.toLowerCase();
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: ChoiceChip(
          selected: active,
          showCheckmark: false,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 5),
              Text('$count', style: countStyle),
            ],
          ),
          onSelected: (_) => onChanged(key.isNotEmpty && active ? '' : key),
        ),
      );
    }

    return Semantics(
      container: true,
      label: promptTagText.filter,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            chip('', promptTagText.all, entries.length),
            for (final item in tags) chip(item.tag, '#${item.tag}', item.count),
            if (untagged > 0)
              chip(untaggedPromptFilter, promptTagText.untagged, untagged),
          ],
        ),
      ),
    );
  }
}

/// Read-only tags of a saved entry: one line in list rows, wrapped chips in
/// details.
class PromptTagList extends StatelessWidget {
  final List<String> tags;
  final bool singleLine;

  const PromptTagList(this.tags, {super.key, this.singleLine = false});

  @override
  Widget build(BuildContext context) {
    final list = normalizePromptTags(tags);
    if (list.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    if (singleLine) {
      return Text(
        list.map((tag) => '#$tag').join('  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final tag in list)
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(StudioRadii.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              child: Text(
                '#$tag',
                style: style?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
          ),
      ],
    );
  }
}

/// Comma-separated tag field with one-tap suggestions from the library.
class PromptTagInput extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final bool enabled;

  const PromptTagInput({
    super.key,
    required this.controller,
    required this.suggestions,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final current = normalizePromptTags(value.text)
            .map((tag) => tag.toLowerCase())
            .toSet();
        final available = suggestions
            .where((tag) => !current.contains(tag.toLowerCase()))
            .take(16)
            .toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('prompt-tag-input'),
              controller: controller,
              enabled: enabled,
              inputFormatters: [LengthLimitingTextInputFormatter(400)],
              decoration: InputDecoration(
                labelText: promptTagText.tags,
                hintText: promptTagText.tagsPlaceholder,
                helperText: promptTagText.tagsHint,
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            if (available.isNotEmpty) ...[
              const SizedBox(height: 6),
              Semantics(
                container: true,
                label: promptTagText.addTag,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in available)
                      ActionChip(
                        label: Text('+ $tag'),
                        onPressed: enabled
                            ? () {
                                final next =
                                    addPromptTagToInput(controller.text, tag);
                                controller.value = TextEditingValue(
                                  text: next,
                                  selection: TextSelection.collapsed(
                                      offset: next.length),
                                );
                              }
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
