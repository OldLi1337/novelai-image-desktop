import 'prompt_skill_selector.dart';
import '../prompts/prompt_skill_selection.dart';
import 'dart:convert';
import '../ui/studio_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

Map<String, String> promptAssistantLabels(Object? language) => const {
      'optimize': '优化提示词',
      'custom': '提示词助手',
      'instruction': '修改要求',
      'source': '当前提示词',
      'template': '使用模板模式',
      'preview': '预览结果',
      'run': '执行',
      'retry': '重试',
      'apply': '应用',
      'cancel': '取消',
      'busy': '正在处理…',
      'stale': '原提示词已变化，请重新执行。'
    };

class PromptAssistantDialog extends StatefulWidget {
  final String kind;
  final String source;
  final bool Function(String) isCurrent;

  const PromptAssistantDialog({
    super.key,
    required this.kind,
    required this.source,
    required this.isCurrent,
  });

  @override
  State<PromptAssistantDialog> createState() => _PromptAssistantDialogState();
}

class _PromptAssistantDialogState extends State<PromptAssistantDialog> {
  final instruction = TextEditingController();
  String result = '', error = '';
  bool busy = false;
  String? resultContext;
  String signature(){final s=context.read<AppState>().settings;return jsonEncode([widget.kind,widget.source,instruction.text,s.promptAssistantMode,s.promptAssistantTemplateVersion,s.promptAssistantSkillVersion,s.convertPromptTemplates,s.convertPromptTemplatesV45,s.convertPromptTemplatesV2,s.promptOptimizeTemplate,s.promptAssistantTemplate,s.promptOptimizeTemplateV2,s.promptAssistantTemplateV2]);}
  List<String> modeLabels()=>const ['标签','自然语言','混合'];

  @override
  void dispose() {
    instruction.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (busy) return;
    final requestContext=signature();
    setState(() {
      busy = true;
      result = '';
      error = '';
    });
    try {
      final response = await context.read<AppState>().assistPositivePrompt(
            currentPrompt: widget.source,
            instruction: instruction.text,
            kind: widget.kind,
          );
      if (!mounted) return;
      setState(() {
        if (response.ok && response.text.trim().isNotEmpty) {
          result = response.text.trim();
          resultContext=requestContext;
        } else {
          error = response.message;
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels =
        promptAssistantLabels(context.watch<AppState>().settings.language);
    final stale = !widget.isCurrent(widget.source)||(result.isNotEmpty&&resultContext!=signature());
    return AlertDialog(
      title: Text(labels[widget.kind]!),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PromptSkillSelector(model:context.watch<AppState>().settings.promptAssistantTemplateVersion,edition:context.watch<AppState>().settings.promptAssistantSkillVersion,language:context.watch<AppState>().settings.language,onChanged:busy?null:(model,edition)async{setState((){result='';error='';resultContext=null;});await context.read<AppState>().setSettings((s)=>selectPromptSkill(s,'assistant',edition,model));}),
                const SizedBox(height:12),
                StudioDropdownButtonFormField<String>(
                    value:context.watch<AppState>().settings.promptAssistantMode,
                    decoration:InputDecoration(labelText:labels['template']),
                    items:[for(final (index,value) in ['tags','natural','mixed'].indexed)DropdownMenuItem(value:value,child:Text(modeLabels()[index]))],
                    onChanged:busy?null:(next) async{if(next==null)return;setState((){result='';error='';resultContext=null;});await context.read<AppState>().setSettings((s)=>s.promptAssistantMode=next);}),
                const SizedBox(height:12),
                Text(labels['source']!),
                SelectableText(widget.source),
                if (widget.kind == 'custom') ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: instruction,
                      maxLines: 3,
                      maxLength: 8000,
                      onChanged: (_) => setState(() {
                            result = '';
                            error = '';
                          }),
                      decoration: InputDecoration(
                          labelText: labels['instruction'],
                          border: const OutlineInputBorder())),
                ],
                if (busy) Text(labels['busy']!),
                if (error.isNotEmpty)
                  Text(error,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (result.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(labels['preview']!),
                  SelectableText(result),
                ],
                if (stale)
                  Text(labels['stale']!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(labels['cancel']!)),
        TextButton(
            onPressed: busy ||
                    (widget.kind == 'optimize'
                        ? widget.source.trim().isEmpty
                        : instruction.text.trim().isEmpty)
                ? null
                : _run,
            child: Text(result.isEmpty ? labels['run']! : labels['retry']!)),
        FilledButton(
            onPressed: busy || result.isEmpty || stale
                ? null
                : () => Navigator.pop(context, result),
            child: Text(labels['apply']!)),
      ],
    );
  }
}
