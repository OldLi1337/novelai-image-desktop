import '../ui/character_editing.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/nai_models.dart';

const _labels = <String, List<String>>{
  "zh-CN": [
    "角色预设",
    "保存当前角色",
    "应用",
    "重命名",
    "删除",
    "名称",
    "保存",
    "取消",
    "已保存",
    "预设角色数量超过当前模型上限，请先切换模型。"
  ],
};
List<String> characterPresetLabels(String language) =>
    _labels[language] ?? _labels['zh-CN']!;
Future<String?> requestPresetName(BuildContext context, String language,
    {String initial = ''}) {
  final t = characterPresetLabels(language);
  var value = initial;
  return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                  title: Text(t[5]),
                  content: TextFormField(
                      initialValue: initial,
                      autofocus: true,
                      maxLength: 120,
                      decoration: InputDecoration(labelText: t[5]),
                      onChanged: (v) => setState(() => value = v)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t[7])),
                    FilledButton(
                        onPressed: value.trim().isEmpty
                            ? null
                            : () => Navigator.pop(context, value.trim()),
                        child: Text(t[6]))
                  ])));
}

class CharacterPresetBar extends StatefulWidget {
  const CharacterPresetBar({super.key});
  @override
  State<CharacterPresetBar> createState() => _CharacterPresetBarState();
}

class _CharacterPresetBarState extends State<CharacterPresetBar> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final language = state.settings.language;
    final t = characterPresetLabels(language),
        labels = characterEditLabels(language);
    return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('保存到正面预设'),
            onPressed: busy || state.extras.charCaptions.isEmpty
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      final snapshot = state.extras.charCaptions
                          .map((c) => CharCaptionItem.fromJson(c.toJson()))
                          .toList();
                      final target = await showDialog<int>(
                          context: context,
                          builder: (context) =>
                              SimpleDialog(title: Text(labels[5]), children: [
                                SimpleDialogOption(
                                    onPressed: () => Navigator.pop(context, -1),
                                    child: Text(labels[4])),
                                for (var i = 0; i < snapshot.length; i++)
                                  SimpleDialogOption(
                                      onPressed: () =>
                                          Navigator.pop(context, i),
                                      child: Text(
                                          '${i + 1} · ${snapshot[i].prompt}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis))
                              ]));
                      if (target == null || !context.mounted) return;
                      final name = await requestPresetName(context, language);
                      if (name == null) return;
                      final chosen =
                          target == -1 ? snapshot : [snapshot[target]];
                      await state.savePositivePromptPreset(
                          name: name,
                          prompt: chosen.map((c) => c.prompt).join('\n'),
                          captions: chosen);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(t[8])));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  }));
  }
}
