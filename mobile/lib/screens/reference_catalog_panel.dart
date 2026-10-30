import '../ui/studio_dropdown.dart';
import '../ui/zoomable_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../references/reference_catalog.dart';
import '../state/app_state.dart';

const _all = '__all__';

const _copy = <String, Map<String, String>>{
  'zh-CN': {
    'title': '在线角色精准参考库',
    'hint': '从 GitHub 读取在线目录，只下载每个角色与形态的最佳精准参考图。',
    'load': '读取在线目录',
    'refresh': '刷新目录',
    'loading': '正在读取…',
    'search': '搜索角色、形态或游戏',
    'game': '游戏',
    'category': '分类',
    'perRow': '每排显示',
    'auto': '自动',
    'all': '全部',
    'inGame': '游戏内角色图',
    'illustration': '角色立绘',
    'resource': '角色资源',
    'download': '下载到本机',
    'downloaded': '已下载',
    'progress': '下载进度',
    'size': '大小',
    'retry': '重试',
    'unavailable': '在线目录暂不可用',
    'empty': '没有匹配的角色',
    'more': '加载更多',
    'result': '项角色与形态',
    'preview': '预览',
    'seriesTitle': '整系列下载',
    'seriesHint': '一次下载该游戏全部精准参考图，已保存项目会自动跳过。',
    'selectSeries': '先选择一个游戏系列，即可查看总大小并整包下载。',
    'total': '系列总计',
    'pending': '待下载',
    'saved': '已保存',
    'downloadSeries': '下载整个系列',
    'downloadingSeries': '正在下载系列',
    'seriesDone': '系列下载完成',
    'seriesPartial': '部分项目失败，再次点击可重试未完成项目。',
    'failed': '失败',
    'confirmSeries': '确认下载整个系列？',
    'confirm': '开始下载',
    'cancel': '取消',
  },
};

Map<String, String> _text(String language) =>
    _copy[language] ?? _copy['zh-CN']!;

class ReferenceCatalogPanel extends StatefulWidget {
  final bool autoLoad;
  final ReferenceCatalog? initialCatalog;
  final String? initialGame;

  const ReferenceCatalogPanel({
    super.key,
    this.autoLoad = false,
    this.initialCatalog,
    this.initialGame,
  });

  @override
  State<ReferenceCatalogPanel> createState() => _ReferenceCatalogPanelState();
}

class _ReferenceCatalogPanelState extends State<ReferenceCatalogPanel> {
  ReferenceCatalog? _catalog;
  String _query = '';
  String _game = _all;
  String _category = _all;
  String _error = '';
  bool _loading = false;
  int _visible = 60;
  int _columns = 0;
  final Map<String, int> _progress = {};
  final Set<String> _active = {};
  bool _bulkActive = false;
  String _bulkGame = '';
  int _bulkTotal = 0;
  int _bulkDone = 0;
  int _bulkFailed = 0;
  int _bulkTotalBytes = 0;
  int _bulkProcessedBytes = 0;

  @override
  void initState() {
    super.initState();
    _catalog = widget.initialCatalog;
    _game = widget.initialGame ?? _all;
    if (widget.autoLoad) _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final catalog = await loadOnlineReferenceCatalog(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _visible = 60;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ReferenceCatalogGame> get _games {
    final catalog = _catalog;
    if (catalog == null) return const [];
    if (catalog.games.isNotEmpty) return catalog.games;
    final ids = catalog.assets.map((asset) => asset.game).toSet().toList()
      ..sort();
    return ids
        .map((id) => ReferenceCatalogGame(
              id: id,
              names: catalog.assets
                  .firstWhere((asset) => asset.game == id)
                  .gameNames,
              categories: catalog.assets
                  .where((asset) => asset.game == id)
                  .map((asset) => asset.category)
                  .toSet()
                  .toList(),
            ))
        .toList();
  }

  String _gameName(String id, String language) {
    final game = _games.where((item) => item.id == id).firstOrNull;
    return game?.names[language] ?? game?.names['zh-CN'] ?? id;
  }

  List<String> get _categories {
    if (_catalog == null) return const [];
    if (_game == _all) {
      return _catalog!.assets.map((asset) => asset.category).toSet().toList();
    }
    return _games.where((item) => item.id == _game).firstOrNull?.categories ??
        const [];
  }

  String _categoryName(String value, Map<String, String> text) =>
      value == '游戏内角色图'
          ? text['inGame']!
          : value == '角色立绘'
              ? text['illustration']!
              : text['resource']!;

  List<ReferenceCatalogAsset> get _filtered {
    final needle = _query.trim().toLowerCase();
    return (_catalog?.assets ?? const [])
        .where((asset) =>
            (_game == _all || asset.game == _game) &&
            (_category == _all || asset.category == _category) &&
            (needle.isEmpty || asset.searchText.contains(needle)))
        .toList();
  }

  List<ReferenceCatalogAsset> get _seriesAssets => _game == _all
      ? const []
      : (_catalog?.assets ?? const [])
          .where((asset) => asset.game == _game)
          .toList();

  Future<bool> _download(BuildContext context, ReferenceCatalogAsset asset,
      String language, Map<String, String> text,
      {bool notify = true,
      void Function(int loaded, int total)? onBytes}) async {
    final state = context.read<AppState>();
    if (_active.contains(asset.id) ||
        state.referencePresets.any((preset) => preset.sourceId == asset.id)) {
      return true;
    }
    setState(() {
      _active.add(asset.id);
      _progress[asset.id] = 0;
    });
    try {
      final bytes = await downloadReferenceCatalogAsset(
        asset,
        onProgress: (loaded, total) {
          if (!mounted) return;
          onBytes?.call(loaded, total);
          setState(() => _progress[asset.id] = total <= 0
              ? 0
              : (loaded * 100 / total).round().clamp(0, 100).toInt());
        },
      );
      final error = await state.saveDownloadedPreciseReferencePreset(
        bytes: bytes,
        sourceId: asset.id,
        name: asset.nameFor(language),
        group: '${asset.game} · ${asset.category}',
        width: asset.width,
        height: asset.height,
        sourceNames: asset.names,
        sourceGameNames: asset.gameNames,
        sourceGameId: asset.game,
        sourceCategory: asset.category,
      );
      if (!context.mounted) return false;
      if (notify) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? state.status)),
        );
      }
      return error == null;
    } catch (error) {
      if (notify && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${text['unavailable']}: $error')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _active.remove(asset.id));
    }
  }

  Future<void> _downloadSeries(
    BuildContext context,
    String language,
    Map<String, String> text,
  ) async {
    if (_bulkActive || _game == _all) return;
    final state = context.read<AppState>();
    final downloaded = state.referencePresets
        .where((preset) => preset.sourceId.isNotEmpty)
        .map((preset) => preset.sourceId)
        .toSet();
    final seriesAssets = _seriesAssets;
    final queue =
        seriesAssets.where((asset) => !downloaded.contains(asset.id)).toList();
    if (queue.isEmpty) return;
    final totalBytes = queue.fold<int>(0, (sum, asset) => sum + asset.bytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.cloud_download_outlined),
        title: Text(text['confirmSeries']!),
        content: Text(
          '${_gameName(_game, language)}\n${text['pending']} ${queue.length} · ${formatReferenceCatalogBytes(totalBytes)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text['cancel']!),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text['confirm']!),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !context.mounted) return;
    setState(() {
      _bulkActive = true;
      _bulkGame = _game;
      _bulkTotal = queue.length;
      _bulkDone = 0;
      _bulkFailed = 0;
      _bulkTotalBytes = totalBytes;
      _bulkProcessedBytes = 0;
    });
    var processedBytes = 0;
    for (final asset in queue) {
      if (!mounted || !context.mounted) break;
      final success = await _download(
        context,
        asset,
        language,
        text,
        notify: false,
        onBytes: (loaded, total) {
          if (!mounted) return;
          final estimate = asset.bytes > 0 ? asset.bytes : total;
          setState(() => _bulkProcessedBytes =
              processedBytes + loaded.clamp(0, estimate).toInt());
        },
      );
      if (!mounted) break;
      processedBytes += asset.bytes;
      setState(() {
        if (success) {
          _bulkDone += 1;
        } else {
          _bulkFailed += 1;
        }
        _bulkProcessedBytes = processedBytes;
      });
    }
    if (!mounted || !context.mounted) return;
    setState(() => _bulkActive = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_bulkFailed == 0
          ? '${text['seriesDone']} · $_bulkDone'
          : '${text['seriesPartial']} ${text['failed']} $_bulkFailed'),
    ));
  }

  Future<void> _preview(BuildContext context, ReferenceCatalogAsset asset) =>
      showGalleryImagePreview(context,
          images: _filtered
              .map((i) => _RemoteCatalogImage(
                  urls: i.thumbnailUrls, fit: BoxFit.contain))
              .toList(),
          initialIndex: _filtered.indexWhere((i) => i.id == asset.id),
          captions: _filtered
              .map((i) => i.nameFor(context.read<AppState>().settings.language))
              .toList());

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final language = state.settings.language;
    final text = _text(language);
    final filtered = _filtered;
    final visible = filtered.take(_visible).toList();
    final downloaded = state.referencePresets
        .where((preset) => preset.sourceId.isNotEmpty)
        .map((preset) => preset.sourceId)
        .toSet();
    final seriesAssets = _seriesAssets;
    final seriesTotalBytes =
        seriesAssets.fold<int>(0, (sum, asset) => sum + asset.bytes);
    final seriesPending =
        seriesAssets.where((asset) => !downloaded.contains(asset.id)).toList();
    final seriesPendingBytes =
        seriesPending.fold<int>(0, (sum, asset) => sum + asset.bytes);
    final bulkPercent = _bulkTotalBytes > 0
        ? (_bulkProcessedBytes / _bulkTotalBytes).clamp(0, 1).toDouble()
        : _bulkTotal > 0
            ? ((_bulkDone + _bulkFailed) / _bulkTotal).clamp(0, 1).toDouble()
            : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final intro = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.cloud_download_outlined),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text['title']!,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(text['hint']!,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                );
                final loadButton = FilledButton.tonalIcon(
                  onPressed:
                      _loading ? null : () => _load(refresh: _catalog != null),
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_catalog == null
                          ? Icons.cloud_download_outlined
                          : Icons.refresh),
                  label: Text(_loading
                      ? text['loading']!
                      : _catalog == null
                          ? text['load']!
                          : text['refresh']!),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      intro,
                      const SizedBox(height: 12),
                      loadButton,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: intro),
                    const SizedBox(width: 12),
                    loadButton,
                  ],
                );
              }),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: Text(text['unavailable']!),
                    subtitle: Text(_error,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: TextButton(
                      onPressed: _loading ? null : () => _load(),
                      child: Text(text['retry']!),
                    ),
                  ),
                ),
              ],
              if (_catalog != null) ...[
                const SizedBox(height: 14),
                TextField(
                  decoration: InputDecoration(
                    labelText: text['search'],
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => setState(() {
                              _query = '';
                              _visible = 60;
                            }),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) => setState(() {
                    _query = value;
                    _visible = 60;
                  }),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 560;
                  final controls = <Widget>[
                    StudioDropdownButtonFormField<String>(
                      value: _game,
                      isExpanded: true,
                      decoration: InputDecoration(
                          labelText: text['game'],
                          border: const OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(
                            value: _all, child: Text(text['all']!)),
                        for (final game in _games)
                          DropdownMenuItem(
                              value: game.id,
                              child: Text(_gameName(game.id, language),
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) => setState(() {
                        _game = value ?? _all;
                        _category = _all;
                        _visible = 60;
                      }),
                    ),
                    if (_game == _all || _categories.length > 1)
                      StudioDropdownButtonFormField<String>(
                        value: _category,
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText: text['category'],
                            border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(
                              value: _all, child: Text(text['all']!)),
                          for (final category in _categories)
                            DropdownMenuItem(
                                value: category,
                                child: Text(_categoryName(category, text),
                                    overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (value) => setState(() {
                          _category = value ?? _all;
                          _visible = 60;
                        }),
                      ),
                    StudioDropdownButtonFormField<int>(
                      value: _columns,
                      isExpanded: true,
                      decoration: InputDecoration(
                          labelText: text['perRow'],
                          border: const OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(value: 0, child: Text(text['auto']!)),
                        for (final value in const [1, 2, 3, 4, 5])
                          DropdownMenuItem(value: value, child: Text('$value')),
                      ],
                      onChanged: (value) =>
                          setState(() => _columns = value ?? 0),
                    ),
                  ];
                  return stacked
                      ? Column(children: [
                          for (var i = 0; i < controls.length; i++) ...[
                            controls[i],
                            if (i < controls.length - 1)
                              const SizedBox(height: 10)
                          ]
                        ])
                      : Row(children: [
                          for (var i = 0; i < controls.length; i++) ...[
                            Expanded(child: controls[i]),
                            if (i < controls.length - 1)
                              const SizedBox(width: 10)
                          ]
                        ]);
                }),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _game == _all
                      ? Card(
                          key: const ValueKey('reference-series-empty'),
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: Text(text['selectSeries']!),
                          ),
                        )
                      : Card(
                          key: ValueKey('reference-series-$_game'),
                          margin: EdgeInsets.zero,
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(.34),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      child: const Icon(
                                          Icons.cloud_download_outlined),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(text['seriesTitle']!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                          Text(_gameName(_game, language),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800)),
                                          Text(text['seriesHint']!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      label: Text(
                                          '${text['total']} ${seriesAssets.length} · ${formatReferenceCatalogBytes(seriesTotalBytes)}'),
                                    ),
                                    Chip(
                                      label: Text(
                                          '${text['pending']} ${seriesPending.length} · ${formatReferenceCatalogBytes(seriesPendingBytes)}'),
                                    ),
                                    Chip(
                                      label: Text(
                                          '${text['saved']} ${seriesAssets.length - seriesPending.length}'),
                                    ),
                                  ],
                                ),
                                if (_bulkGame == _game &&
                                    (_bulkActive ||
                                        _bulkDone > 0 ||
                                        _bulkFailed > 0)) ...[
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(
                                      child: Text(
                                        _bulkActive
                                            ? text['downloadingSeries']!
                                            : _bulkFailed > 0
                                                ? text['seriesPartial']!
                                                : text['seriesDone']!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium,
                                      ),
                                    ),
                                    Text(
                                        '${_bulkDone + _bulkFailed}/$_bulkTotal · ${(bulkPercent * 100).round()}%'),
                                  ]),
                                  const SizedBox(height: 5),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(end: bulkPercent),
                                    duration: const Duration(milliseconds: 180),
                                    builder: (context, value, _) =>
                                        LinearProgressIndicator(value: value),
                                  ),
                                  if (_bulkFailed > 0) ...[
                                    const SizedBox(height: 4),
                                    Text('${text['failed']} $_bulkFailed',
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error)),
                                  ],
                                ],
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed:
                                      _bulkActive || seriesPending.isEmpty
                                          ? null
                                          : () => _downloadSeries(
                                              context, language, text),
                                  icon: _bulkActive
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(
                                          Icons.download_for_offline_outlined),
                                  label: Text(_bulkActive
                                      ? '${text['downloadingSeries']} ${_bulkDone + _bulkFailed}/$_bulkTotal'
                                      : seriesPending.isEmpty
                                          ? text['downloaded']!
                                          : text['downloadSeries']!),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Text('${filtered.length} ${text['result']}',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                if (visible.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(30),
                      child: Center(child: Text(text['empty']!)))
                else
                  LayoutBuilder(builder: (context, constraints) {
                    final automaticColumns = constraints.maxWidth >= 1000
                        ? 5
                        : constraints.maxWidth >= 760
                            ? 4
                            : constraints.maxWidth >= 520
                                ? 3
                                : constraints.maxWidth >= 380
                                    ? 2
                                    : 1;
                    final columns = _columns == 0
                        ? automaticColumns
                        : _columns.clamp(1, automaticColumns);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visible.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 330,
                      ),
                      itemBuilder: (_, index) {
                        final asset = visible[index];
                        final busy = _active.contains(asset.id);
                        final done = downloaded.contains(asset.id);
                        final percent = _progress[asset.id] ?? 0;
                        return TweenAnimationBuilder<double>(
                          key: ValueKey('reference-catalog-${asset.id}'),
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(
                              milliseconds: 220 + (index.clamp(0, 10) * 18)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - value)),
                              child: child,
                            ),
                          ),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            margin: EdgeInsets.zero,
                            child: InkWell(
                              onDoubleTap: () => _preview(context, asset),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                        child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                          ColoredBox(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerLow,
                                            child: _RemoteCatalogImage(
                                                urls: asset.thumbnailUrls),
                                          ),
                                          Positioned(
                                              right: 6,
                                              top: 6,
                                              child: IconButton.filledTonal(
                                                tooltip: text['preview'],
                                                onPressed: () =>
                                                    _preview(context, asset),
                                                icon: const Icon(
                                                    Icons.visibility_outlined,
                                                    size: 18),
                                              )),
                                        ])),
                                    Padding(
                                      padding: const EdgeInsets.all(9),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(asset.nameFor(language),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text(
                                                '${_gameName(asset.game, language)} · ${_categoryName(asset.category, text)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall),
                                            Text(
                                                '${asset.width}×${asset.height} · ${text['size']} ${formatReferenceCatalogBytes(asset.bytes)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall),
                                            if (busy) ...[
                                              const SizedBox(height: 6),
                                              TweenAnimationBuilder<double>(
                                                tween: Tween(
                                                    end: percent > 0
                                                        ? percent / 100
                                                        : 0),
                                                duration: const Duration(
                                                    milliseconds: 180),
                                                builder: (context, value, _) =>
                                                    LinearProgressIndicator(
                                                  value: percent > 0
                                                      ? value
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                  '${text['progress']} $percent%',
                                                  textAlign: TextAlign.right,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall),
                                            ] else
                                              const SizedBox(height: 8),
                                            SizedBox(
                                              height: 40,
                                              child: FilledButton.tonal(
                                                onPressed: busy || done
                                                    ? null
                                                    : () => _download(context,
                                                        asset, language, text),
                                                child: Text(
                                                    done
                                                        ? text['downloaded']!
                                                        : text['download']!,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              ),
                                            ),
                                          ]),
                                    ),
                                  ]),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                if (_visible < filtered.length) ...[
                  const SizedBox(height: 12),
                  Center(
                      child: OutlinedButton.icon(
                    onPressed: () => setState(() => _visible += 60),
                    icon: const Icon(Icons.expand_more),
                    label: Text(text['more']!),
                  )),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteCatalogImage extends StatefulWidget {
  final List<String> urls;
  final BoxFit fit;
  const _RemoteCatalogImage({required this.urls, this.fit = BoxFit.contain});

  @override
  State<_RemoteCatalogImage> createState() => _RemoteCatalogImageState();
}

class _RemoteCatalogImageState extends State<_RemoteCatalogImage> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant _RemoteCatalogImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls.join('\n') != widget.urls.join('\n')) _index = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty || _index >= widget.urls.length) {
      return const Center(child: Icon(Icons.broken_image_outlined));
    }
    return Image.network(
      widget.urls[_index],
      fit: widget.fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, synchronous) =>
          frame != null || synchronous
              ? child
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorBuilder: (context, error, stackTrace) {
        if (_index + 1 < widget.urls.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index += 1);
          });
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return const Center(child: Icon(Icons.broken_image_outlined));
      },
    );
  }
}
