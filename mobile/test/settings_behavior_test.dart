import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/services/nai_api.dart';
import 'package:novelai_mobile/services/proxy_http_client.dart';

void main() {
  group('settings migration and safety', () {
    test('legacy Tag URL enables the remote service during migration', () {
      final settings = AppSettings.fromJson({
        'tagServerUrl': 'http://127.0.0.1:3000/mcp',
      });
      expect(settings.tagServerEnabled, isTrue);
    });

    test('settings round-trip preserves mobile parity options', () {
      final source = AppSettings(
        allowCustomEndpoint: true,
        theme: 'dark',
        proxyForNai: false,
        translateProvider: 'baidu',
        baiduAppId: 'example-id',
        historyRetentionDays: 90,
        keepImageMetadata: false,
        saveToGallery: false,
        imageNameTemplate: '{date}_{seed}_{type}',
        generationGroupId: 'generation-group',
        promptShortcuts: [
          PromptShortcutTemplate(
            id: '1',
            name: '测试',
            prefix: 'masterpiece',
          ),
        ],
      );
      final restored = AppSettings.fromJson(source.toJson());

      expect(restored.allowCustomEndpoint, isTrue);
      expect(restored.theme, 'dark');
      expect(restored.proxyForNai, isFalse);
      expect(restored.translateProvider, 'baidu');
      expect(restored.historyRetentionDays, 90);
      expect(restored.keepImageMetadata, isFalse);
      expect(restored.saveToGallery, isFalse);
      expect(restored.generationGroupId, 'generation-group');
      expect(restored.promptShortcuts.single.name, '测试');
    });

    test('settings saved with removed update, Agent and language options load',
        () {
      final restored = AppSettings.fromJson({
        'theme': 'dark',
        'updateSource': 'gitee',
        'agentApiBaseUrl': 'https://agent.invalid/v1',
        'agentApiModel': 'legacy-agent',
        'language': 'ja-JP',
      });
      expect(restored.theme, 'dark');
      expect(restored.language, 'zh-CN');
      final saved = restored.toJson();
      expect(saved.keys, isNot(contains('updateSource')));
      expect(saved.keys.where((key) => key.startsWith('agent')), isEmpty);
      expect(saved['language'], 'zh-CN');
    });

    test('custom NovelAI endpoints honor explicit opt-out', () {
      const official = 'https://api.novelai.net';
      final settings = AppSettings(allowCustomEndpoint: false);
      expect(
        resolveNovelAiBaseUrl('http://127.0.0.1:9000/', official, settings),
        official,
      );
      expect(
        resolveNovelAiBaseUrl(
          'https://image.novelai.net/',
          'https://image.novelai.net',
          settings,
        ),
        'https://image.novelai.net',
      );
      settings.allowCustomEndpoint = true;
      expect(
        resolveNovelAiBaseUrl('http://127.0.0.1:9000/', official, settings),
        'http://127.0.0.1:9000',
      );
    });

    test('proxy scopes are independent', () {
      final settings = AppSettings(
        proxyForNai: false,
        proxyForMcp: true,
        proxyForAi: false,
        proxyForUpdate: true,
        proxyForTranslate: false,
      );
      expect(proxyEnabledForScope(settings, ProxyScope.nai), isFalse);
      expect(proxyEnabledForScope(settings, ProxyScope.mcp), isTrue);
      expect(proxyEnabledForScope(settings, ProxyScope.ai), isFalse);
      expect(proxyEnabledForScope(settings, ProxyScope.update), isTrue);
      expect(proxyEnabledForScope(settings, ProxyScope.translate), isFalse);
      expect(proxyEnabledForScope(settings, null), isTrue);
    });
  });
}
