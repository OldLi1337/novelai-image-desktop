import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/nai_models.dart';
import '../prompts/prompt_append.dart';
import '../prompts/prompt_library_tags.dart';
import '../state/app_state.dart';
import '../ui/prompt_tag_controls.dart';

// Custom prompt chunks (自定义提词), as on the desktop app: saved phrases that
// are inserted into the current prompt. They never replace the prompt or use
// the positive presets.

typedef PromptChunkText = ({
  String trigger,
  String title,
  String subtitle,
  String search,
  String create,
  String name,
  String namePlaceholder,
  String content,
  String contentPlaceholder,
  String save,
  String cancel,
  String close,
  String edit,
  String remove,
  String removeConfirm,
  String empty,
  String insert,
  String inserted,
  String nameRequired,
  String contentRequired,
});

const PromptChunkText promptChunkText = (
  trigger: '自定义提词',
  title: '自定义提词块',
  subtitle: '保存常用词组并随时插入当前提示词；它不会替换或调用正面预设。',
  search: '搜索提词名称或内容',
  create: '新建提词',
  name: '名称',
  namePlaceholder: '例如：角色服装',
  content: '提词内容',
  contentPlaceholder: '例如：white dress, blue ribbon',
  save: '确认保存',
  cancel: '取消',
  close: '关闭',
  edit: '编辑',
  remove: '删除',
  removeConfirm: '删除这个自定义提词？',
  empty: '还没有自定义提词。',
  insert: '插入',
  inserted: '已插入自定义提词。',
  nameRequired: '请填写名称。',
  contentRequired: '请填写提词内容。',
);

/// Opens the custom prompt chunk library for a prompt field. [tagFilter] is
/// the filter selected the last time this field's library was open;
/// [onTagFilterChanged] reports changes so the next opening keeps it.
Future<void> showPromptChunkSheet(
  BuildContext context, {
  required String value,
  required ValueChanged<String> onApply,
  String tagFilter = '',
  ValueChanged<String>? onTagFilterChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: .9,
      child: _PromptChunkSheet(
        value: value,
        onApply: onApply,
        tagFilter: tagFilter,
        onTagFilterChanged: onTagFilterChanged,
      ),
    ),
  );
}

/// Compact button that opens the custom prompt chunk library.
class PromptChunkButton extends StatefulWidget {
  final String value;
  final ValueChanged<String> onApply;

  const PromptChunkButton({
    super.key,
    required this.value,
    required this.onApply,
  });

  @override
  State<PromptChunkButton> createState() => _PromptChunkButtonState();
}

class _PromptChunkButtonState extends State<PromptChunkButton> {
  // Kept while the button lives, like the desktop library's selected tag.
  String _tagFilter = '';

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showPromptChunkSheet(
        context,
        value: widget.value,
        onApply: widget.onApply,
        tagFilter: _tagFilter,
        onTagFilterChanged: (value) => _tagFilter = value,
      ),
      icon: const Icon(Icons.playlist_add, size: 18),
      label: Text(promptChunkText.trigger),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _PromptChunkSheet extends StatefulWidget {
  final String value;
  final ValueChanged<String> onApply;
  final String tagFilter;
  final ValueChanged<String>? onTagFilterChanged;

  const _PromptChunkSheet({
    required this.value,
    required this.onApply,
    required this.tagFilter,
    this.onTagFilterChanged,
  });

  @override
  State<_PromptChunkSheet> createState() => _PromptChunkSheetState();
}

class _PromptChunkSheetState extends State<_PromptChunkSheet> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _content = TextEditingController();
  final _tags = TextEditingController();
  late String _tagFilter = widget.tagFilter;
  String? _editingId;
  bool _nameError = false;
  bool _contentError = false;
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _setTagFilter(String value) {
    _tagFilter = value;
    widget.onTagFilterChanged?.call(value);
  }

  void _beginCreate() {
    // A new chunk starts with the selected tag. build() has already reset a
    // filter whose tag is gone, so a removed tag is never pre-filled.
    setState(() {
      _editingId = '';
      _name.clear();
      _content.clear();
      _tags.text = _tagFilter.isNotEmpty && _tagFilter != untaggedPromptFilter
          ? _tagFilter
          : '';
      _nameError = false;
      _contentError = false;
    });
  }

  void _beginEdit(PromptChunk chunk) {
    setState(() {
      _editingId = chunk.id;
      _name.text = chunk.name;
      _content.text = chunk.content;
      _tags.text = formatPromptTagInput(chunk.tags);
      _nameError = false;
      _contentError = false;
    });
  }

  Future<void> _save(AppState state) async {
    final name = _name.text.trim();
    final content = _content.text.trim();
    setState(() {
      _nameError = name.isEmpty;
      _contentError = content.isEmpty;
    });
    if (name.isEmpty || content.isEmpty) return;
    setState(() => _saving = true);
    try {
      await state.savePromptChunk(
        id: (_editingId ?? '').isEmpty ? null : _editingId,
        name: name,
        content: content,
        tags: normalizePromptTags(_tags.text),
      );
      if (!mounted) return;
      setState(() {
        _search.clear();
        _editingId = null;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(AppState state, PromptChunk chunk) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(promptChunkText.remove),
        content: Text(promptChunkText.removeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(promptChunkText.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(promptChunkText.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await state.removePromptChunk(chunk.id);
    if (mounted && _editingId == chunk.id) setState(() => _editingId = null);
  }

  void _insert(PromptChunk chunk) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    widget.onApply(appendPromptChunk(widget.value, chunk.content));
    Navigator.pop(context);
    messenger?.showSnackBar(SnackBar(content: Text(promptChunkText.inserted)));
  }

  Widget _editor(AppState state, List<String> tagSuggestions) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('prompt-chunk-name'),
              controller: _name,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: promptChunkText.name,
                hintText: promptChunkText.namePlaceholder,
                errorText: _nameError ? promptChunkText.nameRequired : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_nameError) setState(() => _nameError = false);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('prompt-chunk-content'),
              controller: _content,
              enabled: !_saving,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: promptChunkText.content,
                hintText: promptChunkText.contentPlaceholder,
                errorText:
                    _contentError ? promptChunkText.contentRequired : null,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_contentError) setState(() => _contentError = false);
              },
            ),
            const SizedBox(height: 10),
            PromptTagInput(
              controller: _tags,
              suggestions: tagSuggestions,
              enabled: !_saving,
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed:
                      _saving ? null : () => setState(() => _editingId = null),
                  child: Text(promptChunkText.cancel),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(state),
                  icon: const Icon(Icons.check),
                  label: Text(promptChunkText.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AppState state, PromptChunk chunk) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('prompt-chunk-item-${chunk.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _insert(chunk),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chunk.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          promptChunkText.insert,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chunk.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (chunk.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      PromptTagList(chunk.tags, singleLine: true),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: promptChunkText.edit,
                onPressed: _saving ? null : () => _beginEdit(chunk),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: promptChunkText.remove,
                onPressed: _saving ? null : () => _remove(state, chunk),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final chunks = state.settings.promptChunks;
    final tagLists = [for (final chunk in chunks) chunk.tags];
    // A selected tag whose last chunk was deleted or untagged resets the
    // filter, so a hidden filter never makes the library look empty.
    if (isStalePromptTagFilter(tagLists, _tagFilter)) _setTagFilter('');
    final tagSuggestions = [
      for (final item in collectPromptTags(tagLists)) item.tag
    ];
    final filtered = chunks
        .where((chunk) => matchesPromptLibraryEntry(
            chunk.tags, [chunk.name, chunk.content], _search.text, _tagFilter))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.playlist_add),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(promptChunkText.title,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(promptChunkText.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: promptChunkText.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: tagSuggestions.isNotEmpty
                        ? promptTagText.searchHint
                        : promptChunkText.search,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                key: const ValueKey('prompt-chunk-create'),
                onPressed: _saving ? null : _beginCreate,
                icon: const Icon(Icons.add),
                label: Text(promptChunkText.create),
              ),
            ],
          ),
        ),
        PromptTagFilter(
          entries: tagLists,
          value: _tagFilter,
          onChanged: (value) => setState(() => _setTagFilter(value)),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
            children: [
              if (_editingId != null) ...[
                _editor(state, tagSuggestions),
                const SizedBox(height: 10),
              ],
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(promptChunkText.empty,
                      textAlign: TextAlign.center),
                ),
              for (final chunk in filtered) _tile(state, chunk),
            ],
          ),
        ),
      ],
    );
  }
}
