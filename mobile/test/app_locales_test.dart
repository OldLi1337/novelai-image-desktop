import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/i18n/app_locales.dart';
import 'package:novelai_mobile/prompts/capsule_data.dart';

void main() {
  test('NovelAI billing uses API Token without renaming separate AI API Keys', () {
    expect(generateScreenTextFor('zh-CN').configureToken,
        contains('NovelAI API Token'));
    final detail = settingsDetailTextFor('zh-CN');
    expect(detail.visionApiKey, contains('API Key'));
    expect(detail.textApiKey, contains('API Key'));
  });

  test('every stored language code resolves to Simplified Chinese', () {
    for (final code in ['zh-CN', 'zh-TW', 'en-US', 'ja-JP', 'ko-KR', 'fr-FR']) {
      expect(normalizeAppLocaleCode(code), 'zh-CN');
    }
    expect(normalizeAppLocaleCode(null), 'zh-CN');
  });

  test('provides complete navigation and settings labels', () {
    expect(mainDestinationLabelsFor('zh-CN'), hasLength(12));
    for (final label in mainDestinationLabelsFor('zh-CN')) {
      expect(label.trim(), isNotEmpty);
    }
    expect(shellTextFor('zh-CN').moreLabel.trim(), isNotEmpty);
    expect(shellTextFor('zh-CN').allFeatures.trim(), isNotEmpty);
    final appearance = settingsAppearanceTextFor('zh-CN');
    final settings = settingsScreenTextFor('zh-CN');
    final detail = settingsDetailTextFor('zh-CN');
    final tokenGuide = tokenGuideTextFor('zh-CN');
    final toolsHub = mobileToolsHubTextFor('zh-CN');
    final generate = generateScreenTextFor('zh-CN');
    for (final value in [
      tokenGuide.title,
      tokenGuide.close,
      tokenGuide.subtitle,
      tokenGuide.securityTitle,
      tokenGuide.securitySubtitle,
      tokenGuide.openNovelAi,
      toolsHub.title,
      toolsHub.comicTitle,
      toolsHub.comicSubtitle,
      toolsHub.batchTitle,
      toolsHub.batchSubtitle,
      settings.title,
      settings.accountConfigured,
      settings.accountUnconfigured,
      settings.verified,
      settings.anlas,
      settings.unknown,
      settings.networkSection,
      settings.novelAiSection,
      settings.reverseSection,
      settings.convertSection,
      settings.tagSection,
      settings.translateSection,
      settings.promptTemplatesSection,
      settings.promptShortcutsSection,
      settings.storageSection,
      appearance.sectionTitle,
      appearance.themeLabel,
      appearance.themeSystem,
      appearance.themeLight,
      appearance.themeDark,
      appearance.tagAutocomplete,
      appearance.lockStyleTitle,
      appearance.lockStyleSubtitle,
      appearance.lockNegativeTitle,
      appearance.lockNegativeSubtitle,
      appearance.secureTitle,
      appearance.secureSubtitle,
      appearance.appInfoSubtitle,
      detail.tokenVerifiedSuccess,
      detail.connectionFailed,
      detail.networkSystemVpnTitle,
      detail.networkSystemVpnSubtitle,
      detail.networkTesting,
      detail.networkTest,
      detail.allowCustomEndpointTitle,
      detail.allowCustomEndpointSubtitle,
      detail.verifying,
      detail.verifyAndSaveToken,
      detail.howToGetToken,
      detail.clearToken,
      detail.visionApiUrl,
      detail.visionModel,
      detail.visionApiKey,
      detail.textApiUrl,
      detail.textModel,
      detail.textApiKey,
      detail.saveKey,
      detail.detectModel,
      detail.modelDetection,
      detail.noModelList,
      detail.tagRemoteTitle,
      detail.tagRemoteSubtitle,
      detail.tagLibraryTitle,
      detail.downloadedTagsPrefix,
      detail.downloadedTagsSuffix,
      detail.tagLibraryNotDownloaded,
      detail.downloadBusy,
      detail.download,
      detail.tagDataNotice,
      detail.tagMcpUrl,
      detail.serviceType,
      detail.mcpToolName,
      detail.tagServiceKey,
      detail.saveTagKey,
      detail.testTagMcp,
      detail.mcpCapsuleTitle,
      detail.mcpCapsuleSubtitle,
      detail.mcpConvertTitle,
      detail.mcpReverseTitle,
      detail.translateProvider,
      detail.googleTranslate,
      detail.baiduTranslate,
      detail.baiduAppId,
      detail.baiduSecret,
      detail.baiduSecretSaved,
      detail.saveBaiduSecret,
      detail.reverseTemplateTitle,
      detail.convertTemplateTitle,
      detail.comicTemplateTitle,
      detail.restoreTemplateNote,
      detail.promptShortcutEmpty,
      detail.delete,
      detail.newShortcut,
      detail.historyRetention,
      detail.days30,
      detail.days90,
      detail.oneYear,
      detail.longRetention,
      detail.daysSuffix,
      detail.imageNameTemplate,
      detail.imageNameVars,
      detail.keepMetadataTitle,
      detail.keepMetadataSubtitle,
      detail.saveToGalleryTitle,
      detail.saveToGallerySubtitle,
      detail.customized,
      detail.builtInTemplate,
      detail.resetDefault,
      detail.cancel,
      detail.save,
      detail.newShortcutTitle,
      detail.shortcutName,
      detail.shortcutPrefix,
      detail.shortcutSuffix,
      detail.shortcutNegative,
      detail.imageOutputPath,
      detail.defaultImageDir,
      detail.imagePathHint,
      detail.chooseFolder,
      detail.chooseImageFolderDialog,
      detail.restoreDefault,
      detail.fileAccessTitle,
      detail.fileAccessContent,
      detail.later,
      detail.authorize,
      generate.titleTextToImage,
      generate.titleImageLoaded,
      generate.notConfigured,
      generate.ready,
      generate.stylePrompt,
      generate.positivePrompt,
      generate.negativePrompt,
      generate.translateBusy,
      generate.translate,
      generate.undoTranslation,
      generate.normalize,
      generate.weight,
      generate.randomPreview,
      generate.relatedTag,
      generate.unlockPrompt,
      generate.lockPrompt,
      generate.promptShortcuts,
      generate.previewEmpty,
      generate.loadImage,
      generate.switchToTextToImage,
      generate.tagSearchLabel,
      generate.tagSearchHint,
      generate.browseCategories,
      generate.downloadBusy,
      generate.downloadChineseTags,
      generate.tagsReadyPrefix,
      generate.tagsReadySuffix,
      generate.offlineTagHint,
      generate.capsuleLoadFailed,
      generate.inspirationCapsules,
      generate.model,
      generate.animeMode,
      generate.furryMode,
      generate.width,
      generate.height,
      generate.sampler,
      generate.noiseSchedule,
      generate.ucPreset,
      generate.randomSeed,
      generate.fixedSeed,
      generate.fixedSeedTooltip,
      generate.batch,
      generate.qualityToggle,
      generate.variety,
      generate.i2iParams,
      generate.strength,
      generate.noise,
      generate.extraNoiseSeed,
      generate.output,
      generate.imagePrefix,
      generate.historyGroup,
      generate.ungrouped,
      generate.quoting,
      generate.addToQueue,
      generate.waiting,
      generate.resume,
      generate.pause,
      generate.cancelAndClear,
      generate.generateImage,
      generate.generateCountPrefix,
      generate.generateCountSuffix,
      generate.useCurrentImage,
      generate.officialQuote,
      generate.formulaQuote,
      generate.pendingQuote,
      generate.precharge,
      generate.reading,
      generate.configureToken,
      generate.balance,
      generate.unknown,
      generate.queue,
      generate.running,
      generate.queued,
      generate.clearPending,
      generate.expandQueue,
      generate.collapseQueue,
      generate.pauseAfterCurrent,
      generate.runningCurrent,
      generate.batchPendingPrefix,
      generate.batchPendingSuffix,
      generate.removeFromQueue,
    ]) {
      expect(value.trim(), isNotEmpty);
    }
    expect(tokenGuide.steps, hasLength(3));
    for (final step in tokenGuide.steps) {
      expect(step.title.trim(), isNotEmpty);
      expect(step.description.trim(), isNotEmpty);
    }
  });

  test('capsule tags show their Chinese labels in every stored language', () {
    final raw = jsonDecode(
      File('assets/capsule_taxonomy.json').readAsStringSync(),
    ) as List<dynamic>;
    var count = 0;
    for (final category in raw.cast<Map<String, dynamic>>()) {
      for (final subgroup
          in (category['subgroups'] as List<dynamic>).cast<Map>()) {
        for (final tag in (subgroup['tags'] as List<dynamic>).cast<Map>()) {
          final en = tag['en'].toString();
          final zh = tag['zh'].toString().trim();
          count += 1;
          final label = localizedTagLabel('en-US', en, sourceLabel: zh);
          expect(label.trim(), isNotEmpty);
          if (zh.isNotEmpty) expect(label, zh);
        }
      }
    }
    expect(count, greaterThan(4000));
    expect(localizedTagLabel('ja-JP', 'long_hair'), '长发');
  });
}
