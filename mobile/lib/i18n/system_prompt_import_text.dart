import '../tavern/tavern_preset_import.dart';

const _errors = <String, String>{
  'empty': '系统提示词为空；原配置未改。',
  'bytes': '文件超过 2 MiB；拒绝导入，未截断。',
  'utf8': '文件不是有效 UTF-8；请转换编码后重试。',
  'extension': '仅支持 TXT / MD / JSON 系统提示词。',
  'json': 'JSON 损坏；原配置未改。',
  'shape': '未找到有效 systemPrompt / system_prompt 或 ST 提示块。',
  'system-limit': '系统正文超过 200000 字符；拒绝导入，未截断。',
  'postscript-limit': '后置正文超过 100000 字符；拒绝导入，未截断。',
};
String systemPromptImportErrorText(Object error, Object? language) {
  final code = error is SystemPromptImportError ? error.code : null;
  final text = code == null ? null : _errors[code];
  return text ?? error.toString();
}
