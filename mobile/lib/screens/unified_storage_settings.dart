import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_permission.dart';
import '../services/unified_storage.dart';
import '../state/app_state.dart';

class UnifiedStorageSettings extends StatefulWidget {
  const UnifiedStorageSettings({super.key});
  @override
  State<UnifiedStorageSettings> createState() => _UnifiedStorageSettingsState();
}

class _UnifiedStorageSettingsState extends State<UnifiedStorageSettings> {
  bool busy = false;
  String message = '';
  String text(String key) {
    final language = context.read<AppState>().settings.language;
    const words = {
      'zh-CN': [
        '统一数据目录',
        '将本机预设、图片、记录和备份集中存放。自定义路径不变；密钥保持私有。',
        '复制并校验迁移',
        '已启用',
        '当前使用应用私有目录',
        '请在系统页面开启文件访问权限，然后返回点击迁移。',
        '迁移期间请勿编辑资料；旧文件保留。',
        '迁移完成，旧数据仍保留。',
        '请先停止生成任务。',
        '回退旧目录',
        '回退使用迁移前的旧资料；新目录及迁移后的新增资料会保留，但不会自动合并。',
        '取消',
        '确认回退'
      ],
    };
    return (words[language] ?? words['zh-CN']!)[int.parse(key)];
  }

  @override
  void initState() {
    super.initState();
    UnifiedStorage.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object e) {
      if (mounted) setState(() => message = '$e');
    });
  }

  Future<void> migrate() async {
    final app = context.read<AppState>();
    if (app.busy || app.generationQueueRunning) {
      setState(() => message = text('8'));
      return;
    }
    if (!await StoragePermission.hasAllFilesAccess()) {
      await StoragePermission.requestAllFilesAccess();
      if (mounted) setState(() => message = text('5'));
      return;
    }
    setState(() {
      busy = true;
      message = text('6');
    });
    try {
      await UnifiedStorage.migrate(progress: (s) {
        if (mounted) setState(() => message = s);
      });
      app.storage.resetDataCaches();
      await app.load();
      if (mounted) setState(() => message = text('7'));
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> rollback() async {
    final app = context.read<AppState>();
    if (app.busy || app.generationQueueRunning) {
      setState(() => message = text('8'));
      return;
    }
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(text('9')),
                content: Text(text('10')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(text('11'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(text('12')))
                ]));
    if (yes != true) return;
    setState(() => busy = true);
    try {
      await UnifiedStorage.rollback();
      app.storage.resetDataCaches();
      await app.load();
      if (mounted) setState(() => message = text('4'));
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    if (!Platform.isAndroid) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(text('0'), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Text(text('1')),
      const SizedBox(height: 8),
      SelectableText(UnifiedStorage.active?.path ??
          UnifiedStorage.candidate ??
          '/storage/emulated/0/LangbaiStudio/'),
      Text(UnifiedStorage.active == null ? text('4') : text('3')),
      if (busy) const LinearProgressIndicator(),
      if (message.isNotEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(message)),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (UnifiedStorage.active == null)
          FilledButton.icon(
              onPressed: busy ? null : migrate,
              icon: const Icon(Icons.drive_file_move_outline),
              label: Text(text('2')))
        else
          OutlinedButton(
              onPressed: busy ? null : rollback, child: Text(text('9')))
      ]),
    ]);
  }
}
