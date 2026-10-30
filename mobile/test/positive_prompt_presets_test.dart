import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/prompts/positive_prompt_presets.dart';

void main() {
  test('positive preset names use prompt text and increment conflicts', () {
    expect(
      defaultPositivePromptPresetName('1girl, cinematic lighting, masterpiece'),
      '1girl, cinematic lighting',
    );
    final presets = [
      PositivePromptPreset(
        id: 'a',
        name: '夜景',
        prompt: 'night',
        createdAt: '',
      ),
      PositivePromptPreset(
        id: 'b',
        name: '夜景 (1)',
        prompt: 'night city',
        createdAt: '',
      ),
    ];
    expect(uniquePositivePromptPresetName(presets, '夜景'), '夜景 (2)');
    expect(
      uniquePositivePromptPresetName(presets, '夜景', excludeId: 'a'),
      '夜景',
    );
    expect(positivePromptPresetStorageId('abc'), 'positive-prompt-abc');
  });

  test('tags are stored in the desktop shape and omitted when empty', () {
    final tagged = PositivePromptPreset(
        id: 'p', name: 'Night', prompt: 'night', createdAt: 'now',
        tags: [' 夜景 ', '#夜景', 'City']);
    expect(tagged.tags, ['夜景', 'City']);
    expect(tagged.toJson()['tags'], ['夜景', 'City']);
    expect(PositivePromptPreset.fromJson(tagged.toJson()).tags, ['夜景', 'City']);
    expect(PositivePromptPreset.fromJson({...tagged.toJson(), 'tags': '服装, 角色'})
        .tags, ['服装', '角色']);
    final plain =
        PositivePromptPreset(id: 'q', name: 'Plain', prompt: 'x', createdAt: '');
    expect(plain.toJson().containsKey('tags'), isFalse);
    expect(
        PositivePromptPreset.fromJson({...plain.toJson(), 'tags': <String>[]})
            .toJson()
            .containsKey('tags'),
        isFalse);
  });

  // Mirrors "applying positive prompt presets" in the desktop app's
  // src/positive-prompt-presets.test.ts.
  group('applying positive prompt presets', () {
    CharCaptionItem caption(String prompt, [String negativePrompt = '']) =>
        CharCaptionItem(prompt: prompt, negativePrompt: negativePrompt);
    PositivePromptPreset preset(String prompt,
            [List<CharCaptionItem> captions = const []]) =>
        PositivePromptPreset(
            id: 'p', name: 'P', prompt: prompt, createdAt: '', captions: captions);
    final existing = caption('existing');
    PositivePresetApplication apply(
      PositivePromptPreset preset,
      PositivePresetApplyMode mode, {
      String value = '1girl, 1.2::blue hair::',
      CharCaptionItem? character,
    }) =>
        resolvePositivePresetApplication(preset, mode,
            value: value,
            character: character,
            currentCaptions: [existing],
            maxCharacters: 2);
    List<String> prompts(PositivePresetApplication result) =>
        (result as PositivePresetCharacters).captions.map((c) => c.prompt).toList();

    test('replaces or appends plain prompt text without rewriting weights', () {
      final plain = preset('smile, 0.8::frown::');
      final replaced = apply(plain, PositivePresetApplyMode.replace)
          as PositivePresetPrompt;
      expect(replaced.prompt, 'smile, 0.8::frown::');
      expect(replaced.appended, isFalse);
      final appended =
          apply(plain, PositivePresetApplyMode.append) as PositivePresetPrompt;
      expect(appended.prompt, '1girl, 1.2::blue hair::, smile, 0.8::frown::');
      expect(appended.appended, isTrue);
      expect(
          (apply(plain, PositivePresetApplyMode.append, value: '')
                  as PositivePresetPrompt)
              .prompt,
          'smile, 0.8::frown::');
    });

    test('replaces characters or adds them after the existing ones within the model limit',
        () {
      final one = preset('', [caption('saved')]);
      final replaced = apply(one, PositivePresetApplyMode.replace)
          as PositivePresetCharacters;
      expect(prompts(replaced), ['saved']);
      expect((replaced.appended, replaced.row), (false, false));
      final appended = apply(one, PositivePresetApplyMode.append)
          as PositivePresetCharacters;
      expect(prompts(appended), ['existing', 'saved']);
      expect((appended.appended, appended.row), (true, false));
      // Existing characters keep their identity; saved ones are copies.
      expect(appended.captions.first, same(existing));
      expect(appended.captions.last, isNot(same(one.captions.single)));
      final two = preset('', [caption('a'), caption('b')]);
      expect(apply(two, PositivePresetApplyMode.replace),
          isA<PositivePresetCharacters>());
      expect(apply(two, PositivePresetApplyMode.append),
          isA<PositivePresetOverCapacity>());
    });

    test('appends one saved character into the character row being edited',
        () {
      final row = CharCaptionItem(
          name: 'Row', prompt: 'red coat', negativePrompt: 'hat',
          useCoords: true, x: 0.2, y: 0.8);
      final result = apply(preset('', [caption('smile', 'blur')]),
          PositivePresetApplyMode.append,
          value: 'red coat', character: row) as PositivePresetCharacters;
      expect((result.appended, result.row), (true, true));
      expect(result.captions.single.toJson(), {
        ...row.toJson(),
        'prompt': 'red coat, smile',
        'negativePrompt': 'hat, blur',
      });
      expect(row.prompt, 'red coat');
      final plain = apply(preset('smile'), PositivePresetApplyMode.append,
          value: 'red coat', character: row) as PositivePresetPrompt;
      expect(plain.prompt, 'red coat, smile');
      expect(plain.appended, isTrue);
    });
  });
}
