import 'package:flutter/material.dart';

const _effortTitles = <String, String>{
  'zh-CN': '生成档位（Effort）',
};
String effortTitle(Object? language) => _effortTitles[language] ?? _effortTitles['zh-CN']!;

String effortRemainingTitle(Object? language) => '预计可生成张数';

class EffortControl extends StatelessWidget {
  final String model, value;
  final Object? language;
  final ValueChanged<String> onChanged;
  const EffortControl({super.key, required this.model, required this.value, required this.language, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    if (model.replaceFirst(RegExp(r'-inpainting$'), '') != 'nai-diffusion-5-full') return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(effortTitle(language)),
      const SizedBox(height: 6),
      SegmentedButton<String>(segments: const [ButtonSegment(value:'medium',label:Text('Medium')), ButtonSegment(value:'high',label:Text('High'))], selected:{value}, onSelectionChanged:(values)=>onChanged(values.single)),
    ]));
  }
}
