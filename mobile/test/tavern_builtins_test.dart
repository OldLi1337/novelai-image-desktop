import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/prompts/ig5_image_prompts.dart';
import 'package:novelai_mobile/tavern/tavern_builtins.dart';

void main() {
  test('fresh reverse and conversion presets offer Lyra as an explicit choice',
      () {
    expect(defaultImageSystemPresets().map((item) => item.id), [
      'builtin-ig5-convert',
      'builtin-ig5-reverse',
      lyraImageSamplerId,
    ]);
    final settings = AppSettings();
    expect(settings.reverseConvertPromptPresets.map((item) => item.id),
        contains(lyraImageSamplerId));
    expect(settings.convertSystemPromptPresetId, 'builtin-ig5-convert');
    expect(settings.reverseSystemPromptPresetId, 'builtin-ig5-reverse');
  });

  test('renamed or deleted built-in presets stay persisted', () {
    final renamed = createLyraImageSamplerPreset()..name = '我的图像预设';
    final restored = AppSettings.fromJson(
        AppSettings(reverseConvertPromptPresets: [renamed]).toJson());
    expect(
        restored.reverseConvertPromptPresets
            .singleWhere((item) => item.id == lyraImageSamplerId)
            .name,
        '我的图像预设');

    final deleted = AppSettings.fromJson(AppSettings(
        reverseConvertPromptPresets: [
          createIg5ImageSamplerPreset('convert')
        ]).toJson());
    expect(deleted.reverseConvertPromptPresets.map((item) => item.id),
        isNot(contains(lyraImageSamplerId)));
  });
}
