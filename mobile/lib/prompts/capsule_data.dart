import 'dart:convert';

import 'package:flutter/services.dart';

class CapsuleTag {
  final String tag;
  final String label;

  const CapsuleTag({required this.tag, required this.label});

  factory CapsuleTag.fromJson(Map<String, dynamic> json) => CapsuleTag(
        tag: json['en']?.toString() ?? '',
        label: json['zh']?.toString() ?? '',
      );
}

class CapsuleSubgroup {
  final String name;
  final List<CapsuleTag> tags;

  const CapsuleSubgroup({required this.name, required this.tags});

  factory CapsuleSubgroup.fromJson(Map<String, dynamic> json) =>
      CapsuleSubgroup(
        name: json['name']?.toString() ?? '',
        tags: (json['tags'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => CapsuleTag.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.tag.isNotEmpty)
            .toList(growable: false),
      );
}

class CapsuleCategory {
  final String name;
  final List<CapsuleSubgroup> subgroups;

  const CapsuleCategory({required this.name, required this.subgroups});

  bool get isNegative => name == '反向提示词';

  factory CapsuleCategory.fromJson(Map<String, dynamic> json) =>
      CapsuleCategory(
        name: json['name']?.toString() ?? '',
        subgroups: (json['subgroups'] as List? ?? const [])
            .whereType<Map>()
            .map((item) =>
                CapsuleSubgroup.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.tags.isNotEmpty)
            .toList(growable: false),
      );
}

String readableTagName(String tag) {
  final text = tag.trim().replaceAll(RegExp(r'[_-]+'), ' ');
  if (text.isEmpty) return tag;
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String localizedTagLabel(
  Object? language,
  String tag, {
  String? sourceLabel,
}) {
  final normalized = readableTagName(tag).toLowerCase();
  return sourceLabel?.trim().isNotEmpty == true
      ? sourceLabel!.trim()
      : _tagGlossZh[normalized] ?? readableTagName(tag);
}

const _tagGlossZh = <String, String>{
  '1girl': '一个女孩',
  '1boy': '一个男孩',
  'solo': '单人',
  'long hair': '长发',
  'short hair': '短发',
  'twintails': '双马尾',
  'ponytail': '马尾',
  'blonde hair': '金发',
  'black hair': '黑发',
  'white hair': '白发',
  'blue hair': '蓝发',
  'red hair': '红发',
  'pink hair': '粉发',
  'blue eyes': '蓝眼',
  'red eyes': '红眼',
  'green eyes': '绿眼',
  'smile': '微笑',
  'blush': '脸红',
  'open mouth': '张嘴',
  'looking at viewer': '看向观众',
  'dress': '连衣裙',
  'school uniform': '校服',
  'gloves': '手套',
  'hair ornament': '发饰',
  'simple background': '简单背景',
  'outdoors': '户外',
  'indoors': '室内',
  'night': '夜晚',
  'starry sky': '星空',
  'cityscape': '城市景观',
  'classroom': '教室',
  'masterpiece': '杰作',
  'best quality': '最佳质量',
  'very aesthetic': '高审美',
};

Future<List<CapsuleCategory>> loadCapsuleTaxonomy() async {
  final source = await rootBundle.loadString('assets/capsule_taxonomy.json');
  final decoded = jsonDecode(source);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((item) => CapsuleCategory.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.subgroups.isNotEmpty)
      .toList(growable: false);
}

// Flattened, de-duplicated capsule tags, cached after the first load so tag
// autocomplete can search the bundled 4000+ entries without any download.
List<CapsuleTag>? _flatCapsuleCache;

Future<List<CapsuleTag>> _flatCapsuleTags() async {
  final cached = _flatCapsuleCache;
  if (cached != null) return cached;
  final categories = await loadCapsuleTaxonomy();
  final flat = <CapsuleTag>[];
  final seen = <String>{};
  for (final category in categories) {
    for (final subgroup in category.subgroups) {
      for (final tag in subgroup.tags) {
        if (tag.tag.isNotEmpty && seen.add(tag.tag.toLowerCase())) {
          flat.add(tag);
        }
      }
    }
  }
  _flatCapsuleCache = flat;
  return flat;
}

/// Searches the bundled capsule taxonomy by English tag or Chinese label.
/// Exact > prefix > contains; works for both Latin and CJK queries.
Future<List<CapsuleTag>> searchCapsuleTags(String query,
    {int limit = 12}) async {
  final raw = query.trim();
  if (raw.isEmpty) return const [];
  final flat = await _flatCapsuleTags();
  final cjk = RegExp(r'[㐀-鿿]').hasMatch(raw);
  final normalized = raw.toLowerCase().replaceAll('_', ' ');
  final scored = <({CapsuleTag tag, int score})>[];
  for (final tag in flat) {
    var score = 0;
    if (cjk) {
      final label = tag.label;
      if (label == raw) {
        score = 3;
      } else if (label.startsWith(raw)) {
        score = 2;
      } else if (label.contains(raw)) {
        score = 1;
      }
    } else {
      final name = tag.tag.toLowerCase().replaceAll('_', ' ');
      if (name == normalized) {
        score = 3;
      } else if (name.startsWith(normalized)) {
        score = 2;
      } else if (name.contains(normalized)) {
        score = 1;
      }
    }
    if (score > 0) scored.add((tag: tag, score: score));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.take(limit).map((item) => item.tag).toList();
}
