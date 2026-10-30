import 'screens/novelai_accounts_screen.dart';
import 'screens/style_library_screen.dart';
import 'i18n/style_library_text.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n/app_locales.dart';
import 'models/nai_models.dart';
import 'screens/gallery_screen.dart';
import 'screens/local_favorites_screen.dart';
import 'i18n/local_favorites_text.dart';
import 'screens/ai_log_screen.dart';
import 'screens/data_backup_settings.dart';
import 'screens/generate_screen.dart';
import 'screens/inspect_screen.dart';
import 'screens/metadata_inspector_screen.dart';
import 'screens/online_gallery_screen.dart';
import 'screens/tools_hub_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tools_screen.dart';
import 'state/app_state.dart';
import 'services/background_queue_service.dart';
import 'ui/onboarding.dart';
import 'ui/studio_shell.dart';
import 'ui/studio_theme.dart';
import 'ui/global_typography.dart';
import 'services/ui_fonts.dart';
import 'models/ui_typography.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    FlutterForegroundTask.initCommunicationPort();
  }
  BackgroundQueueService.initialize();
  runApp(ChangeNotifierProvider(
      create: (_) => AppState()..load(), child: const NovelAIApp()));
}

class NovelAIApp extends StatelessWidget {
  const NovelAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    final typography=context.select<AppState,UiTypography>((s)=>s.effectiveUiTypography);
    final family=uiFontFamily(typography.font);
    final theme = context.select<AppState, String>((s) => s.settings.theme);
    final reduceMotion =
        context.select<AppState, bool>((s) => s.settings.reduceMotion);
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: withUiFont(StudioTheme.light(),family),
      darkTheme: withUiFont(StudioTheme.dark(),family),
      themeMode: switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: StudioTextScaler(MediaQuery.textScalerOf(context),typography.scale/100),
              disableAnimations: reduceMotion ||
                  MediaQuery.disableAnimationsOf(context)),
          child: UiTypographyScope(family:family, child: Theme(
              data: withUiTextLayout(Theme.of(context),StudioTextScaler(MediaQuery.textScalerOf(context),typography.scale/100)).copyWith(
                  expansionTileTheme: Theme.of(context)
                      .expansionTileTheme
                      .copyWith(
                          expansionAnimationStyle: reduceMotion ||
                                  MediaQuery.disableAnimationsOf(context)
                              ? AnimationStyle.noAnimation
                              : AppMotion.disclosureStyle)),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: child ?? const SizedBox.shrink(),
              )))),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _navigationOrderKey = 'mobile_navigation_order_v2';
  // Orders saved while page 9 was the removed image agent.
  static const _legacyNavigationOrderKey = 'mobile_navigation_order_v1';
  static const _incomingBackupChannel =
      MethodChannel('langbai.novelai/incoming_backup');
  static const _incomingBackupPending = '__incoming_backup_pending__';

  int _index = 0;
  List<int>? _navigationOrder;
  bool _onboardingScheduled = false;
  bool _v5NoticeScheduled = false;
  bool _incomingBackupInitialChecked = !Platform.isAndroid && !Platform.isIOS;
  bool _incomingBackupRouteScheduled = false;
  final List<String> _pendingIncomingBackups = [];
  final Set<String> _handledIncomingBackups = {};
  late final List<Widget> _pages;

  static const _destinationIcons = [
    (icon: Icons.auto_awesome_outlined, selectedIcon: Icons.auto_awesome),
    (icon: Icons.brush_outlined, selectedIcon: Icons.brush),
    (icon: Icons.tune_outlined, selectedIcon: Icons.tune),
    (icon: Icons.visibility_outlined, selectedIcon: Icons.visibility),
    (icon: Icons.translate_outlined, selectedIcon: Icons.translate),
    (icon: Icons.data_object_outlined, selectedIcon: Icons.data_object),
    (icon: Icons.widgets_outlined, selectedIcon: Icons.widgets),
    (
      icon: Icons.collections_bookmark_outlined,
      selectedIcon: Icons.collections_bookmark
    ),
    (icon: Icons.public_outlined, selectedIcon: Icons.public),
    (icon: Icons.photo_library_outlined, selectedIcon: Icons.photo_library),
    (icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings),
    (icon: Icons.palette_outlined, selectedIcon: Icons.palette),
    (icon: Icons.star_border, selectedIcon: Icons.star),
  ];

  @override
  void initState() {
    super.initState();
    _loadNavigationOrder();
    _pages = [
      const SafeArea(bottom: false, child: Column(children: [NovelAiAccountSelector(), Expanded(child: GenerateScreen())])),
      const ToolsScreen(kind: ToolPageKind.inpaint),
      const ToolsScreen(kind: ToolPageKind.postprocess),
      const InspectScreen(kind: InspectPageKind.reverse),
      const InspectScreen(kind: InspectPageKind.convert),
      MetadataInspectorScreen(
        onBack: () {
          if (mounted) setState(() => _index = 0);
        },
        onOpenGenerate: () {
          if (mounted) setState(() => _index = 0);
        },
      ),
      const ToolsHubScreen(),
      const Scaffold(
        body: SafeArea(
          child: ReferencePresetLibraryPanel(
            standalone: true,
            showClose: false,
          ),
        ),
      ),
      const OnlineGalleryScreen(),
      GalleryScreen(
        onOpenMetadata: () {
          if (mounted) setState(() => _index = 5);
        },
      ),
      const AiLogScreen(),
      const SettingsScreen(),
      StyleLibraryScreen(onApply: () {
        if (mounted) setState(() => _index = 0);
      }),
      const LocalFavoritesScreen(),
    ];
    _initializeIncomingBackupChannel();
  }

  Future<void> _loadNavigationOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_navigationOrderKey) ??
          _withoutImageAgentPage(
              prefs.getStringList(_legacyNavigationOrderKey));
      if (raw == null) return;
      final saved = raw.map(int.tryParse).toList();
      if (saved.any((index) => index == null)) return;
      if (mounted) {
        setState(() => _navigationOrder =
            StudioAdaptiveShell.normalizeDestinationOrder(saved.cast<int>(), _destinationIcons.length));
      }
    } catch (_) {
      // Navigation remains usable in its default order if preferences fail.
    }
  }

  // Drops the removed image agent page from an order saved by an earlier
  // version; the pages after it moved up by one.
  static List<String>? _withoutImageAgentPage(List<String>? legacy) => legacy
      ?.where((value) => value != '9')
      .map((value) {
        final index = int.tryParse(value);
        return index != null && index > 9 ? '${index - 1}' : value;
      })
      .toList();

  Future<void> _saveNavigationOrder(List<int> order) async {
    try {
      final next = StudioAdaptiveShell.normalizeDestinationOrder(order, _destinationIcons.length);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setStringList(_navigationOrderKey, next.map((n) => '$n').toList())) {
        throw StateError('Could not save navigation order');
      }
      if (mounted) setState(() => _navigationOrder = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法保存导航排序')));
      }
    }
  }

  @override
  void dispose() {
    _incomingBackupChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _initializeIncomingBackupChannel() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _incomingBackupChannel.setMethodCallHandler((call) async {
      if (call.method == 'backupReceived') {
        if (mounted && !_incomingBackupInitialChecked) {
          setState(() => _incomingBackupInitialChecked = true);
        }
        _queueIncomingBackup(call.arguments);
      } else if (call.method == 'backupReceiveFinished' && mounted) {
        setState(() => _incomingBackupInitialChecked = true);
      }
    });
    var waitingForNativeCopy = false;
    try {
      final initial = await _incomingBackupChannel
          .invokeMethod<Object?>('takeInitialBackup');
      waitingForNativeCopy = initial?.toString() == _incomingBackupPending;
      if (!waitingForNativeCopy) _queueIncomingBackup(initial);
    } on MissingPluginException {
      // Native file association is unavailable on unsupported build targets.
    } on PlatformException {
      // The normal in-app file picker remains available if native delivery
      // fails on a vendor-specific Android/iOS build.
    } finally {
      if (mounted && !waitingForNativeCopy) {
        setState(() => _incomingBackupInitialChecked = true);
        _scheduleIncomingBackupRoute();
      }
    }
  }

  void _queueIncomingBackup(Object? rawPath) {
    final path = rawPath?.toString().trim() ?? '';
    if (!mounted || path.isEmpty || _handledIncomingBackups.contains(path)) {
      return;
    }
    if (!_pendingIncomingBackups.contains(path)) {
      setState(() => _pendingIncomingBackups.add(path));
    }
    _scheduleIncomingBackupRoute();
  }

  void _scheduleIncomingBackupRoute() {
    if (!mounted ||
        _incomingBackupRouteScheduled ||
        _pendingIncomingBackups.isEmpty) {
      return;
    }
    if (!context.read<AppState>().booted) return;
    _incomingBackupRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _pendingIncomingBackups.isEmpty) {
        _incomingBackupRouteScheduled = false;
        return;
      }
      final path = _pendingIncomingBackups.removeAt(0);
      _handledIncomingBackups.add(path);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => IncomingBackupImportScreen(filePath: path),
        ),
      );
      try {
        final cachedCopy = File(path);
        if (await cachedCopy.exists()) await cachedCopy.delete();
      } catch (_) {
        // Cache cleanup is best-effort and never affects an already completed
        // import or the original document owned by the sharing application.
      }
      if (!mounted) return;
      setState(() => _incomingBackupRouteScheduled = false);
      _scheduleIncomingBackupRoute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final booted = context.select<AppState, bool>((s) => s.booted);
    if (!booted) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _scheduleIncomingBackupRoute();
    final language =
        context.select<AppState, String>((s) => s.settings.language);
    if (!_incomingBackupInitialChecked) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在读取分享的备份文件…'),
              ],
            ),
          ),
        ),
      );
    }
    final labels = [
      ...mainDestinationLabelsFor(language),
      styleLibraryText(language)['title']!,
      localFavoritesLabelFor(language)
    ];
    final shellText = shellTextFor(language);
    final destinations = [
      for (var i = 0; i < _destinationIcons.length; i++)
        StudioDestination(
          label: labels[i],
          icon: _destinationIcons[i].icon,
          selectedIcon: _destinationIcons[i].selectedIcon,
        ),
    ];
    final needsOnboarding =
        context.select<AppState, bool>((s) => s.needsNetworkOnboarding);
    final handlingIncomingBackup = !_incomingBackupInitialChecked ||
        _incomingBackupRouteScheduled ||
        _pendingIncomingBackups.isNotEmpty;
    if (!handlingIncomingBackup && needsOnboarding && !_onboardingScheduled) {
      _onboardingScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showNetworkOnboarding();
      });
    }
    final currentModelIsV5 =
        context.select<AppState, bool>((s) => s.params.isV5);
    if (!handlingIncomingBackup &&
        !needsOnboarding &&
        !currentModelIsV5 &&
        !_v5NoticeScheduled) {
      _v5NoticeScheduled = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showV5MigrationNotice());
    }
    return StudioAdaptiveShell(
      selectedIndex: _index,
      onDestinationSelected: (index) {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _index = index);
      },
      destinations: destinations,
      pages: _pages,
      moreLabel: shellText.moreLabel,
      allFeaturesLabel: shellText.allFeatures,
      destinationOrder: _navigationOrder,
      onDestinationOrderChanged: _saveNavigationOrder,
    );
  }

  Future<void> _showNetworkOnboarding() async {
    final openSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => const Dialog.fullscreen(child: OnboardingFlow()),
    );
    if (!mounted) return;
    await context.read<AppState>().dismissNetworkOnboarding();
    if (openSettings == true && mounted) setState(() => _index = 11);
  }

  Future<void> _showV5MigrationNotice() async {
    const key = 'langbai.notice.v5-model-migration.seen';
    const legacyKey = 'langbai.notice.v5-model-migration.v2';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) == true ||
          prefs.getBool(legacyKey) == true ||
          !mounted) {
        if (prefs.getBool(legacyKey) == true) await prefs.setBool(key, true);
        return;
      }
      // Persist before opening the dialog so force-closing the app while the
      // reminder is visible still counts as the one allowed presentation.
      await prefs.setBool(key, true);
      if (!mounted) return;
      const copy = _v5MigrationCopy;
      final openGenerate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.auto_awesome),
          title: Text(copy.title),
          content: Text(copy.body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(copy.keep)),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(copy.go)),
          ],
        ),
      );
      if (openGenerate == true && mounted) setState(() => _index = 0);
    } catch (_) {
      // A preference backend may be unavailable in isolated widget tests.
    }
  }
}

const _v5MigrationCopy = (
  title: 'NovelAI V5 Full 已上线',
  body:
      '为避免改变旧项目的复现结果，升级软件不会强制覆盖已经保存的模型。旧用户如仍显示 V4 / V4.5，请在生成页的模型列表中手动选择 NAI Diffusion V5 Full；新建默认配置已经使用 V5 Full。\n\nV5 的训练分布不同，V4 / V4.5 时期的画师标签或画师串可能弱化、失效或呈现不同效果。需要复现旧结果时请保留旧模型，并在切换后重新测试画师串。',
  keep: '保持当前模型',
  go: '前往模型选择'
);
