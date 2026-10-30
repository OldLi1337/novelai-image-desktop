import 'artist_recipe.dart';

List<ArtistTagRecord> parseCustomArtistPool(String raw) {
  final names = <String>{};
  for (final token in raw.split(RegExp(r'[,，\r\n]+'))) {
    final name = token
        .trim()
        .replaceAll(RegExp(r'^[{\[\s]+|[}\]\s]+$'), '')
        .replaceFirst(RegExp(r'^artist\s*:\s*', caseSensitive: false), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    if (name.isNotEmpty &&
        name.length <= 200 &&
        !RegExp(r'[{}\[\]<>:]').hasMatch(name)) names.add(name);
  }
  return names
      .toList()
      .asMap()
      .entries
      .map((e) => ArtistTagRecord(-(e.key + 1), e.value, 0))
      .toList();
}

const _labels = <String, List<String>>{
  "zh-CN": ["使用自定义画师候选库", "画师列表（逗号或换行分隔）", "仅从这里抽取，不混入排行榜；权重由抽卡参数统一设置。"],
};
List<String> customArtistPoolText(String language) =>
    _labels[language] ?? _labels['zh-CN']!;
