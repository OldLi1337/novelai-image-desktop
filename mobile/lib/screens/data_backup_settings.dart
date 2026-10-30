import '../ui/global_typography.dart';
import '../ui/studio_dropdown.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_locales.dart';
import '../services/data_backup_service.dart';
import '../services/storage_permission.dart';
import '../state/app_state.dart';

Map<String, String> _backupText(Object? language) {
  final code = normalizeAppLocaleCode(language);
  const values = <String, Map<String, String>>{
    'zh-CN': {
      'restoreGuide': "选择备份文件即可恢复；先核对分类，再确认导入。",
      'retained': "新版桌面归档已保管 {count} 份；未在移动端运行。导出画风实验室数据后，在桌面导入并使用恢复入口。",
      'rescue': "导入前完整备份：",
      'preserved': "原数据保留位置：",
      'activateHelp': "恢复前将保留当前工作区，再切换到所选数据；不会自动启动任务。模型和运行环境沿用本机配置，请确认兼容后手动启动。",
      'activateRecovery': "恢复使用此数据…",
      'openRecovery': "打开恢复目录",
      'staged': "已保存在恢复目录，尚未替换当前工作区",
      'restored': "已恢复；任务未启动",
      'recoveryTitle': "恢复结果与入口",
      'styleLab': "画风实验室：当前自动迭代结果与参考图",
      'coverage':
          "画风结果在移动端仅保管归档，导回桌面再恢复。模型、运行环境与符号链接不迁移。自动轻量备份不含画风结果，请使用完整备份。",
      'title': '数据导入、导出与自动备份',
      'desc': '桌面、Android 与 iOS 共用 .naisbackup。默认全选，也可以排除任意数据。',
      'sensitive': 'API Token 与第三方密钥会按你的选择直接写入备份，请只交给可信设备。',
      'selectAll': '全选',
      'clear': '清空',
      'export': '导出所选数据',
      'choose': '选择备份文件',
      'import': '导入所选数据',
      'busy': '正在处理…',
      'archive': '待导入归档',
      'mergeTitle': '确认安全合并',
      'merge':
          "所选数据均独立处理。常规记录只合并；画风结果先保存完整恢复副本，当前工作区存在时需在导入结果中手动切换。导入前会生成完整备份。",
      'overwriteTitle': '再次确认覆盖配置',
      'overwrite': '配置与 API 会覆盖现有对应值（设备路径除外）。其它数据仍不会覆盖。',
      'cancel': '取消',
      'continue': '继续',
      'confirm': '确认覆盖并导入',
      'done': '导入完成：新增 {i}，跳过 {s}，重命名 {r}。',
      'autoTitle': '自动备份',
      'auto': '启用自动备份',
      'autoDesc': '默认开启轻量备份；图片默认不自动压缩，导入前仍会额外备份。',
      'images': '自动备份包含图片和参考图',
      'interval': '间隔（小时）',
      'retention': '保留数量',
      'backupNow': '立即完整备份',
      'latest': '最近备份',
      'none': '尚无自动备份',
      'folder': '备份目录',
      'chooseFolder': '选择备份目录',
      'resetFolder': '恢复默认目录',
      'defaultFolder': '应用默认备份目录',
      'folderSaved': '备份目录已更新。',
      'fileSaved': '备份文件已保存。',
      'folderFallback': '所选目录当前不可写，已暂时使用默认目录，备份不会中断。',
      'accessContent':
          '自定义备份目录在 Android 11 及以上需要“所有文件访问权限”。授权后返回应用即可；未授权时备份仍会安全保存到应用默认目录。',
      'count': '{count} 个 · {size}',
      'configuration': '应用配置',
      'apiCredentials': 'API 与敏感数据',
      'artistLibrary': '画师串与独立收藏夹',
      'textHistory': '反推与转换历史',
      'referencePresets': '参考预设与参考图',
      'imageHistory': '本机图片与生成记录',
      'promptPresets': '提示词、风格与预设图',
      'workspaceData': "工具草稿、画风参数与其他本机状态",
    },
  };
  return values[code] ?? values['zh-CN']!;
}

String _bytes(int value) {
  if (value < 1024) return '$value B';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  if (value < 1024 * 1024 * 1024) {
    return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(value / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

class DataBackupSettingsPanel extends StatefulWidget {
  final String? initialBackupPath;
  final bool initiallyExpanded;
  final bool importOnly;

  const DataBackupSettingsPanel({
    super.key,
    this.initialBackupPath,
    this.initiallyExpanded = false,
    this.importOnly = false,
  });

  @override
  State<DataBackupSettingsPanel> createState() =>
      _DataBackupSettingsPanelState();
}

class _DataBackupSettingsPanelState extends State<DataBackupSettingsPanel>
    with WidgetsBindingObserver {
  DataBackupImportReport? lastReport;
  Set<DataBackupCategory> exportSelection = DataBackupCategory.values.toSet();
  Set<DataBackupCategory> importSelection = {};
  DataBackupInspection? inspection;
  DataBackupStatus? backupStatus;
  String? inspectionError;
  bool busy = false;

  DataBackupService get service =>
      DataBackupService(context.read<AppState>().storage);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshStatus();
      final path = widget.initialBackupPath?.trim();
      if (path != null && path.isNotEmpty) _inspectPath(path);
    });
  }

  @override
  void didUpdateWidget(covariant DataBackupSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final path = widget.initialBackupPath?.trim();
    if (path != null &&
        path.isNotEmpty &&
        path != oldWidget.initialBackupPath?.trim()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _inspectPath(path));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final value = await service.status();
      if (mounted) setState(() => backupStatus = value);
    } catch (_) {}
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<bool> _confirm(String title, String message, String action,
      {bool destructive = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(destructive
                ? Icons.warning_amber_rounded
                : Icons.restore_rounded),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_backupText(
                    context.read<AppState>().settings.language)['cancel']!),
              ),
              destructive
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(action),
                    )
                  : FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(action),
                    ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _export(Map<String, String> text) async {
    if (exportSelection.isEmpty) return;
    setState(() => busy = true);
    try {
      final file = await service.createBackup(exportSelection);
      final path = await service.saveBackupFile(
        file,
        dialogTitle: text['export'],
      );
      if (path != null) _message(text['fileSaved']!);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _chooseBackupDirectory(Map<String, String> text) async {
    final app = context.read<AppState>();
    setState(() => busy = true);
    try {
      final selected = await service.chooseBackupDirectory(
        dialogTitle: text['chooseFolder'],
      );
      if (selected == null) return;
      await app.setSettings((settings) => settings.backupDir = selected);
      if (!await StoragePermission.hasAllFilesAccess() && mounted) {
        final detail = settingsDetailTextFor(app.settings.language);
        final authorize = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(detail.fileAccessTitle),
                content: Text(text['accessContent']!),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(detail.later),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(detail.authorize),
                  ),
                ],
              ),
            ) ??
            false;
        if (authorize) await StoragePermission.requestAllFilesAccess();
      }
      await _refreshStatus();
      _message(text['folderSaved']!);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetBackupDirectory(Map<String, String> text) async {
    final app = context.read<AppState>();
    setState(() => busy = true);
    try {
      await app.setSettings((settings) => settings.backupDir = '');
      await _refreshStatus();
      _message(text['folderSaved']!);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _choose() async {
    setState(() => busy = true);
    try {
      final path = await service.pickBackupFile();
      if (path == null) return;
      await _inspectPath(path, managesBusyState: false);
    } catch (error) {
      if (mounted) setState(() => inspectionError = error.toString());
      _message(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _inspectPath(
    String path, {
    bool managesBusyState = true,
  }) async {
    if (managesBusyState && mounted) setState(() => busy = true);
    if (mounted) {
      setState(() {
        inspectionError = null;
        inspection = null;
        importSelection = {};
      });
    }
    try {
      final value = await service.inspect(path);
      if (!mounted) return;
      setState(() {
        inspection = value;
        importSelection =
            value.categories.map((summary) => summary.category).toSet();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => inspectionError = error.toString());
      _message(error.toString());
    } finally {
      if (managesBusyState && mounted) setState(() => busy = false);
    }
  }

  Future<void> _import(Map<String, String> text) async {
    final source = inspection;
    final app = context.read<AppState>();
    if (source == null || importSelection.isEmpty) return;
    if (!await _confirm(
        text['mergeTitle']!, text['merge']!, text['continue']!)) {
      return;
    }
    final overwrites =
        importSelection.contains(DataBackupCategory.configuration) ||
            importSelection.contains(DataBackupCategory.apiCredentials);
    if (overwrites &&
        !await _confirm(
            text['overwriteTitle']!, text['overwrite']!, text['confirm']!,
            destructive: true)) {
      return;
    }
    setState(() => busy = true);
    try {
      final report = await service.importBackup(
        source.path,
        importSelection,
        confirmConfigurationOverwrite: overwrites,
      );
      if (mounted) setState(() => lastReport = report);
      await app.load();
      _message(text['done']!
          .replaceAll('{i}', '${report.imported}')
          .replaceAll('{s}', '${report.skipped}')
          .replaceAll('{r}', '${report.renamed}'));
      await _refreshStatus();
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _backupNow() async {
    setState(() => busy = true);
    try {
      final file = await service.runAutomaticBackup(force: true);
      if (file != null) _message(file.path);
      await _refreshStatus();
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _categoryList(
    Map<String, String> text,
    Set<DataBackupCategory> selection,
    ValueChanged<Set<DataBackupCategory>> onChanged, {
    List<DataBackupCategorySummary>? summaries,
  }) {
    final summaryMap = {
      for (final summary in summaries ?? const <DataBackupCategorySummary>[])
        summary.category: summary,
    };
    final available = summaries == null
        ? DataBackupCategory.values
        : summaries.map((summary) => summary.category);
    return Column(
      children: available.map((category) {
        final summary = summaryMap[category];
        return CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: selection.contains(category),
          title: Text(text[category.id]!),
          subtitle: summary == null
              ? null
              : Text('${summary.items} · ${_bytes(summary.bytes)}'),
          onChanged: busy
              ? null
              : (checked) {
                  final next = {...selection};
                  checked == true ? next.add(category) : next.remove(category);
                  onChanged(next);
                },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final text = _backupText(app.settings.language);
    final status = backupStatus;
    final intervalOptions = <int>{
      1,
      6,
      12,
      24,
      72,
      168,
      app.settings.autoBackupIntervalHours,
    }.toList()
      ..sort();
    final retentionOptions = <int>{
      1,
      3,
      7,
      14,
      30,
      50,
      app.settings.autoBackupRetentionCount,
    }.toList()
      ..sort();
    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded || widget.importOnly,
        title: Text(text['title']!,
            style: Theme.of(context).textTheme.titleMedium),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              "${text['desc']!}\n${text['coverage']!}",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.key_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(child: Text(text['sensitive']!)),
              ]),
            ),
          ),
          if (!widget.importOnly) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() =>
                        exportSelection = DataBackupCategory.values.toSet()),
                child: Text(text['selectAll']!),
              ),
              TextButton(
                onPressed:
                    busy ? null : () => setState(() => exportSelection = {}),
                child: Text(text['clear']!),
              ),
            ]),
            _categoryList(text, exportSelection,
                (value) => setState(() => exportSelection = value)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: busy || exportSelection.isEmpty
                    ? null
                    : () => _export(text),
                icon: const Icon(Icons.archive_rounded),
                label: Text(busy ? text['busy']! : text['export']!),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : _choose,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(text['choose']!),
              ),
            ]),
          ],
          if (widget.importOnly && busy && inspection == null) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(text['busy']!, textAlign: TextAlign.center),
          ],
          if (inspectionError != null) ...[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(child: Text(inspectionError!)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _choose,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(text['choose']!),
            ),
          ],
          if (inspection != null) ...[
            const Divider(height: 28),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_rounded),
              title: Text(text['archive']!),
              subtitle: Text(
                '${inspection!.createdAt.toLocal()} · ${inspection!.sourcePlatform} · v${inspection!.sourceVersion}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _categoryList(
              text,
              importSelection,
              (value) => setState(() => importSelection = value),
              summaries: inspection!.categories,
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed:
                  busy || importSelection.isEmpty ? null : () => _import(text),
              icon: const Icon(Icons.restore_rounded),
              label: Text(text['import']!),
            ),
          ],
          if (lastReport != null) ...[
            const Divider(height: 24),
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: SelectableText(text['recoveryTitle']!,
                    style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(height: 8),
            if (lastReport!.retainedNativeArchives > 0)
              SelectableText(text['retained']!.replaceAll(
                  '{count}', '${lastReport!.retainedNativeArchives}')),
            SelectableText(
                "${text['rescue']}\n${lastReport!.rescueBackupPath}\n${text['restoreGuide']}"),
          ],
          if (!widget.importOnly) ...[
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.backup_rounded),
              title: Text(text['autoTitle']!),
              subtitle: Text(text['autoDesc']!),
            ),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_copy_rounded),
                      title: Text(text['folder']!),
                      subtitle: Text(
                        status?.directory ??
                            (app.settings.backupDir.trim().isEmpty
                                ? text['defaultFolder']!
                                : app.settings.backupDir),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => _chooseBackupDirectory(text),
                            icon: const Icon(Icons.folder_open_rounded),
                            label: Text(text['chooseFolder']!),
                          ),
                          TextButton.icon(
                            onPressed: busy || app.settings.backupDir.isEmpty
                                ? null
                                : () => _resetBackupDirectory(text),
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: Text(text['resetFolder']!),
                          ),
                        ],
                      ),
                    ),
                    if (status?.usingFallbackDirectory == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Text(
                          text['folderFallback']!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: app.settings.autoBackupEnabled,
              title: Text(text['auto']!),
              onChanged: (value) => app.setSettings(
                  (settings) => settings.autoBackupEnabled = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: app.settings.autoBackupIncludeImages,
              title: Text(text['images']!),
              onChanged: (value) => app.setSettings(
                  (settings) => settings.autoBackupIncludeImages = value),
            ),
            Row(children: [
              Expanded(
                child: StudioDropdownButtonFormField<int>(
                  value: app.settings.autoBackupIntervalHours,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: text['interval']!,
                      border: const OutlineInputBorder()),
                  items: intervalOptions
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text('$value')))
                      .toList(),
                  onChanged: (value) => value == null
                      ? null
                      : app.setSettings((settings) =>
                          settings.autoBackupIntervalHours = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudioDropdownButtonFormField<int>(
                  value: app.settings.autoBackupRetentionCount,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: text['retention']!,
                      border: const OutlineInputBorder()),
                  items: retentionOptions
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text('$value')))
                      .toList(),
                  onChanged: (value) => value == null
                      ? null
                      : app.setSettings((settings) =>
                          settings.autoBackupRetentionCount = value),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(text['latest']!),
                subtitle: Text([
                  status?.latest?.toLocal().toString() ?? text['none']!,
                  text['count']!
                      .replaceAll('{count}', '${status?.count ?? 0}')
                      .replaceAll('{size}', _bytes(status?.totalBytes ?? 0)),
                ].join('\n')),
                isThreeLine: false,
                trailing: IconButton(
                  tooltip: text['backupNow']!,
                  onPressed: busy ? null : _backupNow,
                  icon: const Icon(Icons.backup_rounded),
                ),
              ),
            ),
            if (Platform.isIOS || Platform.isAndroid)
              Text("${text['desc']!}\n${text['coverage']!}",
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Dedicated destination for a backup opened from the operating-system share
/// sheet or "Open with" menu. It reuses the exact same inspection, category
/// selection, merge, rescue-backup, and overwrite-confirmation flow as Settings.
class IncomingBackupImportScreen extends StatelessWidget {
  final String filePath;

  const IncomingBackupImportScreen({
    super.key,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.select<AppState, String>(
      (state) => state.settings.language,
    );
    final text = _backupText(language);
    return Scaffold(
      appBar: AppBar(title: studioAppBarTitle(context, Text(text['archive']!))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            DataBackupSettingsPanel(
              initialBackupPath: filePath,
              initiallyExpanded: true,
              importOnly: true,
            ),
          ],
        ),
      ),
    );
  }
}
