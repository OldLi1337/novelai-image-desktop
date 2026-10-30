const translationLanguages = [
  (value: "zh-CN", label: "简体中文", name: "Simplified Chinese", baidu: "zh"),
  (value: "zh-TW", label: "繁體中文", name: "Traditional Chinese", baidu: "cht"),
  (value: "en", label: "English", name: "English", baidu: "en"),
  (value: "ja", label: "日本語", name: "Japanese", baidu: "jp"),
  (value: "ko", label: "한국어", name: "Korean", baidu: "kor"),
  (value: "fr", label: "Français", name: "French", baidu: "fra"),
  (value: "de", label: "Deutsch", name: "German", baidu: "de"),
  (value: "es", label: "Español", name: "Spanish", baidu: "spa"),
  (value: "ru", label: "Русский", name: "Russian", baidu: "ru"),
  (value: "pt", label: "Português", name: "Portuguese", baidu: "pt"),
  (value: "it", label: "Italiano", name: "Italian", baidu: "it"),
];
const _aliases = {
  'zh': 'zh-CN',
  'zh-cn': 'zh-CN',
  'zh-tw': 'zh-TW',
  'en-us': 'en',
  'ja-jp': 'ja',
  'ko-kr': 'ko',
  'jp': 'ja',
  'kor': 'ko',
  'cht': 'zh-TW',
  'fra': 'fr',
  'spa': 'es'
};
String normalizeTranslationPreference(Object? value) {
  if (value is! String || value.trim().isEmpty || value == 'system') {
    return 'system';
  }
  final raw = value.trim().toLowerCase();
  final code = _aliases[raw] ?? raw;
  return translationLanguages.any((l) => l.value == code) ? code : 'system';
}

/// "system" follows the software language, which is always Simplified Chinese.
String resolveTranslationTarget(Object? preference) {
  final target = normalizeTranslationPreference(preference);
  return target == 'system' ? 'zh-CN' : target;
}

String baiduTranslationTarget(String target) => translationLanguages
    .firstWhere((l) => l.value == resolveTranslationTarget(target))
    .baidu;
const _previewRow = [
  "翻译预览",
  "目标语言",
  "跟随软件语言",
  "原文",
  "译文",
  "翻译",
  "重新翻译",
  "正在翻译…",
  "应用译文",
  "复制译文",
  "取消",
  "翻译失败，请重试。",
  "原文已变化，请重新翻译后应用。",
  "已复制译文",
  "复制失败，请重试。",
  "预览不会修改原文；仅点击应用后替换。"
];
Map<String, String> translationText(Object? language) {
  const keys = [
    'title',
    'target',
    'system',
    'source',
    'result',
    'run',
    'retry',
    'busy',
    'apply',
    'copy',
    'cancel',
    'failed',
    'stale',
    'copied',
    'copyFailed',
    'hint'
  ];
  return {for (var i = 0; i < keys.length; i++) keys[i]: _previewRow[i]};
}

String normalizeTranslationSource(Object? value) {
  final code = normalizeTranslationPreference(value);
  return code == 'system' ? 'auto' : code;
}

Map<String, String> translationEditorText(Object? language) {
  const row = ['源语言', '自动检测', '互换语言', '实时翻译', '输入停止后自动翻译', '请先选择源语言或完成自动检测'];
  const keys = [
    'sourceLanguage',
    'auto',
    'swap',
    'live',
    'liveHint',
    'selectSource'
  ];
  return {for (var i = 0; i < keys.length; i++) keys[i]: row[i]};
}
