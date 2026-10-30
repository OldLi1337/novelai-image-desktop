import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/tavern/lyra_preset_data.dart';
import 'package:novelai_mobile/tavern/tavern_models.dart';
import 'package:novelai_mobile/prompts/dsh_image_ai.dart';
import 'package:novelai_mobile/prompts/ig5_image_prompts.dart';

void main() {
  group('built-in DSH image AI adapter', () {
    test('supports exactly the two scoped image tasks', () {
      expect(DshImageAiTask.values,
          [DshImageAiTask.reverse, DshImageAiTask.convert]);
      expect(buildDshImageAiSystemAddon(DshImageAiTask.reverse),
          contains('Inspect the supplied image directly'));
      expect(buildDshImageAiSystemAddon(DshImageAiTask.convert),
          contains('Convert the supplied description directly'));
    });

    test('disabled mode preserves the original system prompt', () {
      expect(
        injectDshImageAiSystemPrompt(
          task: DshImageAiTask.reverse,
          systemPrompt: 'BASE',
          enabled: false,
        ),
        'BASE',
      );
    });

    test('settings persist and normalize the mode', () {
      final strict = AppSettings.fromJson({
        'reverseConvertDshEnabled': false,
        'reverseConvertDshMode': 'strict',
      });
      expect(strict.reverseConvertDshEnabled, isFalse);
      expect(strict.reverseConvertDshMode, 'strict');
      expect(strict.toJson()['reverseConvertDshMode'], 'strict');

      final defaults = AppSettings.fromJson({});
      expect(defaults.reverseConvertDshEnabled, isTrue);
      expect(defaults.reverseConvertDshMode, 'focused');
    });

    test(
        'fresh scoped defaults are the shared IG5 adaptations; Lyra remains explicit legacy',
        () {
      for (final task in DshImageAiTask.values) {
        final value = buildDshImageAiSystemAddon(task);
        expect(value, contains(ig5PromptBodies[task.name]!));
        expect(value, isNot(contains(lyraPresetSystemPrompt)));
      }
      expect(lyraImageTaskSourceSha256,
          '09D89AE4F64E05C06962786BB19A8C7364898E863DCC3FCDE99F661E841EF6A9');
    });

    test('does not duplicate a shared preset already in the system prompt',
        () {
      final value = injectDshImageAiSystemPrompt(
        task: DshImageAiTask.reverse,
        systemPrompt: ig5PromptBodies['reverse']!,
      );
      expect(value.split(ig5PromptBodies['reverse']!), hasLength(2));
      expect(value, contains('Inspect the supplied image directly'));
    });

    test('uses a selected custom preset for reverse and conversion', () {
      final preset = TavernSamplerPreset(
        id: 'custom-preset',
        name: 'Custom preset',
        systemPrompt: 'CUSTOM_SYSTEM_PROMPT',
        jailbreakPrompt: 'CUSTOM_JAILBREAK_PROMPT',
      );
      for (final task in [DshImageAiTask.reverse, DshImageAiTask.convert]) {
        final value = injectDshImageAiSystemPrompt(
          task: task,
          systemPrompt: 'BASE',
          sharedPreset: preset,
          useDefaultSharedPreset: false,
        );
        expect(value, contains('Shared SillyTavern preset · Custom preset'));
        expect(value, contains('CUSTOM_SYSTEM_PROMPT'));
        expect(value, contains('CUSTOM_JAILBREAK_PROMPT'));
        expect(value, isNot(contains(lyraPresetSystemPrompt)));
      }
    });

    test('settings persist an empty or selected shared preset library', () {
      final custom = TavernSamplerPreset(
        id: 'custom',
        name: 'Custom',
        systemPrompt: 'SYSTEM',
        jailbreakPrompt: 'JAILBREAK',
      );
      final restored = AppSettings.fromJson(AppSettings(
        reverseConvertPromptPresets: [custom],
        reverseConvertPromptPresetId: custom.id,
      ).toJson());
      expect(
          restored.reverseConvertPromptPresets
              .firstWhere((p) => p.id == 'custom')
              .name,
          'Custom');
      expect(restored.reverseConvertPromptPresetId, 'custom');

      final empty = AppSettings.fromJson({
        'reverseConvertPromptPresets': <Object>[],
        'reverseConvertPromptPresetId': '',
      });
      expect(empty.reverseConvertPromptPresets, isEmpty);
    });
  });
}
