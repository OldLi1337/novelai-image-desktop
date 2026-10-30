import '../images/coordinated_file_image.dart';
import '../ui/zoomable_image.dart';
import 'dart:convert';
import 'character_preset_bar.dart' show characterPresetLabels;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../i18n/app_locales.dart';
import '../models/nai_models.dart';
import '../prompts/positive_prompt_presets.dart';
import '../prompts/prompt_library_tags.dart';
import '../state/app_state.dart';
import '../ui/prompt_library_bar.dart';
import '../ui/prompt_tag_controls.dart';
import 'prompt_chunk_sheet.dart';

typedef _PresetText = ({
  String trigger,
  String title,
  String subtitle,
  String saveCurrent,
  String create,
  String search,
  String empty,
  String name,
  String nameHint,
  String prompt,
  String promptHint,
  String images,
  String imageHint,
  String addImages,
  String edit,
  String delete,
  String save,
  String cancel,
  String apply,
  String append,
  String appendCharacters,
  String duplicate,
  String required,
  String confirmDelete,
  String applyNotice,
  String appendNotice,
  String appendCharactersNotice,
  String applyCharactersNotice,
});

_PresetText _textFor(String language) {
  return (
    trigger: '正面预设',
    title: '正面提示词预设',
    subtitle: '选择预设后可替换或追加到当前正面提示词；参考图只用于查看，不会参与生图。',
    saveCurrent: '保存当前',
    create: '手动新建',
    search: '搜索名称或提示词',
    empty: '还没有正面提示词预设',
    name: '预设名称',
    nameHint: '留空时以提示词开头命名',
    prompt: '正面提示词',
    promptHint: '只保存正面提示词内容',
    images: '参考查看图',
    imageHint: '最多 3 张；只用于辨认和对照，不会加入生成参数。',
    addImages: '添加图片',
    edit: '编辑',
    delete: '删除',
    save: '保存',
    cancel: '取消',
    apply: '替换当前正面提示词',
    append: '追加到当前提示词',
    appendCharacters: '追加这些角色',
    duplicate: '相同预设已存在，未重复保存。',
    required: '请填写正面提示词。',
    confirmDelete: '删除这个预设及其参考图？',
    applyNotice: '已替换当前正面提示词。',
    appendNotice: '已追加到当前正面提示词末尾。',
    appendCharactersNotice: '已在现有角色后追加预设角色。',
    applyCharactersNotice: '已应用预设角色。',
  );
}

class PositivePromptPresetButton extends StatefulWidget {
  final String currentPrompt;
  final ValueChanged<String> onApply;
  // The character row this button belongs to: 保存当前 saves it as a
  // character preset, and appending one saved character extends the row.
  final CharCaptionItem? character;
  final ValueChanged<List<CharCaptionItem>>? onApplyCharacters;
  final bool compact;

  const PositivePromptPresetButton({
    super.key,
    required this.currentPrompt,
    required this.onApply,
    this.character,
    this.onApplyCharacters,
    this.compact = false,
  });

  @override
  State<PositivePromptPresetButton> createState() =>
      _PositivePromptPresetButtonState();
}

class _PositivePromptPresetButtonState
    extends State<PositivePromptPresetButton> {
  // Kept while the button lives, like the desktop library's selected tag.
  String _tagFilter = '';

  @override
  Widget build(BuildContext context) {
    final text = _textFor(context.watch<AppState>().settings.language);
    return OutlinedButton.icon(
      onPressed: () => showPositivePromptPresetSheet(
        context,
        currentPrompt: widget.currentPrompt,
        onApply: widget.onApply,
        character: widget.character,
        onApplyCharacters: widget.onApplyCharacters,
        tagFilter: _tagFilter,
        onTagFilterChanged: (value) => _tagFilter = value,
      ),
      icon: const Icon(Icons.bookmarks_outlined, size: 18),
      label: Text(text.trigger),
      style: widget.compact
          ? OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }
}

/// The positive prompt's library actions, always visible under the field as
/// on the desktop app: 正面预设, 保存当前 (straight into a new preset made
/// from the prompt) and 自定义提词. [characterModel] is the model whose
/// character limit applies to character presets (the inpaint model on the
/// inpaint screen); null means the generation model.
class PositivePromptLibraryBar extends StatefulWidget {
  final String value;
  final ValueChanged<String> onApply;
  final String? characterModel;

  const PositivePromptLibraryBar({
    super.key,
    required this.value,
    required this.onApply,
    this.characterModel,
  });

  @override
  State<PositivePromptLibraryBar> createState() =>
      _PositivePromptLibraryBarState();
}

class _PositivePromptLibraryBarState extends State<PositivePromptLibraryBar> {
  // Each library keeps its selected tag while the bar lives.
  String _presetTagFilter = '';
  String _chunkTagFilter = '';

  void _openPresets({bool createFromCurrent = false}) {
    showPositivePromptPresetSheet(
      context,
      currentPrompt: widget.value,
      onApply: widget.onApply,
      characterModel: widget.characterModel,
      createFromCurrent: createFromCurrent,
      tagFilter: _presetTagFilter,
      onTagFilterChanged: (value) => _presetTagFilter = value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = _textFor(context.watch<AppState>().settings.language);
    return PromptLibraryBar(
      semanticLabel: text.prompt,
      actions: [
        (
          key: const ValueKey('positive-library-presets'),
          icon: Icons.bookmarks_outlined,
          label: text.trigger,
          onPressed: _openPresets,
        ),
        (
          key: const ValueKey('positive-library-save-current'),
          icon: Icons.push_pin_outlined,
          label: text.saveCurrent,
          onPressed: widget.value.trim().isEmpty
              ? null
              : () => _openPresets(createFromCurrent: true),
        ),
        (
          key: const ValueKey('positive-library-chunks'),
          icon: Icons.playlist_add,
          label: promptChunkText.trigger,
          onPressed: () => showPromptChunkSheet(
                context,
                value: widget.value,
                onApply: widget.onApply,
                tagFilter: _chunkTagFilter,
                onTagFilterChanged: (value) => _chunkTagFilter = value,
              ),
        ),
      ],
    );
  }
}

/// Opens the positive preset library. With [createFromCurrent] it opens
/// straight into a new preset made from [currentPrompt]. [tagFilter] is the
/// filter selected the last time this library was open; [onTagFilterChanged]
/// reports changes so the next opening keeps it.
Future<void> showPositivePromptPresetSheet(
  BuildContext context, {
  required String currentPrompt,
  required ValueChanged<String> onApply,
  CharCaptionItem? character,
  ValueChanged<List<CharCaptionItem>>? onApplyCharacters,
  String? characterModel,
  bool createFromCurrent = false,
  String tagFilter = '',
  ValueChanged<String>? onTagFilterChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: .94,
      child: _PositivePromptPresetSheet(
        currentPrompt: currentPrompt,
        onApply: onApply,
        character: character,
        onApplyCharacters: onApplyCharacters,
        characterModel: characterModel,
        createFromCurrent: createFromCurrent,
        tagFilter: tagFilter,
        onTagFilterChanged: onTagFilterChanged,
      ),
    ),
  );
}

class _PositivePromptPresetSheet extends StatefulWidget {
  final String currentPrompt;
  final ValueChanged<String> onApply;
  final CharCaptionItem? character;
  final ValueChanged<List<CharCaptionItem>>? onApplyCharacters;
  final String? characterModel;
  final bool createFromCurrent;
  final String tagFilter;
  final ValueChanged<String>? onTagFilterChanged;

  const _PositivePromptPresetSheet({
    required this.currentPrompt,
    required this.onApply,
    this.character,
    this.onApplyCharacters,
    this.characterModel,
    this.createFromCurrent = false,
    this.tagFilter = '',
    this.onTagFilterChanged,
  });

  @override
  State<_PositivePromptPresetSheet> createState() =>
      _PositivePromptPresetSheetState();
}

class _PositivePromptPresetSheetState
    extends State<_PositivePromptPresetSheet> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _prompt = TextEditingController();
  final _tags = TextEditingController();
  String? _editingId;
  String _selectedId = '';
  String _activeImageId = '';
  String _message = '';
  bool _busy = false;
  late String _tagFilter = widget.tagFilter;
  List<CharCaptionItem> _draftCaptions = [];
  String get _draftText => _draftCaptions.isEmpty
      ? _prompt.text
      : _draftCaptions.map((c) => c.prompt).join('\n');

  @override
  void initState() {
    super.initState();
    if (widget.createFromCurrent) {
      _beginCreate(context.read<AppState>().settings.positivePromptPresets, true);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _prompt.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _setTagFilter(String value) {
    _tagFilter = value;
    widget.onTagFilterChanged?.call(value);
  }

  void _beginCreate(List<PositivePromptPreset> presets, bool current) {
    // 保存当前 on the library bar opens the editor directly, with the filter
    // remembered from an earlier opening: a tag removed since then is dropped,
    // not pre-filled.
    if (isStalePromptTagFilter(
        [for (final preset in presets) preset.tags], _tagFilter)) {
      _setTagFilter('');
    }
    final character = widget.character;
    _editingId = '';
    _draftCaptions = current && character != null
        ? [
            CharCaptionItem.fromJson(
                {...character.toJson(), 'prompt': widget.currentPrompt})
          ]
        : [];
    _prompt.text = current ? widget.currentPrompt : '';
    _name.text = current && widget.currentPrompt.trim().isNotEmpty
        ? defaultPositivePromptPresetName(
            widget.currentPrompt, presets.length + 1)
        : '';
    _tags.text = _tagFilter.isNotEmpty && _tagFilter != untaggedPromptFilter
        ? _tagFilter
        : '';
    _message = '';
  }

  void _startCreate(List<PositivePromptPreset> presets, bool current) {
    setState(() => _beginCreate(presets, current));
  }

  void _startEdit(PositivePromptPreset preset) {
    setState(() {
      _editingId = preset.id;
      _draftCaptions = preset.captions
          .map((c) => CharCaptionItem.fromJson(c.toJson()))
          .toList();
      _selectedId = preset.id;
      _name.text = preset.name;
      _prompt.text = preset.prompt;
      _tags.text = formatPromptTagInput(preset.tags);
      _message = '';
    });
  }

  Future<void> _save(AppState state, _PresetText text) async {
    if (_draftText.trim().isEmpty && _draftCaptions.isEmpty) {
      setState(() => _message = text.required);
      return;
    }
    final requested = _name.text.trim().isEmpty
        ? defaultPositivePromptPresetName(
            _draftText, state.settings.positivePromptPresets.length + 1)
        : _name.text.trim();
    final duplicate = state.settings.positivePromptPresets
        .where((preset) =>
            preset.id != _editingId &&
            preset.name.trim() == requested &&
            preset.prompt == _draftText &&
            jsonEncode(preset.captions.map((c) => c.toJson()).toList()) ==
                jsonEncode(_draftCaptions.map((c) => c.toJson()).toList()))
        .firstOrNull;
    if (duplicate != null) {
      setState(() {
        _selectedId = duplicate.id;
        _editingId = null;
        _message = text.duplicate;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await state.savePositivePromptPreset(
        id: (_editingId ?? '').isEmpty ? null : _editingId,
        name: requested,
        prompt: _draftText,
        captions: _draftCaptions,
        tags: normalizePromptTags(_tags.text),
      );
      if (!mounted) return;
      setState(() {
        _selectedId = saved.id;
        _editingId = null;
        _message = '';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(
    AppState state,
    PositivePromptPreset preset,
    _PresetText text,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.delete),
        content: Text(text.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(text.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await state.removePositivePromptPreset(preset.id);
    if (!mounted) return;
    setState(() {
      _selectedId = state.settings.positivePromptPresets.firstOrNull?.id ?? '';
      _editingId = null;
      _busy = false;
    });
  }

  Future<void> _importImages(
    AppState state,
    PositivePromptPreset preset,
  ) async {
    final available =
        positivePromptPresetImageLimit - preset.previewImages.length;
    if (available <= 0) return;
    final picked = await ImagePicker().pickMultiImage(imageQuality: 100);
    if (picked.isEmpty) return;
    setState(() => _busy = true);
    final imported = await state.importPositivePromptPresetImages(
      preset: preset,
      sources: picked
          .take(available)
          .map((item) => (path: item.path, name: item.name))
          .toList(),
    );
    if (!mounted) return;
    setState(() {
      if (imported.isNotEmpty) _activeImageId = imported.first.id;
      _busy = false;
    });
  }

  void _showImage(PositivePromptPreset preset, StylePromptPreviewImage image) {
    showGalleryImagePreview(context, images: [
      imageFile(File(image.filePath),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image_outlined, color: Colors.white70))
    ], captions: [
      '${preset.name} · ${image.name}'
    ]);
  }

  Widget _presetList(
    List<PositivePromptPreset> presets,
    PositivePromptPreset? selected,
    bool horizontal,
  ) {
    if (presets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Icon(Icons.bookmarks_outlined, size: 34),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
      padding: const EdgeInsets.all(10),
      itemCount: presets.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8, height: 8),
      itemBuilder: (context, index) {
        final preset = presets[index];
        final active = preset.id == selected?.id;
        final first = preset.previewImages.firstOrNull;
        return SizedBox(
          key: ValueKey('positive-preset-item-${preset.id}'),
          width: horizontal ? 250 : null,
          child: Card(
            clipBehavior: Clip.antiAlias,
            color:
                active ? Theme.of(context).colorScheme.primaryContainer : null,
            child: InkWell(
              onTap: () => setState(() {
                _selectedId = preset.id;
                _activeImageId = preset.previewImages.firstOrNull?.id ?? '';
                _message = '';
              }),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      child: first == null
                          ? const Icon(Icons.bookmark_outline)
                          : imageFile(
                              File(first.filePath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preset.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          // Flexible: the phone layout's cards have a fixed
                          // height, so large text is cut off, not overflowed.
                          Flexible(
                            child: Text(
                              preset.prompt,
                              maxLines: preset.tags.isEmpty ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          if (preset.tags.isNotEmpty)
                            Flexible(
                              child:
                                  PromptTagList(preset.tags, singleLine: true),
                            ),
                        ],
                      ),
                    ),
                    Text('${preset.previewImages.length}/3'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _images(
    AppState state,
    PositivePromptPreset preset,
    _PresetText text,
  ) {
    final images = preset.previewImages;
    final active =
        images.where((item) => item.id == _activeImageId).firstOrNull ??
            images.firstOrNull;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text.images,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(text.imageHint,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || images.length >= 3
                      ? null
                      : () => _importImages(state, preset),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text('${text.addImages} ${images.length}/3'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: active == null
                    ? InkWell(
                        onTap: () => _importImages(state, preset),
                        child: const Center(
                            child: Icon(Icons.image_outlined, size: 42)),
                      )
                    : InkWell(
                        onTap: () => _showImage(preset, active),
                        child: imageFile(
                          File(active.filePath),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 42),
                          ),
                        ),
                      ),
              ),
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final image = images[index];
                    return Stack(
                      children: [
                        InkWell(
                          onTap: () =>
                              setState(() => _activeImageId = image.id),
                          onLongPress: () => _showImage(preset, image),
                          child: Container(
                            width: 94,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: image.id == active?.id
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                width: image.id == active?.id ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: imageFile(File(image.filePath),
                                fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            tooltip: text.delete,
                            onPressed: _busy
                                ? null
                                : () async {
                                    await state.removePositivePromptPresetImage(
                                      preset: preset,
                                      image: image,
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _activeImageId = preset.previewImages
                                                .firstOrNull?.id ??
                                            '';
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline, size: 17),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _apply(
    AppState state,
    PositivePromptPreset preset,
    PositivePresetApplyMode mode,
    _PresetText text,
  ) {
    final model = widget.characterModel ?? state.params.model;
    final application = resolvePositivePresetApplication(
      preset,
      mode,
      value: widget.currentPrompt,
      character: widget.character,
      currentCaptions: state.extras.charCaptions,
      maxCharacters: (state.params.copy()..model = model).maxCharacterPrompts,
    );
    final String notice;
    switch (application) {
      case PositivePresetOverCapacity():
        setState(() =>
            _message = characterPresetLabels(state.settings.language)[9]);
        return;
      case PositivePresetPrompt(:final prompt, :final appended):
        widget.onApply(prompt);
        notice = appended ? text.appendNotice : text.applyNotice;
      case PositivePresetCharacters(:final captions, :final appended, :final row):
        if (widget.onApplyCharacters != null) {
          widget.onApplyCharacters!(captions);
        } else if (row) {
          widget.onApply(captions.single.prompt);
        } else {
          state.extras.charCaptions = captions;
          state.markCharacterChanged();
        }
        notice = row
            ? text.appendNotice
            : appended
                ? text.appendCharactersNotice
                : text.applyCharactersNotice;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    messenger?.showSnackBar(SnackBar(content: Text(notice)));
  }

  Widget _detail(
    AppState state,
    PositivePromptPreset? selected,
    _PresetText text,
  ) {
    if (selected == null) {
      return Center(child: Text(text.empty));
    }
    // One saved character appended inside a character row extends that row.
    final appendsToRow =
        widget.character != null && selected.captions.length == 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(selected.name,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              tooltip: text.edit,
              onPressed: () => _startEdit(selected),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: text.delete,
              onPressed: _busy ? null : () => _delete(state, selected, text),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        if (selected.tags.isNotEmpty) ...[
          PromptTagList(selected.tags),
          const SizedBox(height: 8),
        ],
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(selected.prompt),
          ),
        ),
        const SizedBox(height: 10),
        _images(state, selected, text),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('positive-preset-replace'),
          onPressed: () =>
              _apply(state, selected, PositivePresetApplyMode.replace, text),
          icon: const Icon(Icons.swap_horiz),
          label: Text(selected.captions.isNotEmpty
              ? "${characterPresetLabels(state.settings.language)[2]} · ${selected.captions.length}"
              : text.apply),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('positive-preset-append'),
          onPressed: () =>
              _apply(state, selected, PositivePresetApplyMode.append, text),
          icon: const Icon(Icons.playlist_add),
          label: Text(selected.captions.isNotEmpty && !appendsToRow
              ? text.appendCharacters
              : text.append),
        ),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_message, textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Widget _editor(
    AppState state,
    PositivePromptPreset? selected,
    _PresetText text,
    List<String> tagSuggestions,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: text.name,
            hintText: text.nameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (_draftCaptions.isNotEmpty)
          for (var i = 0; i < _draftCaptions.length; i++) ...[
            Text(mobileUiFormatFor(state.settings.language,
                'generate.characterLabel', {'index': i + 1})),
            TextFormField(
                key: ValueKey('preset-role-positive-$i'),
                initialValue: _draftCaptions[i].prompt,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(labelText: text.prompt),
                onChanged: (v) => setState(() => _draftCaptions[i].prompt = v)),
            TextFormField(
                key: ValueKey('preset-role-negative-$i'),
                initialValue: _draftCaptions[i].negativePrompt,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: mobileUiTextFor(
                        state.settings.language, 'generate.characterNegative')),
                onChanged: (v) =>
                    setState(() => _draftCaptions[i].negativePrompt = v)),
            const SizedBox(height: 12),
          ]
        else
          TextField(
            controller: _prompt,
            minLines: 7,
            maxLines: 15,
            decoration: InputDecoration(
              labelText: text.prompt,
              hintText: text.promptHint,
              border: const OutlineInputBorder(),
            ),
          ),
        const SizedBox(height: 12),
        PromptTagInput(
          controller: _tags,
          suggestions: tagSuggestions,
          enabled: !_busy,
        ),
        const SizedBox(height: 12),
        if ((_editingId ?? '').isNotEmpty && selected != null)
          _images(state, selected, text)
        else
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, size: 34),
                  const SizedBox(height: 8),
                  Text(text.imageHint, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_message, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _busy ? null : () => setState(() => _editingId = null),
              child: Text(text.cancel),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _busy ? null : () => _save(state, text),
              icon: const Icon(Icons.check),
              label: Text(text.save),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = _textFor(state.settings.language);
    final all = state.settings.positivePromptPresets;
    final tagLists = [for (final preset in all) preset.tags];
    // A selected tag whose last preset was deleted or untagged resets the
    // filter, so a hidden filter never makes the library look empty.
    if (isStalePromptTagFilter(tagLists, _tagFilter)) _setTagFilter('');
    final tagSuggestions = [
      for (final item in collectPromptTags(tagLists)) item.tag
    ];
    final presets = all
        .where((preset) => matchesPromptLibraryEntry(
              preset.tags,
              [
                preset.name,
                preset.prompt,
                for (final caption in preset.captions) caption.prompt,
              ],
              _search.text,
              _tagFilter,
            ))
        .toList();
    if (_editingId == null &&
        !presets.any((preset) => preset.id == _selectedId)) {
      _selectedId = presets.firstOrNull?.id ?? '';
    }
    final selected =
        all.where((preset) => preset.id == _selectedId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.bookmarks_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text.title,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                        selected?.captions.isNotEmpty == true
                            ? "${mobileUiTextFor(state.settings.language, 'generate.characterPrompts')} · ${selected!.captions.length}"
                            : text.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        if (_editingId == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: tagSuggestions.isNotEmpty
                        ? promptTagText.searchHint
                        : text.search,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _startCreate(
                            state.settings.positivePromptPresets, false),
                        icon: const Icon(Icons.add),
                        label: Text(text.create),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.currentPrompt.trim().isEmpty
                            ? null
                            : () => _startCreate(
                                state.settings.positivePromptPresets, true),
                        icon: const Icon(Icons.push_pin_outlined),
                        label: Text(text.saveCurrent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (_editingId == null)
          PromptTagFilter(
            entries: tagLists,
            value: _tagFilter,
            onChanged: (value) => setState(() => _setTagFilter(value)),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          ),
        const Divider(height: 1),
        Expanded(
          child: _editingId != null
              ? _editor(state, selected, text, tagSuggestions)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 760) {
                      return Row(
                        children: [
                          SizedBox(
                            width: 310,
                            child: _presetList(presets, selected, false),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: _detail(state, selected, text)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        SizedBox(
                          height: 104,
                          child: _presetList(presets, selected, true),
                        ),
                        const Divider(height: 1),
                        Expanded(child: _detail(state, selected, text)),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
