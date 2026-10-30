import '../ui/global_typography.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_locales.dart';
import '../state/app_state.dart';
import '../ui/studio_theme.dart';
import 'batch_redraw_screen.dart';
import 'comic_screen.dart';
import 'random_artist_lab_screen.dart';
import 'prompt_codex_screen.dart';
import 'v5_artist_weight_repair_screen.dart';

({String title, String subtitle}) _promptCodexTileText(String language) {
  return (
    title: '所长 NovelAI 个人法典',
    subtitle: '三套法典离线收录、原章节与统一分类检索、提示词一键复制，并可手动更新'
  );
}

class ToolsHubScreen extends StatelessWidget {
  const ToolsHubScreen({super.key});

  Future<void> _openTool(
    BuildContext context,
    Widget Function(VoidCallback onBack) buildTool,
  ) {
    return Navigator.of(context).push<void>(
      _StudioToolRoute<void>(
        builder: (routeContext) => buildTool(
          () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language =
        context.select<AppState, String>((s) => s.settings.language);
    final text = mobileToolsHubTextFor(language);
    final promptCodexText = _promptCodexTileText(language);
    return Scaffold(
      appBar: AppBar(title: studioAppBarTitle(context, Text(text.title))),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(StudioSpacing.lg),
        children: [
          _ToolTile(
            icon: Icons.auto_stories_outlined,
            title: text.comicTitle,
            subtitle: text.comicSubtitle,
            onTap: () => _openTool(
              context,
              (onBack) => ComicScreen(onBack: onBack),
            ),
          ),
          const SizedBox(height: StudioSpacing.md),
          _ToolTile(
            icon: Icons.collections_outlined,
            title: text.batchTitle,
            subtitle: text.batchSubtitle,
            onTap: () => _openTool(
              context,
              (onBack) => BatchRedrawScreen(onBack: onBack),
            ),
          ),
          const SizedBox(height: StudioSpacing.md),
          _ToolTile(
            icon: Icons.casino_outlined,
            title: text.artistLabTitle,
            subtitle: text.artistLabSubtitle,
            onTap: () => _openTool(
              context,
              (onBack) => RandomArtistLabScreen(onBack: onBack),
            ),
          ),
          const SizedBox(height: StudioSpacing.md),
          _ToolTile(
            icon: Icons.auto_fix_high_outlined,
            title: 'V4.5 画师串修复器',
            subtitle: '把每个 V4.5 画师权重独立压到原值的 1/3～1/2，并规范为 V5 数值格式',
            onTap: () => _openTool(
              context,
              (onBack) => V5ArtistWeightRepairScreen(onBack: onBack),
            ),
          ),
          const SizedBox(height: StudioSpacing.md),
          _ToolTile(
            icon: Icons.tune_outlined,
            title: '输入画师串抽卡',
            subtitle: '粘贴完整画师串，保留全部 Tag，只重抽画师权重，批量生图并收藏',
            onTap: () => _openTool(
              context,
              (onBack) => V5ArtistWeightRepairScreen(
                mode: V5ArtistToolMode.draw,
                onBack: onBack,
              ),
            ),
          ),
          const SizedBox(height: StudioSpacing.md),
          _ToolTile(
            icon: Icons.menu_book_outlined,
            title: promptCodexText.title,
            subtitle: promptCodexText.subtitle,
            onTap: () => _openTool(
              context,
              (onBack) => PromptCodexScreen(onBack: onBack),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioToolRoute<T> extends MaterialPageRoute<T> {
  _StudioToolRoute({required super.builder});

  @override
  Duration get transitionDuration => AppMotion.standard;

  @override
  Duration get reverseTransitionDuration => AppMotion.fast;
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          minVerticalPadding: 18,
          leading: Icon(icon, size: 32),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
