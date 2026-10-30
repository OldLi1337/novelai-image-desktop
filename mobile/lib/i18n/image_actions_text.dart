import 'app_locales.dart';

String imageActionsText(Object? language, String key) {
  const labels = {
    'zh-CN': [
      '粘贴图片',
      '复制图片',
      '已复制图片',
      '此平台无法复制图片到剪贴板。',
      '复制时保留原始元数据',
      '默认关闭。开启后复制原始文件字节（含内嵌参数）；接收应用可能丢弃元数据。'
    ],
  };
  const keys = [
    'paste',
    'copy',
    'copied',
    'unsupported',
    'originalTitle',
    'originalHint'
  ];
  final index = keys.indexOf(key);
  return index < 0 ? key : labels[normalizeAppLocaleCode(language)]![index];
}
