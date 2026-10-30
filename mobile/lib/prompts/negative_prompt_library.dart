import 'dart:typed_data';
import 'dart:convert';
import 'prompt_append.dart';
import 'prompt_library_tags.dart';

const negativeBuiltins=[
  {
    'id': 'negative-reinforced-v1',
    'name': '强化版',
    'prompt': r'''2.0::worst quality, normal quality, lowres, text, letters, title, watermark, signature, username, artist name, artist collaboration, 
1.8::bad hands, extra fingers, missing fingers, fused fingers, poorly drawn hands, bad feet, extra toes, missing toes, fused toes, poorly drawn feet, 
1.6::bad anatomy, bad proportions, malformed limbs, extra limbs, missing limbs, disconnected limbs, fused body parts, long neck, unnatural pose, 
1.5::blurry, jpeg artifacts, compression artifacts, glitch, scan lines, chromatic aberration, aliasing, jagged edges, grid noise, edge artifact, denoising failure, 
1.4::poorly drawn face, ugly face, asymmetrical eyes, cross-eyed, iris deformation, disproportional philtrum, facial asymmetry, 
1.3::plastic skin, wax figure, clay render, doll joint, flat color, flat lighting, specular overflow, vignetting, 
1.2::censored, cropped, out of frame, black bars, sketch, unfinished, messy, cartoon, Disney style, Pixar style, cel-shaded, vector art, western woman, western face, blood vessel, 
1.1::frame border, UV stretching, PBR error, subsurface scattering error, ray tracing artifact, digital artifact, unfinished, duplicate''',
    'createdAt': '2026-10-08T00:00:00Z'
  },
  {
    'id': 'negative-light-v1',
    'name': '轻量版',
    'prompt': r'''lowres, bad anatomy, bad hands, extra limbs, missing limbs, deformed, mutated, poorly drawn face, ugly, blurry, out of focus, watermark, text, error, cropped, worst quality, low quality, normal quality, jpeg artifacts, signature, username, artistic error, film grain, scan artifacts, bad quality, very displeasing, chromatic aberration, dithering, halftone, screentone, multiple views, logo, too many watermarks, negative space, blank page,mismatched pupils, glowing eyes''',
    'createdAt': '2026-10-08T00:00:00Z'
  }
];

bool _valid(dynamic p)=>p is Map && p['id'] is String && (p['id'] as String).isNotEmpty && (p['id'] as String).length<=100 && p['name'] is String && (p['name'] as String).trim().isNotEmpty && (p['name'] as String).length<=100 && p['prompt'] is String && (p['prompt'] as String).trim().isNotEmpty && (p['prompt'] as String).length<=100000 && p['createdAt'] is String;
/// Optional `tags` are kept in the desktop app's shape: a normalized list,
/// omitted when empty.
List<Map<String,Object>> normalizeNegativePromptPresets(dynamic value){
 if(value is! List)return negativeBuiltins.map((p)=>Map<String,Object>.from(p)).toList();
 final ids=<String>{};return value.where(_valid).where((p)=>ids.add(p['id'] as String)).take(2000).map((p)=><String,Object>{for(final k in ['id','name','prompt'])k:p[k] as String,...promptTagField(p['tags']),'createdAt':p['createdAt'] as String}).toList();
}
List<String> negativePresetTags(Map<String,Object> preset)=>normalizePromptTags(preset['tags']);
// The desktop's import messages (src/negative-prompt-library.ts), word for word.
const _invalidLibrary='不是有效的负面提示词库文件。';
const negativeLibraryTooLarge='词库文件超过 5 MB。';
dynamic _decodeLibraryJson(String text){try{return jsonDecode(text);}on FormatException{throw const FormatException(_invalidLibrary);}}
List<Map<String,Object>> parseNegativeLibrary(String text){
 if(text.length>5000000)throw const FormatException(negativeLibraryTooLarge);
 final doc=_decodeLibraryJson(text.replaceFirst(RegExp(r'^\uFEFF'),''));
 if(doc is! Map||doc['identifier']!='langbai-negative-prompt-library'||doc['version']!=1||doc['presets'] is! List)throw const FormatException(_invalidLibrary);
 final raw=doc['presets'] as List;if(raw.length>2000||raw.any((p)=>!_valid(p)))throw const FormatException(_invalidLibrary);
 final entries=normalizeNegativePromptPresets(raw);if(entries.length!=raw.length)throw const FormatException('词库中有重复的预设 ID。');return entries;
}
String exportNegativeLibrary(List<Map<String,Object>> entries)=>const JsonEncoder.withIndent('  ').convert({'identifier':'langbai-negative-prompt-library','version':1,'presets':normalizeNegativePromptPresets(entries)});
/// Preserve literal tag weights, repetitions and line breaks. Do not normalize prompts.
String applyNegativePreset(String current,String prompt,String mode)=>mode=='replace'?prompt:appendPromptText(current,prompt);
/// A duplicate (same name and prompt) is not added again; its tags are merged into the existing entry.
List<Map<String,Object>> mergeNegativeLibrary(List<Map<String,Object>> current,List<Map<String,Object>> imported,String Function() newId){final next=current.map((p)=>Map<String,Object>.from(p)).toList();for(final p in imported){final same=next.where((e)=>e['name']==p['name']&&e['prompt']==p['prompt']).firstOrNull;if(same!=null){final tags=mergePromptTags([negativePresetTags(same),negativePresetTags(p)]);if(tags.isNotEmpty)same['tags']=tags;continue;}next.add({...p,'id':next.any((e)=>e['id']==p['id'])?newId():p['id']!});}if(next.length>2000)throw const FormatException('预设最多 2000 个。');return next;}

/// A file that is not UTF-8 is not a valid library.
String decodeNegativeFile(Uint8List bytes){try{return utf8.decode(bytes);}on FormatException{throw const FormatException(_invalidLibrary);}}
/// What the library dialog shows for a failed action: the error's own message without Dart's type prefix, like the desktop's errorText.
String negativeLibraryErrorText(Object error){final text=switch(error){FormatException(:final message)=>message,StateError(:final message)=>message,_=>'$error'.replaceFirst('Exception: ','')}.trim();return text.isEmpty?'操作失败。':text;}
const _negativeLabels={
  "zh-CN": [
    "负面提示词库",
    "选择后预览，再替换或追加；不会改动正面提示词。",
    "搜索名称或提示词",
    "保存当前",
    "新建",
    "编辑",
    "删除",
    "导入",
    "导出",
    "替换",
    "追加",
    "关闭",
    "保存",
    "取消",
    "名称",
    "负面提示词",
    "暂无预设",
    "已保存",
    "已应用负面提示词",
    "确认删除此预设？"
  ],
};
List<String> negativeLibraryLabels(String language)=>_negativeLabels[language]??_negativeLabels['zh-CN']!;
