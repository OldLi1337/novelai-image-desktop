import '../images/coordinated_file_image.dart';
import '../ui/global_typography.dart';
import '../ui/studio_theme.dart';
import '../ui/studio_dropdown.dart';
import '../ui/zoomable_image.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../artist/artist_recipe.dart';
import '../artist/random_custom_tag_library.dart';
import '../artist/weight_distribution.dart';
import '../i18n/app_locales.dart';
import '../models/nai_models.dart';
import '../prompts/v5_artist_weight_repair.dart';
import '../state/app_state.dart';
import '../ui/quality_preset_control.dart';
import '../ui/weight_distribution_controls.dart';
import 'positive_prompt_preset_sheet.dart';

class _RepairDrawResult {
  final ArtistRecipe recipe;
  final int sequence;
  int seed;
  String status;
  HistoryItem? image;
  String? error;
  String generationModel;
  bool liked;
  bool saving = false;

  _RepairDrawResult(
    this.recipe, {
    required this.sequence,
    required this.seed,
    this.status = 'pending',
    this.image,
    this.error,
    this.generationModel = 'nai-diffusion-5-full',
    this.liked = false,
  });

  Map<String, dynamic> toJson() => {
        'recipe': recipe.toJson(),
        'sequence': sequence,
        'seed': seed,
        'status': status,
        'image': image?.toJson(),
        'error': error,
        'generationModel': generationModel,
        'liked': liked,
      };

  factory _RepairDrawResult.fromJson(Map<String, dynamic> json) =>
      _RepairDrawResult(
        ArtistRecipe.fromJson(
          Map<String, dynamic>.from(json['recipe'] as Map? ?? const {}),
        ),
        sequence: (json['sequence'] as num?)?.toInt() ?? 1,
        seed: (json['seed'] as num?)?.toInt() ?? 1,
        status: json['status']?.toString() ?? 'done',
        image: json['image'] is Map
            ? HistoryItem.fromJson(
                Map<String, dynamic>.from(json['image'] as Map),
              )
            : null,
        error: json['error']?.toString(),
        generationModel:
            json['generationModel']?.toString() ?? 'nai-diffusion-5-full',
        liked: json['liked'] == true,
      );
}

Map<String, String> _repairText(Object? language) {
  return {
    'title': 'V4.5 画师串修复器',
    'subtitle':
        '自动识别画师、质量词和其他 Tag；整串每个有效 Tag 都独立压到原权重的 1/3–1/2，并统一为规范 V5 数值格式。',
    'basis': '用户实测结论与限制',
    'note':
        'NovelAI 官方没有公布 V4.5→V5 换算公式。社区的 1/3–1/2 建议主要来自旧画师权重迁移；按本工具设定，质量词、风格词和其他有效 Tag 也会套用同一范围。结果仅是试验起点，不是官方标准。',
    'safe':
        '显式 artist: 标签和已确认的无前缀画师名会识别为画师；质量、风格、年份、负面和内容 Tag 不会被加上 artist:。重复分隔符和孤立 :: 会自动清理。',
    'strategy': '社区迁移策略',
    'input': 'V4.5 完整 Tag 串',
    'output': '规范 V5 Tag 串',
    'run': '随机修复画师权重',
    'copy': '复制结果',
    'reset': '恢复默认',
    'empty': '请先粘贴画师串。',
    'none': '没有识别到有效 Tag；请检查输入和分隔符。',
    'done':
        '已生成 {candidates} 组候选；每组修复 {count} 个 Tag（画师 {artists}、质量词 {quality}、其他 {other}）。',
    'copied': '已复制结果。',
  };
}

Map<String, String> _drawText(Object? language) {
  return {
    'title': '输入画师串抽卡',
    'hint':
        '沿用修复器的识别与规范流程：每个有效 Tag 先按旧权重的 1/3～1/2 迁移，再限制在自定义最终范围内；不删除任何 Tag。',
    'settings': '抽卡设置',
    'input': '完整 Tag 串',
    'inputHint': '例如：xiaoluo_xl, 1.2::artist:pottsness ::',
    'normalizeHint':
        '自动识别画师、质量词与其他 Tag；只有显式 artist: 和已确认画师名会获得 artist: 前缀。',
    'inputEmpty': '请先粘贴画师串。',
    'none': '没有识别到有效 Tag；请检查输入和分隔符。',
    'min': '最低权重',
    'max': '最高权重',
    'count': '候选组数',
    'base': '正面提示词（固定内容）',
    'fixed': '全批固定 Seed',
    'random': '每张随机 Seed',
    'seed': 'Seed',
    'randomSeed': '随机 Seed',
    'draw': '重新抽权重',
    'generate': '生成这一批',
    'stop': '停止',
    'params': '生图沿用生成页当前参数；非 V5 模型会自动改用 V5 Full。',
    'all':
        '已识别 {count} 个有效 Tag（画师 {artists}、质量词 {quality}、其他 {other}）；每组完整保留。',
    'results': '本批候选',
    'favorites': '收藏夹',
    'shared': '本工具收藏独立保存，不与另外两种画师工具共用',
    'empty': '输入画师串后即可抽取候选。',
    'emptyFavorite': '收藏库暂无内容。',
    'needPrompt': '请填写固定内容提示词。',
    'needDraw': '请先抽取候选。',
    'running': '正在生成 {done}/{total}',
    'complete': '生成完成；可收藏喜欢的结果。',
    'pending': '等待',
    'generating': '生成中',
    'done': '完成',
    'failed': '失败',
    'favorite': '收藏',
    'saved': '已收藏',
    'saving': '保存中',
    'remove': '移除',
    'apply': '应用到生成',
    'retry': '重试',
    'removed': '已移除收藏和本地图片。',
    'preview': '双击或点击按钮预览大图',
  };
}

Map<String, String> _drawParamText(Object? language) {
  return {
    'title': 'NovelAI 生成参数',
    'hint': '参数仅用于本工具批量生图，可自行修改；也可从生成页同步或恢复软件初始参数。',
    'sync': '从生成页同步',
    'reset': '恢复初始参数',
    'model': '模型',
    'size': '图片尺寸',
    'width': '宽度',
    'height': '高度',
    'negative': '负面提示词',
    'steps': '步数',
    'sampler': '采样器',
    'noise': '噪声计划',
    'uc': '负面预设',
  };
}

enum V5ArtistToolMode { repair, draw }

class V5ArtistWeightRepairScreen extends StatefulWidget {
  final VoidCallback onBack;
  final V5ArtistToolMode mode;

  const V5ArtistWeightRepairScreen({
    super.key,
    required this.onBack,
    this.mode = V5ArtistToolMode.repair,
  });

  @override
  State<V5ArtistWeightRepairScreen> createState() =>
      _V5ArtistWeightRepairScreenState();
}

class _V5ArtistWeightRepairScreenState
    extends State<V5ArtistWeightRepairScreen> {
  static const _repairFavoritesKey = 'v5_artist_repair_v1_favorites';
  static const _drawFavoritesKey = 'v5_artist_draw_v1_favorites';
  static const _repairPrefsPrefix = 'v5_artist_repair_v1_';
  static const _drawPrefsPrefix = 'v5_artist_draw_v1_';
  final _input = TextEditingController();
  final _output = TextEditingController();
  final _drawInput = TextEditingController();
  final _drawTagSearch = TextEditingController();
  final _basePrompt = TextEditingController();
  final _minWeight = TextEditingController(text: '0.2');
  final _maxWeight = TextEditingController(text: '1.2');
  final _candidateCount = TextEditingController(text: '8');
  final _seed = TextEditingController(text: '246813579');
  final _width = TextEditingController(text: '832');
  final _height = TextEditingController(text: '1216');
  final _negativePrompt = TextEditingController();
  GenerateParams _generationParams = GenerateParams();
  String _message = '';
  bool _fixedSeed = true;
  bool _running = false;
  bool _batchReady = false;
  bool _cancelled = false;
  bool _showFavorites = false;
  WeightControlMode _weightControlMode = WeightControlMode.novice;
  WeightDistributionConfig _weightDistribution =
      const WeightDistributionConfig();
  final List<_RepairDrawResult> _results = [];
  final List<_RepairDrawResult> _favorites = [];
  final Set<String> _drawStyleTags = <String>{};
  String _drawTagCategory = 'quality';

  String get _prefsPrefix => widget.mode == V5ArtistToolMode.draw
      ? _drawPrefsPrefix
      : _repairPrefsPrefix;
  String get _favoritesKey => widget.mode == V5ArtistToolMode.draw
      ? _drawFavoritesKey
      : _repairFavoritesKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadToolState());
  }

  Future<void> _loadToolState() async {
    if (!mounted) return;
    try {
      await _restoreToolState();
    } catch (error, stack) {
      debugPrint('Artist draw restore failed: $error\n$stack');
      if (mounted) {
        setState(() {
          _message = '抽卡设置读取失败，请恢复默认后重试；收藏文件已保留。';
        });
      }
    }
  }

  Future<void> _restoreToolState() async {
    final app = context.read<AppState>();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final prefix = _prefsPrefix;
    _basePrompt.text =
        prefs.getString('${prefix}positivePrompt') ?? app.params.positivePrompt;
    final savedInput = prefs.getString('${prefix}artistInput') ?? '';
    if (widget.mode == V5ArtistToolMode.draw) {
      _drawInput.text = savedInput;
    } else {
      _input.text = savedInput;
    }
    _minWeight.text = '${prefs.getDouble('${prefix}minWeight') ?? .2}';
    _maxWeight.text = '${prefs.getDouble('${prefix}maxWeight') ?? 1.2}';
    _candidateCount.text = '${prefs.getInt('${prefix}candidateCount') ?? 8}';
    _seed.text = '${prefs.getInt('${prefix}seed') ?? 246813579}';
    _fixedSeed = prefs.getBool('${prefix}fixedSeed') ?? true;
    _weightControlMode =
        prefs.getString('${prefix}weightControlMode') == 'advanced'
            ? WeightControlMode.advanced
            : WeightControlMode.novice;
    _weightDistribution = WeightDistributionConfig(
      mode: prefs.getDouble('${prefix}weightMode') ?? .8,
      leftDispersion: prefs.getDouble('${prefix}weightLeftDispersion') ?? .4,
      rightDispersion: prefs.getDouble('${prefix}weightRightDispersion') ?? .4,
      softBalance: prefs.getDouble('${prefix}weightSoftBalance') ?? 0,
    );
    _drawStyleTags
      ..clear()
      ..addAll(prefs.getStringList('${prefix}styleTags') ?? const <String>[]);
    try {
      final raw = prefs.getString('${prefix}generationParams');
      _generationParams = raw == null
          ? _prepareGenerationParams(app.params)
          : GenerateParams.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
    } catch (_) {
      _generationParams = _prepareGenerationParams(app.params);
    }
    _generationParams
      ..positivePrompt = ''
      ..stylePrompt = '';
    _syncGenerationControllers();
    try {
      final decoded = jsonDecode(
        prefs.getString(_favoritesKey) ?? '[]',
      ) as List;
      _favorites
        ..clear()
        ..addAll(
            decoded.whereType<Map>().map((item) => _RepairDrawResult.fromJson(
                  Map<String, dynamic>.from(item),
                )));
    } catch (_) {
      _favorites.clear();
    }
    if (mounted) setState(() {});
  }

  GenerateParams _prepareGenerationParams(GenerateParams source) {
    final next = source.copy();
    if (!next.isV5) next.model = 'nai-diffusion-5-full';
    next
      ..positivePrompt = ''
      ..stylePrompt = '';
    return next.normalized();
  }

  void _syncGenerationControllers() {
    _width.text = '${_generationParams.width}';
    _height.text = '${_generationParams.height}';
    _negativePrompt.text = _generationParams.negativePrompt;
  }

  Future<void> _saveDrawState() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _prefsPrefix;
    await prefs.setString('${prefix}positivePrompt', _basePrompt.text);
    await prefs.setString(
      '${prefix}artistInput',
      widget.mode == V5ArtistToolMode.draw ? _drawInput.text : _input.text,
    );
    await prefs.setDouble(
        '${prefix}minWeight', double.tryParse(_minWeight.text) ?? .2);
    await prefs.setDouble(
        '${prefix}maxWeight', double.tryParse(_maxWeight.text) ?? 1.2);
    await prefs.setInt('${prefix}candidateCount',
        (int.tryParse(_candidateCount.text) ?? 8).clamp(1, 100).toInt());
    await prefs.setInt('${prefix}seed',
        (int.tryParse(_seed.text) ?? 246813579).clamp(1, 0x7fffffff).toInt());
    await prefs.setBool('${prefix}fixedSeed', _fixedSeed);
    await prefs.setString(
        '${prefix}weightControlMode',
        _weightControlMode == WeightControlMode.advanced
            ? 'advanced'
            : 'novice');
    await prefs.setDouble('${prefix}weightMode', _weightDistribution.mode);
    await prefs.setDouble(
        '${prefix}weightLeftDispersion', _weightDistribution.leftDispersion);
    await prefs.setDouble(
        '${prefix}weightRightDispersion', _weightDistribution.rightDispersion);
    await prefs.setDouble(
        '${prefix}weightSoftBalance', _weightDistribution.softBalance);
    await prefs.setStringList(
        '${prefix}styleTags', _drawStyleTags.toList(growable: false));
    _generationParams.negativePrompt = _negativePrompt.text;
    await prefs.setString(
        '${prefix}generationParams', jsonEncode(_generationParams.toJson()));
  }

  void _commitDimension(TextEditingController controller, bool width) {
    final fallback = width ? _generationParams.width : _generationParams.height;
    final value = int.tryParse(controller.text) ?? fallback;
    final snapped = snapNaiDimensionWithinArea(
      value,
      width ? _generationParams.height : _generationParams.width,
      fallback,
    );
    setState(() {
      controller.text = '$snapped';
      if (width) {
        _generationParams.width = snapped;
      } else {
        _generationParams.height = snapped;
      }
    });
    _saveDrawState();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _favoritesKey,
      jsonEncode(_favorites.map((item) => item.toJson()).toList()),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _output.dispose();
    _drawInput.dispose();
    _drawTagSearch.dispose();
    _basePrompt.dispose();
    _minWeight.dispose();
    _maxWeight.dispose();
    _candidateCount.dispose();
    _seed.dispose();
    _width.dispose();
    _height.dispose();
    _negativePrompt.dispose();
    super.dispose();
  }

  Future<void> _run(Map<String, String> text) async {
    setState(() => _batchReady = false);
    if (_input.text.trim().isEmpty) {
      setState(() {
        _output.clear();
        _message = text['empty']!;
      });
      return;
    }
    final normalized = normalizeV45ArtistSyntax(_input.text);
    final recipes = repairV45ArtistCandidatesForV5(
      input: _input.text,
      count: (int.tryParse(_candidateCount.text) ?? 8).clamp(1, 100),
      drawSeed: _freshSeed(),
      weightDistribution: _weightControlMode == WeightControlMode.advanced
          ? _weightDistribution
          : null,
    );
    if (recipes.isEmpty) {
      setState(() {
        _output.clear();
        _message = text['none']!;
      });
      return;
    }
    await _installRecipes(recipes);
    if (!mounted) return;
    setState(() {
      _output.text = recipes.first.prompt;
      _message = text['done']!
          .replaceAll('{candidates}', recipes.length.toString())
          .replaceAll('{count}', normalized.totalAdjusted.toString())
          .replaceAll('{artists}', normalized.artistTagCount.toString())
          .replaceAll('{quality}', normalized.qualityTagCount.toString())
          .replaceAll('{other}', normalized.otherTagCount.toString());
    });
    _saveDrawState();
  }

  void _reset() {
    setState(() {
      _minWeight.text = '0.2';
      _maxWeight.text = '1.2';
      _candidateCount.text = '8';
      _seed.text = '246813579';
      _fixedSeed = true;
      _weightControlMode = WeightControlMode.novice;
      _weightDistribution = const WeightDistributionConfig();
      _message = '';
    });
    _saveDrawState();
  }

  int _freshSeed() => Random.secure().nextInt(0x7fffffff) + 1;

  Future<void> _clearTemporaryResults() async {
    final app = context.read<AppState>();
    final temporary = _results
        .where((item) => !item.liked && item.image != null)
        .map((item) => item.image!)
        .toList();
    _results.clear();
    for (final image in temporary) {
      await app.deleteArtistLabTemporary(image).catchError((_) {});
    }
  }

  Future<void> _installRecipes(List<ArtistRecipe> recipes) async {
    await _clearTemporaryResults();
    if (!mounted) return;
    final model = _generationParams.model;
    final fixed =
        (int.tryParse(_seed.text) ?? 246813579).clamp(1, 0x7fffffff).toInt();
    setState(() {
      _results.addAll(List.generate(
        recipes.length,
        (index) => _RepairDrawResult(
          recipes[index],
          sequence: index + 1,
          seed: _fixedSeed ? fixed : _freshSeed(),
          generationModel: model,
        ),
      ));
      _showFavorites = false;
      _batchReady = true;
    });
  }

  Future<void> _draw(Map<String, String> text) async {
    setState(() => _batchReady = false);
    if (_drawInput.text.trim().isEmpty) {
      setState(() => _message = text['inputEmpty']!);
      return;
    }
    final source = <String>[
      _drawInput.text.trim(),
      ..._drawStyleTags,
    ].where((value) => value.isNotEmpty).join(', ');
    final normalized = normalizeV45ArtistSyntax(source);
    final recipes = drawAllV5ArtistWeights(
      input: normalized.output,
      count: (int.tryParse(_candidateCount.text) ?? 8).clamp(1, 100),
      minWeight: double.tryParse(_minWeight.text) ?? .2,
      maxWeight: double.tryParse(_maxWeight.text) ?? 1.2,
      drawSeed: _freshSeed(),
      weightDistribution: _weightControlMode == WeightControlMode.advanced
          ? _weightDistribution
          : null,
    );
    if (recipes.isEmpty) {
      setState(() => _message = text['none']!);
      return;
    }
    await _installRecipes(recipes);
    if (!mounted) return;
    setState(() {
      _message = text['all']!
          .replaceAll('{count}', normalized.totalAdjusted.toString())
          .replaceAll('{artists}', normalized.artistTagCount.toString())
          .replaceAll('{quality}', normalized.qualityTagCount.toString())
          .replaceAll('{other}', normalized.otherTagCount.toString());
    });
    _saveDrawState();
  }

  Widget _drawStyleTagLibrary(AppState app) {
    final language = normalizeAppLocaleCode(app.settings.language);
    final category = randomCustomTagLibrary.firstWhere(
      (item) => item.id == _drawTagCategory,
      orElse: () => randomCustomTagLibrary.first,
    );
    final query = _drawTagSearch.text.trim().toLowerCase();
    final entries = category.tags.where((entry) {
      if (query.isEmpty) return true;
      return entry.tag.toLowerCase().contains(query) ||
          entry.labels.values
              .any((label) => label.toLowerCase().contains(query));
    }).toList(growable: false);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.style_outlined),
        title: const Text('画风 Tag 库'),
        subtitle: Text('已选 ${_drawStyleTags.length} 个；每个候选都会加入并随机赋权'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          TextField(
            controller: _drawTagSearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _drawTagSearch.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
              hintText: '搜索 Tag 或含义',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: randomCustomTagLibrary.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = randomCustomTagLibrary[index];
                return ChoiceChip(
                  selected: item.id == _drawTagCategory,
                  label: Text('${item.label(language)} ${item.tags.length}'),
                  onSelected: (_) => setState(() => _drawTagCategory = item.id),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: entries.isEmpty
                ? const Center(child: Text('没有匹配的 Tag'))
                : ListView.builder(
                    primary: false,
                    itemCount: entries.length,
                    itemExtent: 54,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final selected = _drawStyleTags.contains(entry.tag);
                      return CheckboxListTile(
                        dense: true,
                        value: selected,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(entry.tag,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(entry.label(language),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onChanged: (_) {
                          setState(() {
                            if (selected) {
                              _drawStyleTags.remove(entry.tag);
                            } else {
                              _drawStyleTags.add(entry.tag);
                            }
                          });
                          _saveDrawState();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateOne(_RepairDrawResult result) async {
    final app = context.read<AppState>();
    final fixed = _generationParams.copy()
      ..positivePrompt = _basePrompt.text.trim()
      ..negativePrompt = _negativePrompt.text
      ..stylePrompt = result.recipe.prompt
      ..seedMode = 'fixed'
      ..seed = result.seed;
    setState(() {
      result
        ..status = 'generating'
        ..error = null
        ..generationModel = fixed.model;
    });
    try {
      final image = await app.generateArtistLabTemporary(
        panelParams: fixed,
        panelExtras: GenerateExtras(),
      );
      if (!mounted) return;
      setState(() {
        result
          ..image = image
          ..status = 'done'
          ..generationModel =
              image.model.isNotEmpty ? image.model : fixed.model;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        result
          ..status = 'failed'
          ..error = error.toString();
      });
    }
  }

  Future<void> _generate(Map<String, String> text) async {
    if (_running) return;
    if (!_batchReady || _results.isEmpty) {
      setState(() => _message = text['needDraw']!);
      return;
    }
    if (_basePrompt.text.trim().isEmpty) {
      setState(() => _message = text['needPrompt']!);
      return;
    }
    setState(() {
      _running = true;
      _cancelled = false;
    });
    for (final result in _results) {
      if (_cancelled) break;
      await _generateOne(result);
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _message = _cancelled ? text['stop']! : text['complete']!;
    });
  }

  void _stop() {
    _cancelled = true;
    context.read<AppState>().cancelGeneration();
  }

  Future<void> _retry(_RepairDrawResult result) async {
    if (_running) return;
    setState(() => _running = true);
    await _generateOne(result);
    if (mounted) setState(() => _running = false);
  }

  Future<void> _favorite(_RepairDrawResult result) async {
    if (result.image == null || result.liked || result.saving) return;
    final app = context.read<AppState>();
    setState(() => result.saving = true);
    try {
      result.image = await app.saveArtistLabFavorite(result.image!);
      result
        ..liked = true
        ..saving = false
        ..status = 'done';
      _favorites.removeWhere((item) => item.recipe.id == result.recipe.id);
      _favorites.insert(0, result);
      await _saveFavorites();
    } catch (error) {
      result
        ..saving = false
        ..error = error.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> _removeFavorite(
    _RepairDrawResult result,
    Map<String, String> text,
  ) async {
    if (result.image == null) return;
    await context.read<AppState>().deleteHistory(result.image!.id);
    _favorites.removeWhere((item) => item.recipe.id == result.recipe.id);
    _results.removeWhere((item) => item.recipe.id == result.recipe.id);
    await _saveFavorites();
    if (mounted) setState(() => _message = text['removed']!);
  }

  void _apply(_RepairDrawResult result) {
    final app = context.read<AppState>();
    final value = _generationParams.copy()
      ..model = result.generationModel
      ..positivePrompt = _basePrompt.text.trim()
      ..negativePrompt = _negativePrompt.text
      ..stylePrompt = result.recipe.prompt
      ..seedMode = 'fixed'
      ..seed = result.seed;
    app.setParam((target) {
      target
        ..model = value.model
        ..stylePrompt = value.stylePrompt
        ..positivePrompt = value.positivePrompt
        ..negativePrompt = value.negativePrompt
        ..width = value.width
        ..height = value.height
        ..steps = value.steps
        ..cfgScale = value.cfgScale
        ..cfgRescale = value.cfgRescale
        ..sampler = value.sampler
        ..noiseSchedule = value.noiseSchedule
        ..seed = value.seed
        ..seedMode = value.seedMode
        ..ucPreset = value.ucPreset
        ..qualityPreset = value.qualityPreset
        ..qualityToggle = value.qualityToggle
        ..transparentBackground = value.transparentBackground
        ..smea = value.smea
        ..smeaDyn = value.smeaDyn
        ..variety = value.variety
        ..fileNamePrefix = value.fileNamePrefix;
    });
  }

  Future<void> _previewResult(
      _RepairDrawResult result, Map<String, String> text) async {
    final list = (_showFavorites ? _favorites : _results)
        .where((i) => i.image != null)
        .toList();
    await showGalleryImagePreview(context,
        images: list
            .map((i) => imageFile(File(i.image!.filePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined)))
            .toList(),
        initialIndex: list.indexOf(result),
        captions: list
            .map((i) =>
                '${i.generationModel} · ${i.image!.width}×${i.image!.height}')
            .toList());
  }

  Widget _drawResultCard(
    _RepairDrawResult result,
    Map<String, String> text, {
    bool favorite = false,
  }) {
    final width = result.image?.width ?? _generationParams.width;
    final height = result.image?.height ?? _generationParams.height;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            title: Text('#${result.sequence.toString().padLeft(2, '0')}'),
            subtitle: Text('${result.generationModel} · $width×$height'),
            trailing: Text(favorite || result.liked
                ? text['saved']!
                : text[result.status] ?? result.status),
          ),
          AspectRatio(
            aspectRatio: width / max(1, height),
            child: result.image == null
                ? Center(
                    child: result.status == 'generating'
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.image_outlined, size: 42),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: () => _previewResult(result, text),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        imageFile(
                          File(result.image!.filePath),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 42,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: IconButton.filledTonal(
                            tooltip: text['preview'],
                            onPressed: () => _previewResult(result, text),
                            icon: const Icon(Icons.zoom_in),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              result.recipe.prompt,
              maxLines: 5,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (result.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                result.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              if (favorite)
                TextButton.icon(
                  onPressed: () => _removeFavorite(result, text),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(text['remove']!),
                )
              else if (result.status == 'failed')
                TextButton.icon(
                  onPressed: _running ? null : () => _retry(result),
                  icon: const Icon(Icons.refresh),
                  label: Text(text['retry']!),
                )
              else
                TextButton.icon(
                  onPressed:
                      result.status == 'done' && !result.liked && !result.saving
                          ? () => _favorite(result)
                          : null,
                  icon: Icon(
                      result.liked ? Icons.favorite : Icons.favorite_border),
                  label: Text(result.saving
                      ? text['saving']!
                      : result.liked
                          ? text['saved']!
                          : text['favorite']!),
                ),
              FilledButton(
                onPressed:
                    result.status == 'done' ? () => _apply(result) : null,
                child: Text(text['apply']!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool decimal = false,
    double width = 145,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          border: const OutlineInputBorder(),
        ),
        onEditingComplete: _saveDrawState,
        onTapOutside: (_) => _saveDrawState(),
      ),
    );
  }

  Widget _generationSettingsCard(
    AppState app,
    Map<String, String> text,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>('v5-artist-draw-generation'),
        initiallyExpanded: true,
        maintainState: true,
        title: Text(text['title']!),
        subtitle: Text(text['hint']!),
        trailing: PopupMenuButton<String>(
          popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : AppMotion.disclosureStyle,
          tooltip: text['title'],
          icon: const Icon(Icons.tune),
          onSelected: (value) {
            setState(() {
              _generationParams = value == 'sync'
                  ? _prepareGenerationParams(app.params)
                  : GenerateParams();
              _syncGenerationControllers();
            });
            _saveDrawState();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'sync',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync),
                title: Text(text['sync']!),
              ),
            ),
            PopupMenuItem(
              value: 'reset',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt),
                title: Text(text['reset']!),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: LayoutBuilder(builder: (context, constraints) {
              final fieldWidth = constraints.maxWidth >= 620
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: constraints.maxWidth,
                    child: StudioDropdownButtonFormField<String>(
                      key: ValueKey('v5-draw-model-${_generationParams.model}'),
                      value: _generationParams.model,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: text['model']),
                      items: naiModels
                          .map((option) => DropdownMenuItem(
                                value: option.value,
                                child: Text(localizedNaiOptionLabel(
                                  app.settings.language,
                                  option.value,
                                  option.label,
                                )),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _generationParams.model = value;
                          if (!_generationParams.isV5) {
                            if (_generationParams.qualityPreset == 'light') {
                              _generationParams.qualityPreset = 'standard';
                            }
                            _generationParams.transparentBackground = false;
                          }
                          _generationParams.qualityToggle =
                              _generationParams.qualityPreset != 'none';
                        });
                        _saveDrawState();
                      },
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text['size']!,
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: sizePresets
                              .map((preset) => ChoiceChip(
                                    label: Text(localizedSizePresetLabel(
                                      app.settings.language,
                                      preset.width,
                                      preset.height,
                                      preset.label,
                                    )),
                                    selected: _generationParams.width ==
                                            preset.width &&
                                        _generationParams.height ==
                                            preset.height,
                                    onSelected: (_) {
                                      setState(() {
                                        _generationParams
                                          ..width = preset.width
                                          ..height = preset.height;
                                        _syncGenerationControllers();
                                      });
                                      _saveDrawState();
                                    },
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: _width,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: text['width']),
                      onEditingComplete: () => _commitDimension(_width, true),
                      onTapOutside: (_) => _commitDimension(_width, true),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: _height,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: text['height']),
                      onEditingComplete: () => _commitDimension(_height, false),
                      onTapOutside: (_) => _commitDimension(_height, false),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: StudioDropdownButtonFormField<String>(
                      key: ValueKey(
                          'v5-draw-sampler-${_generationParams.sampler}'),
                      value: _generationParams.sampler,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: text['sampler']),
                      items: naiSamplers
                          .map((option) => DropdownMenuItem(
                                value: option.value,
                                child: Text(localizedNaiOptionLabel(
                                  app.settings.language,
                                  option.value,
                                  option.label,
                                )),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _generationParams.sampler = value);
                        _saveDrawState();
                      },
                    ),
                  ),
                  if (_generationParams.supportsNoiseScheduleControl)
                    SizedBox(
                      width: fieldWidth,
                      child: StudioDropdownButtonFormField<String>(
                        key: ValueKey(
                            'v5-draw-noise-${_generationParams.noiseSchedule}'),
                        value: _generationParams.noiseSchedule,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: text['noise']),
                        items: naiNoiseSchedules
                            .map((option) => DropdownMenuItem(
                                  value: option.value,
                                  child: Text(localizedNaiOptionLabel(
                                    app.settings.language,
                                    option.value,
                                    option.label,
                                  )),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(
                              () => _generationParams.noiseSchedule = value);
                          _saveDrawState();
                        },
                      ),
                    ),
                  SizedBox(
                    width: fieldWidth,
                    child: StudioDropdownButtonFormField<int>(
                      key: ValueKey('v5-draw-uc-${_generationParams.ucPreset}'),
                      value: _generationParams.ucPreset,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: text['uc']),
                      items: ucPresets
                          .map((option) => DropdownMenuItem(
                                value: int.parse(option.value),
                                child: Text(localizedNaiOptionLabel(
                                  app.settings.language,
                                  option.value,
                                  option.label,
                                )),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _generationParams.ucPreset = value);
                        _saveDrawState();
                      },
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${text['steps']} · ${_generationParams.steps}'),
                        Slider(
                          value:
                              _generationParams.steps.clamp(1, 50).toDouble(),
                          min: 1,
                          max: 50,
                          divisions: 49,
                          onChanged: (value) => setState(
                              () => _generationParams.steps = value.round()),
                          onChangeEnd: (_) => _saveDrawState(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'CFG Scale · ${_generationParams.cfgScale.toStringAsFixed(1)}'),
                        Slider(
                          value: _generationParams.cfgScale.clamp(1, 10),
                          min: 1,
                          max: 10,
                          divisions: 45,
                          onChanged: (value) => setState(
                              () => _generationParams.cfgScale = value),
                          onChangeEnd: (_) => _saveDrawState(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'CFG Rescale · ${_generationParams.cfgRescale.toStringAsFixed(2)}'),
                        Slider(
                          value: _generationParams.cfgRescale.clamp(0, 1),
                          min: 0,
                          max: 1,
                          divisions: 100,
                          onChanged: (value) => setState(
                              () => _generationParams.cfgRescale = value),
                          onChangeEnd: (_) => _saveDrawState(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: QualityPresetControl(
                      language: app.settings.language,
                      model: _generationParams.model,
                      value: _generationParams.qualityPreset,
                      transparentBackground:
                          _generationParams.transparentBackground,
                      onChanged: (value) {
                        setState(() => _generationParams
                          ..qualityPreset = value
                          ..qualityToggle = value != 'none');
                        _saveDrawState();
                      },
                      onTransparentChanged: (value) {
                        setState(() =>
                            _generationParams.transparentBackground = value);
                        _saveDrawState();
                      },
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: TextField(
                      controller: _negativePrompt,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(labelText: text['negative']),
                      onChanged: (value) {
                        _generationParams.negativePrompt = value;
                        _saveDrawState();
                      },
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (_generationParams.supportsVariety)
                          FilterChip(
                            label: const Text('Variety+'),
                            selected: _generationParams.variety,
                            onSelected: (value) {
                              setState(() => _generationParams.variety = value);
                              _saveDrawState();
                            },
                          ),
                        if (!_generationParams.isV4Plus)
                          FilterChip(
                            label: const Text('SMEA'),
                            selected: _generationParams.smea,
                            onSelected: (value) {
                              setState(() {
                                _generationParams.smea = value;
                                if (!value) _generationParams.smeaDyn = false;
                              });
                              _saveDrawState();
                            },
                          ),
                        if (!_generationParams.isV4Plus)
                          FilterChip(
                            label: const Text('SMEA Dyn'),
                            selected: _generationParams.smeaDyn,
                            onSelected: _generationParams.smea
                                ? (value) {
                                    setState(() =>
                                        _generationParams.smeaDyn = value);
                                    _saveDrawState();
                                  }
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  List<Widget> _resultWorkspace(
    AppState app,
    Map<String, String> text,
  ) =>
      [
        const SizedBox(height: 12),
        _generationSettingsCard(app, _drawParamText(app.settings.language)),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text('${text['results']} (${_results.length})'),
            ),
            ButtonSegment(
              value: true,
              label: Text('${text['favorites']} (${_favorites.length})'),
            ),
          ],
          selected: {_showFavorites},
          onSelectionChanged: (values) =>
              setState(() => _showFavorites = values.first),
        ),
        const SizedBox(height: 6),
        Text(
          text['shared']!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        if (!_showFavorites && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(text['empty']!, textAlign: TextAlign.center),
          )
        else if (_showFavorites && _favorites.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(text['emptyFavorite']!, textAlign: TextAlign.center),
          )
        else
          ...(_showFavorites ? _favorites : _results).map(
            (item) => _drawResultCard(
              item,
              text,
              favorite: _showFavorites,
            ),
          ),
      ];

  List<Widget> _drawWorkspace(
    AppState app,
    ColorScheme colors,
    Map<String, String> text,
    int completed,
  ) {
    return [
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text['settings']!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: _drawInput,
                minLines: 4,
                maxLines: 9,
                onChanged: (_) => setState(() => _message = ''),
                decoration: InputDecoration(
                  labelText: text['input'],
                  hintText: text['inputHint'],
                  helperText: text['normalizeHint'],
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              _drawStyleTagLibrary(app),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 700
                      ? 3
                      : constraints.maxWidth >= 360
                          ? 2
                          : 1;
                  final fieldWidth =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _numberField(_minWeight, text['min']!,
                          decimal: true, width: fieldWidth),
                      _numberField(_maxWeight, text['max']!,
                          decimal: true, width: fieldWidth),
                      _numberField(_candidateCount, text['count']!,
                          width: fieldWidth),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              WeightDistributionControls(
                mode: _weightControlMode,
                lower: double.tryParse(_minWeight.text) ?? .2,
                upper: double.tryParse(_maxWeight.text) ?? 1.2,
                config: _weightDistribution,
                onModeChanged: (value) {
                  setState(() => _weightControlMode = value);
                  _saveDrawState();
                },
                onChanged: (value) {
                  setState(() => _weightDistribution = value);
                  _saveDrawState();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _basePrompt,
                minLines: 3,
                maxLines: 7,
                decoration: InputDecoration(
                  labelText: text['base'],
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _saveDrawState(),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedBuilder(
                  animation: _basePrompt,
                  builder: (context, _) => PositivePromptPresetButton(
                    currentPrompt: _basePrompt.text,
                    compact: true,
                    onApply: (value) {
                      _basePrompt.text = value;
                      _basePrompt.selection = TextSelection.collapsed(
                          offset: _basePrompt.text.length);
                      _saveDrawState();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.push_pin_outlined),
                    label: Text(text['fixed']!),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(text['random']!),
                  ),
                ],
                selected: {_fixedSeed},
                onSelectionChanged: (values) {
                  setState(() => _fixedSeed = values.first);
                  _saveDrawState();
                },
              ),
              if (_fixedSeed) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _seed,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: text['seed'],
                          border: const OutlineInputBorder(),
                        ),
                        onEditingComplete: _saveDrawState,
                        onTapOutside: (_) => _saveDrawState(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: text['randomSeed'],
                      onPressed: () {
                        setState(() => _seed.text = '${_freshSeed()}');
                        _saveDrawState();
                      },
                      icon: const Icon(Icons.casino_outlined),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _running ? null : () => _draw(text),
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(text['draw']!),
                  ),
                  if (_running)
                    FilledButton.tonalIcon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(text['stop']!),
                    )
                  else
                    FilledButton.icon(
                      onPressed:
                          !_batchReady || _results.isEmpty ? null : () => _generate(text),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(text['generate']!),
                    ),
                ],
              ),
              if (_running) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _results.isEmpty ? null : completed / _results.length,
                ),
                const SizedBox(height: 5),
                Text(text['running']!
                    .replaceAll('{done}', '$completed')
                    .replaceAll('{total}', '${_results.length}')),
              ],
              if (_message.isNotEmpty && !_running) ...[
                const SizedBox(height: 10),
                Text(
                  _message,
                  style: TextStyle(
                    color: _message == text['none']
                        ? colors.error
                        : colors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ..._resultWorkspace(app, text),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final language = app.settings.language;
    final text = _repairText(language);
    final drawText = _drawText(language);
    final colors = Theme.of(context).colorScheme;
    final completed = _results
        .where((item) => item.status == 'done' || item.status == 'failed')
        .length;
    if (widget.mode == V5ArtistToolMode.draw) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: studioAppBarTitle(context, Text(drawText['title']!)),
          actions: [
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt),
              label: Text(text['reset']!),
            ),
          ],
        ),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 36),
          children: [
            Text(
              drawText['hint']!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ..._drawWorkspace(app, colors, drawText, completed),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: studioAppBarTitle(context, Text(text['title']!)),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 36),
        children: [
          Text(text['subtitle']!,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            color: colors.primaryContainer.withAlpha(88),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text['basis']!,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(text['note']!),
                        const SizedBox(height: 7),
                        Text(text['safe']!,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.casino_outlined,
                          size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(text['strategy']!,
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      Text(
                        '×0.333–0.5',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _input,
                    onChanged: (_) => setState(() => _output.clear()),
                    minLines: 5,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: text['input'],
                      hintText:
                          '(artist:foo:1.2), {artist:bar}, [artist:baz], 1.2::artist:qux ::',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: colors.surface,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: colors.outlineVariant)),
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primaryContainer,
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Icon(Icons.arrow_downward,
                              size: 17, color: colors.primary),
                        ),
                        Expanded(child: Divider(color: colors.outlineVariant)),
                      ],
                    ),
                  ),
                  TextField(
                    controller: _output,
                    readOnly: true,
                    minLines: 5,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: text['output'],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: colors.primaryContainer.withAlpha(44),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _numberField(
                    _candidateCount,
                    drawText['count']!,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 12),
                  WeightDistributionControls(
                    mode: _weightControlMode,
                    lower: minV5ArtistRepairMultiplier,
                    upper: maxV5ArtistRepairMultiplier,
                    config: _weightDistribution,
                    onModeChanged: (value) {
                      setState(() => _weightControlMode = value);
                      _saveDrawState();
                    },
                    onChanged: (value) {
                      setState(() => _weightDistribution = value);
                      _saveDrawState();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _basePrompt,
                    minLines: 3,
                    maxLines: 7,
                    onChanged: (_) => _saveDrawState(),
                    decoration: InputDecoration(
                      labelText: drawText['base'],
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedBuilder(
                      animation: _basePrompt,
                      builder: (context, _) => PositivePromptPresetButton(
                        currentPrompt: _basePrompt.text,
                        compact: true,
                        onApply: (value) {
                          _basePrompt.text = value;
                          _basePrompt.selection = TextSelection.collapsed(
                              offset: _basePrompt.text.length);
                          _saveDrawState();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.push_pin_outlined),
                        label: Text(drawText['fixed']!),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.casino_outlined),
                        label: Text(drawText['random']!),
                      ),
                    ],
                    selected: {_fixedSeed},
                    onSelectionChanged: (values) {
                      setState(() => _fixedSeed = values.first);
                      _saveDrawState();
                    },
                  ),
                  if (_fixedSeed) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _seed,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: drawText['seed'],
                              border: const OutlineInputBorder(),
                            ),
                            onEditingComplete: _saveDrawState,
                            onTapOutside: (_) => _saveDrawState(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: drawText['randomSeed'],
                          onPressed: () {
                            setState(() => _seed.text = '${_freshSeed()}');
                            _saveDrawState();
                          },
                          icon: const Icon(Icons.casino_outlined),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _running ? null : () => _run(text),
                        icon: const Icon(Icons.auto_fix_high),
                        label: Text(text['run']!),
                      ),
                      OutlinedButton.icon(
                        onPressed: _output.text.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _output.text),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(text['copied']!)),
                                );
                              },
                        icon: const Icon(Icons.content_copy_outlined),
                        label: Text(text['copy']!),
                      ),
                      if (_running)
                        FilledButton.tonalIcon(
                          onPressed: _stop,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(drawText['stop']!),
                        )
                      else
                        FilledButton.icon(
                          onPressed: !_batchReady || _results.isEmpty
                              ? null
                              : () => _generate(drawText),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(drawText['generate']!),
                        ),
                    ],
                  ),
                  if (_running) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value:
                          _results.isEmpty ? null : completed / _results.length,
                    ),
                    const SizedBox(height: 5),
                    Text(drawText['running']!
                        .replaceAll('{done}', '$completed')
                        .replaceAll('{total}', '${_results.length}')),
                  ],
                  if (_message.isNotEmpty && !_running) ...[
                    const SizedBox(height: 10),
                    Text(
                      _message,
                      style: TextStyle(
                        color: _message == text['none']
                            ? colors.error
                            : colors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ..._resultWorkspace(app, drawText),
        ],
      ),
    );
  }
}
