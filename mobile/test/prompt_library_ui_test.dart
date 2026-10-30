import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/screens/generate_screen.dart';
import 'package:novelai_mobile/services/storage.dart';
import 'package:novelai_mobile/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The saved-prompt libraries under the prompt fields, with their tag filters.
// Mirrors the desktop app's src/prompt-library-bar.test.tsx and
// src/prompt-library-ui.test.tsx, here with the real Flutter widgets.

const _created = '2026-10-01T00:00:00.000Z';
const _capacity = '预设角色数量超过当前模型上限，请先切换模型。';

AppState _state() {
  final state = AppState()..settings.language = 'zh-CN';
  addTearDown(state.dispose);
  return state;
}

PositivePromptPreset _preset(String id, String name, String prompt,
        {List<String>? tags, List<CharCaptionItem>? captions}) =>
    PositivePromptPreset(
        id: id,
        name: name,
        prompt: prompt,
        tags: tags,
        captions: captions,
        createdAt: _created);

PromptChunk _chunk(String id, String name, String content,
        {List<String>? tags}) =>
    PromptChunk(
        id: id,
        name: name,
        content: content,
        tags: tags,
        createdAt: _created,
        updatedAt: _created);

Map<String, Object> _negative(String id, String name, String prompt,
        {List<String>? tags}) =>
    {
      'id': id,
      'name': name,
      'prompt': prompt,
      if (tags != null) 'tags': tags,
      'createdAt': _created,
    };

/// A prompt field as the generate and inpaint screens build it. [value] holds
/// its text.
Widget _field(ValueNotifier<String> value,
        {bool negative = false, String? characterModel, Key? key}) =>
    ValueListenableBuilder<String>(
      key: key,
      valueListenable: value,
      builder: (context, text, _) => PromptEditor(
        label: negative ? '负面' : '提示词',
        value: text,
        lockKind: negative ? 'negative' : null,
        positiveLibrary: !negative,
        characterModel: characterModel,
        onChanged: (next) => value.value = next,
      ),
    );

Future<void> _pump(WidgetTester tester, AppState state, List<Widget> children,
    {Size size = const Size(1000, 1600), double textScale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    ),
  ));
}

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _button(String label) => find.ancestor(
    of: find.text(label), matching: find.byWidgetPredicate((w) => w is OutlinedButton));
Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The tag filter chips like the desktop test lists them: label, count and
/// '*' for the selected one.
List<String> _chips(WidgetTester tester) => [
      for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)))
        () {
          final row = chip.label as Row;
          final label = (row.children.first as Text).data;
          final count = (row.children.last as Text).data;
          return '$label$count${chip.selected ? '*' : ''}';
        }()
    ];

String _tagInput(WidgetTester tester) =>
    tester.widget<TextField>(_key('prompt-tag-input')).controller!.text;

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(_key(key)).onPressed != null;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('library actions under the prompt fields', () {
    testWidgets(
        'the positive field shows 正面预设, 保存当前 and 自定义提词; 保存当前 needs a prompt',
        (tester) async {
      final prompt = ValueNotifier('1girl');
      await _pump(tester, _state(), [_field(prompt)]);
      for (final label in ['正面预设', '保存当前', '自定义提词']) {
        expect(_button(label), findsOneWidget);
      }
      expect(_enabled(tester, 'positive-library-save-current'), isTrue);
      prompt.value = '  ';
      await tester.pump();
      expect(_enabled(tester, 'positive-library-save-current'), isFalse);
      expect(_enabled(tester, 'positive-library-presets'), isTrue);
      expect(_enabled(tester, 'positive-library-chunks'), isTrue);
      // The negative library is not part of the positive field.
      expect(_key('negative-library-open'), findsNothing);
    });

    testWidgets(
        'the negative field shows 负面提示词库 and 保存当前 instead of the icon button',
        (tester) async {
      final negative = ValueNotifier('lowres');
      await _pump(tester, _state(), [_field(negative, negative: true)]);
      expect(_button('负面提示词库'), findsOneWidget);
      expect(_button('保存当前'), findsOneWidget);
      expect(find.byTooltip('负面提示词库'), findsNothing);
      expect(_key('positive-library-presets'), findsNothing);
      expect(_enabled(tester, 'negative-library-save-current'), isTrue);
      negative.value = '';
      await tester.pump();
      expect(_enabled(tester, 'negative-library-save-current'), isFalse);
    });

    testWidgets(
        'the buttons share one row on a phone, drop their icons when tight and stack for large text',
        (tester) async {
      final prompt = ValueNotifier('1girl');
      const keys = [
        'positive-library-presets',
        'positive-library-save-current',
        'positive-library-chunks'
      ];
      List<Rect> rects() => [for (final key in keys) tester.getRect(_key(key))];
      Finder icons() =>
          find.descendant(of: _key(keys.last), matching: find.byType(Icon));

      await _pump(tester, _state(), [_field(prompt)],
          size: const Size(390, 844));
      var row = rects();
      expect(row.map((rect) => rect.top).toSet(), hasLength(1));
      expect(row[0].width, moreOrLessEquals(row[2].width));
      expect(icons(), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Narrower, as inside the inpaint screen's card on a 375-point phone.
      await _pump(tester, _state(), [_field(prompt)],
          size: const Size(340, 800));
      row = rects();
      expect(row.map((rect) => rect.top).toSet(), hasLength(1));
      expect(icons(), findsNothing);
      expect(tester.takeException(), isNull);

      await _pump(tester, _state(), [_field(prompt)],
          size: const Size(360, 800), textScale: 2);
      final stacked = rects();
      expect(stacked[0].bottom, lessThanOrEqualTo(stacked[1].top));
      expect(stacked[1].bottom, lessThanOrEqualTo(stacked[2].top));
      expect(stacked.map((rect) => rect.width).toSet(), hasLength(1));
      expect(icons(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('positive presets', () {
    testWidgets('append adds the preset after the current prompt; replace swaps it',
        (tester) async {
      final state = _state();
      state.settings.positivePromptPresets = [
        _preset('p1', '表情', 'smile, 0.8::frown::')
      ];
      final prompt = ValueNotifier('1girl, 1.2::blue hair::');
      await _pump(tester, state, [_field(prompt)]);
      await _tap(tester, _key('positive-library-presets'));
      expect(find.text('追加到当前提示词'), findsOneWidget);
      await _tap(tester, _key('positive-preset-append'));
      expect(prompt.value, '1girl, 1.2::blue hair::, smile, 0.8::frown::');
      expect(find.text('已追加到当前正面提示词末尾。'), findsOneWidget);
      // Let the first notice time out.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await _tap(tester, _key('positive-library-presets'));
      await _tap(tester, _key('positive-preset-replace'));
      expect(prompt.value, 'smile, 0.8::frown::');
      expect(find.text('已替换当前正面提示词。'), findsOneWidget);
    });

    testWidgets(
        'character presets are added after the existing characters within the inpaint model limit',
        (tester) async {
      final state = _state();
      state.params.model = 'nai-diffusion-5-full';
      state.extras.charCaptions = [
        for (final name in ['a', 'b', 'c', 'd', 'e']) CharCaptionItem(prompt: name)
      ];
      state.settings.positivePromptPresets = [
        _preset('trio', '角色组', '', captions: [
          for (var i = 0; i < 3; i++) CharCaptionItem(prompt: 'role $i')
        ])
      ];
      final inpaint = ValueNotifier('');
      final generate = ValueNotifier('');
      await _pump(tester, state, [
        _field(inpaint,
            characterModel: 'nai-diffusion-4-5-full-inpainting',
            key: const ValueKey('inpaint')),
        _field(generate, key: const ValueKey('generate')),
      ]);
      Finder library(String field) => find.descendant(
          of: _key(field), matching: _key('positive-library-presets'));

      await _tap(tester, library('inpaint'));
      expect(find.text('应用 · 3'), findsOneWidget);
      await _tap(tester, find.text('追加这些角色'));
      expect(find.text(_capacity), findsOneWidget);
      expect(state.extras.charCaptions, hasLength(5));
      await _tap(tester, find.byIcon(Icons.close).last);

      await _tap(tester, library('generate'));
      await _tap(tester, find.text('追加这些角色'));
      expect(state.extras.charCaptions.map((c) => c.prompt),
          ['a', 'b', 'c', 'd', 'e', 'role 0', 'role 1', 'role 2']);
      expect(find.text('已在现有角色后追加预设角色。'), findsOneWidget);
      expect(inpaint.value, isEmpty);
      expect(generate.value, isEmpty);
    });

    testWidgets(
        'a preset the inpaint model can hold applies even if the generation model cannot',
        (tester) async {
      final state = _state();
      state.params.model = 'nai-diffusion-4-5-full';
      state.settings.positivePromptPresets = [
        _preset('seven', '七人', '', captions: [
          for (var i = 0; i < 7; i++) CharCaptionItem(prompt: 'role $i')
        ])
      ];
      final inpaint = ValueNotifier('');
      await _pump(tester, state, [
        _field(inpaint, characterModel: 'nai-diffusion-5-full-inpainting')
      ]);
      await _tap(tester, _key('positive-library-presets'));
      await _tap(tester, find.text('应用 · 7'));
      expect(state.extras.charCaptions, hasLength(7));
    });

    testWidgets('tags are saved with a preset and searched with #tag',
        (tester) async {
      final state = _state();
      state.settings.positivePromptPresets = [
        _preset('p1', '星空', '1girl, starry', tags: ['night sky']),
        _preset('p2', '夜晚', '1girl, moon', tags: ['night']),
        _preset('p3', '城市', 'night city'),
      ];
      await _pump(tester, state, [_field(ValueNotifier('1girl'))]);
      await _tap(tester, _key('positive-library-presets'));
      final search = find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(TextField));
      Future<List<String>> listed(String query) async {
        await tester.enterText(search.first, query);
        await tester.pumpAndSettle();
        return [
          for (final id in ['p1', 'p2', 'p3'])
            if (_key('positive-preset-item-$id').evaluate().isNotEmpty) id
        ];
      }

      expect(await listed('#night sky'), ['p1']);
      expect(await listed('#Night'), ['p2']);
      expect(await listed('night'), ['p1', 'p2', 'p3']);
      // Words after a tag are searched as text.
      expect(await listed('#night moon'), ['p2']);
      expect(await listed('#night city'), isEmpty);
      await listed('');

      await _tap(tester, find.text('手动新建'));
      // Suggestions come from the tags already in the library.
      await _tap(tester, find.widgetWithText(ActionChip, '+ night'));
      expect(_tagInput(tester), 'night');
      await tester.enterText(
          find.widgetWithText(TextField, '正面提示词'), '1girl, aurora');
      await tester.enterText(_key('prompt-tag-input'), 'night, #极光，Night ');
      await _tap(tester, find.text('保存'));
      final saved = state.settings.positivePromptPresets.first;
      expect(saved.prompt, '1girl, aurora');
      expect(saved.tags, ['night', '极光']);
      expect((await Storage().getSettings()).positivePromptPresets.first.tags,
          ['night', '极光']);
      // The new tag is now a filter chip.
      expect(_chips(tester), containsAll(['全部4*', '#night2', '#极光1']));
    });
  });

  group('tag filters reset when their chip disappears', () {
    testWidgets('positive presets: deleting the only tagged preset brings back the rest',
        (tester) async {
      final state = _state();
      final blue = _preset('p1', '蓝发少女', '1girl, blue hair', tags: ['夜景']);
      final rain = _preset('p2', '雨夜城市', 'city, night, rain');
      state.settings.positivePromptPresets = [blue, rain];
      await _pump(tester, state, [_field(ValueNotifier('1girl'))]);
      await _tap(tester, _key('positive-library-presets'));
      await _tap(tester, _chip('#夜景'));
      expect(_key('positive-preset-item-p1'), findsOneWidget);
      expect(_key('positive-preset-item-p2'), findsNothing);

      await state.setSettings((s) => s.positivePromptPresets = [rain]);
      await tester.pumpAndSettle();
      expect(_chips(tester), isEmpty);
      expect(_key('positive-preset-item-p2'), findsOneWidget);
      // The new-preset form no longer inherits the removed tag.
      await _tap(tester, find.text('手动新建'));
      expect(_tagInput(tester), '');
    });

    testWidgets('positive presets: with other tags left, the filter returns to 全部',
        (tester) async {
      final state = _state();
      state.settings.positivePromptPresets = [
        _preset('p1', '蓝发少女', '1girl', tags: ['夜景']),
        _preset('p2', '雨夜城市', 'city', tags: ['角色']),
      ];
      await _pump(tester, state, [_field(ValueNotifier('1girl'))]);
      await _tap(tester, _key('positive-library-presets'));
      await _tap(tester, _chip('#夜景'));
      await state.setSettings((s) => s.positivePromptPresets.first.tags = []);
      await tester.pumpAndSettle();
      expect(_chips(tester), ['全部2*', '#角色1', '未加标签1']);
      expect(_key('positive-preset-item-p1'), findsOneWidget);
      expect(_key('positive-preset-item-p2'), findsOneWidget);
    });

    testWidgets('negative library: deleting the only tagged entry brings back the rest',
        (tester) async {
      final state = _state();
      state.settings.negativePromptPresets = [
        _negative('n1', '通用', 'lowres, bad anatomy', tags: ['通用']),
        _negative('n2', '模糊', 'blurry'),
      ];
      await _pump(tester, state, [_field(ValueNotifier('lowres'), negative: true)]);
      await _tap(tester, _key('negative-library-open'));
      await _tap(tester, _chip('#通用'));
      expect(_key('negative-preset-item-n1'), findsOneWidget);
      expect(_key('negative-preset-item-n2'), findsNothing);

      await state.mutateNegativePresets(
          (old) => old.where((p) => p['id'] != 'n1').toList());
      await tester.pumpAndSettle();
      expect(_chips(tester), isEmpty);
      expect(_key('negative-preset-item-n2'), findsOneWidget);
    });

    testWidgets(
        'prompt chunks: removing the only tag, or tagging the last untagged chunk, brings back the list',
        (tester) async {
      final state = _state();
      final outfit = _chunk('c1', '服装', 'white dress', tags: ['衣服']);
      final smile = _chunk('c2', '表情', 'smile');
      state.settings.promptChunks = [outfit, smile];
      await _pump(tester, state, [_field(ValueNotifier('1girl'))]);
      await _tap(tester, _key('positive-library-chunks'));
      List<String> listed() => [
            for (final id in ['c1', 'c2'])
              if (_key('prompt-chunk-item-$id').evaluate().isNotEmpty) id
          ];
      await _tap(tester, _chip('#衣服'));
      expect(listed(), ['c1']);
      await state.setSettings((s) => s.promptChunks.first.tags = []);
      await tester.pumpAndSettle();
      expect(listed(), ['c1', 'c2']);

      await state.setSettings((s) => s.promptChunks.first.tags = ['衣服']);
      await tester.pumpAndSettle();
      await _tap(tester, _chip('未加标签'));
      expect(listed(), ['c2']);
      expect(_chips(tester), contains('未加标签1*'));
      await state.setSettings((s) => s.promptChunks.last.tags = ['表情']);
      await tester.pumpAndSettle();
      expect(_chips(tester).first, '全部2*');
      expect(_chips(tester).skip(1).toSet(), {'#表情1', '#衣服1'});
      expect(listed(), ['c1', 'c2']);
    });
  });

  group('new entries skip a tag filter that went stale while the library was closed',
      () {
    testWidgets(
        'positive presets: the bar 保存当前 keeps a tag that exists and drops one that was removed',
        (tester) async {
      final state = _state();
      final night = _preset('p1', '蓝发少女', '1girl', tags: ['夜景']);
      final role = _preset('p2', '雨夜城市', 'city', tags: ['角色']);
      state.settings.positivePromptPresets = [night, role];
      await _pump(tester, state, [_field(ValueNotifier('1girl, smile'))]);
      await _tap(tester, _key('positive-library-presets'));
      await _tap(tester, _chip('#角色'));
      await _tap(tester, find.byIcon(Icons.close).last);
      await _tap(tester, _key('positive-library-save-current'));
      expect(_tagInput(tester), '角色');
      await _tap(tester, find.text('取消'));
      await _tap(tester, find.byIcon(Icons.close).last);

      // Another library (each character row has one) or a restore removes it.
      await state.setSettings((s) => s.positivePromptPresets.last.tags = []);
      await tester.pumpAndSettle();
      await _tap(tester, _key('positive-library-save-current'));
      expect(_tagInput(tester), '');
      // The filter is reset too, so the list is complete once the editor
      // closes.
      await _tap(tester, find.text('取消'));
      expect(_chips(tester).first, '全部2*');
      expect(_key('positive-preset-item-p1'), findsOneWidget);
      expect(_key('positive-preset-item-p2'), findsOneWidget);
    });

    testWidgets(
        'negative library: the bar 保存当前 keeps a tag that exists and drops one that was removed',
        (tester) async {
      final state = _state();
      state.settings.negativePromptPresets = [
        _negative('n1', '通用', 'lowres, bad anatomy', tags: ['通用']),
        _negative('n2', '模糊', 'blurry', tags: ['画质']),
      ];
      final negative = ValueNotifier('lowres');
      await _pump(tester, state, [_field(negative, negative: true)]);
      await _tap(tester, _key('negative-library-open'));
      await _tap(tester, _chip('#画质'));
      await _tap(tester, find.byTooltip('关闭'));
      await _tap(tester, _key('negative-library-save-current'));
      expect(_tagInput(tester), '画质');
      // The editor starts from the current negative prompt.
      expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, '负面提示词'))
              .controller!
              .text,
          'lowres');
      await _tap(tester, find.text('取消'));
      await _tap(tester, find.byTooltip('关闭'));

      await state.mutateNegativePresets((old) => [
            old.first,
            {...old.last}..remove('tags'),
          ]);
      await tester.pumpAndSettle();
      await _tap(tester, _key('negative-library-save-current'));
      expect(_tagInput(tester), '');
      await _tap(tester, find.text('取消'));
      expect(_chips(tester).first, '全部2*');
    });

    testWidgets('prompt chunks: 新建提词 pre-fills a tag that exists, not a removed one',
        (tester) async {
      final state = _state();
      state.settings.promptChunks = [
        _chunk('c1', '服装', 'white dress', tags: ['衣服']),
        _chunk('c2', '表情', 'smile', tags: ['表情']),
      ];
      await _pump(tester, state, [_field(ValueNotifier('1girl'))]);
      await _tap(tester, _key('positive-library-chunks'));
      await _tap(tester, _chip('#衣服'));
      await _tap(tester, find.byIcon(Icons.close).last);
      await _tap(tester, _key('positive-library-chunks'));
      expect(_chips(tester), contains('#衣服1*'));
      await _tap(tester, _key('prompt-chunk-create'));
      expect(_tagInput(tester), '衣服');
      await _tap(tester, find.byIcon(Icons.close).last);

      await state.setSettings((s) => s.promptChunks.first.tags = []);
      await tester.pumpAndSettle();
      await _tap(tester, _key('positive-library-chunks'));
      expect(_chips(tester).first, '全部2*');
      await _tap(tester, _key('prompt-chunk-create'));
      expect(_tagInput(tester), '');
    });
  });

  group('negative library and prompt chunks', () {
    testWidgets('the negative library saves tags and appends with one separator',
        (tester) async {
      final state = _state();
      state.settings.negativePromptPresets = [
        _negative('n1', '模糊', 'blurry', tags: ['画质'])
      ];
      final negative = ValueNotifier('lowres,  ');
      await _pump(tester, state, [_field(negative, negative: true)]);
      await _tap(tester, _key('negative-library-save-current'));
      await tester.enterText(find.widgetWithText(TextField, '名称'), '低清');
      await _tap(tester, find.widgetWithText(ActionChip, '+ 画质'));
      await tester.enterText(_key('prompt-tag-input'), '画质, #低清');
      await _tap(tester, find.text('保存'));
      final saved = state.settings.negativePromptPresets
          .firstWhere((p) => p['name'] == '低清');
      expect(saved['prompt'], 'lowres,  ');
      expect(saved['tags'], ['画质', '低清']);
      expect(
          (await Storage().getSettings())
              .negativePromptPresets
              .firstWhere((p) => p['name'] == '低清')['tags'],
          ['画质', '低清']);

      await _tap(tester, _key('negative-preset-item-n1'));
      await _tap(tester, find.text('追加'));
      expect(negative.value, 'lowres, blurry');
    });

    testWidgets('prompt chunks are created with tags, inserted and deleted',
        (tester) async {
      final state = _state();
      final prompt = ValueNotifier('1girl');
      await _pump(tester, state, [_field(prompt)]);
      await _tap(tester, _key('positive-library-chunks'));
      expect(find.text('还没有自定义提词。'), findsOneWidget);
      await _tap(tester, _key('prompt-chunk-create'));
      await _tap(tester, find.text('确认保存'));
      expect(find.text('请填写名称。'), findsOneWidget);
      expect(find.text('请填写提词内容。'), findsOneWidget);
      expect(state.settings.promptChunks, isEmpty);

      await tester.enterText(_key('prompt-chunk-name'), ' 服装 ');
      await tester.enterText(_key('prompt-chunk-content'), ' white dress, ');
      await tester.enterText(_key('prompt-tag-input'), '衣服，角色');
      await _tap(tester, find.text('确认保存'));
      final chunk = state.settings.promptChunks.single;
      expect(chunk.name, '服装');
      expect(chunk.content, 'white dress,');
      expect(chunk.tags, ['衣服', '角色']);
      expect((await Storage().getSettings()).promptChunks.single.toJson(),
          chunk.toJson());

      await _tap(tester, _key('prompt-chunk-item-${chunk.id}'));
      expect(prompt.value, '1girl, white dress, ');
      expect(find.text('已插入自定义提词。'), findsOneWidget);

      await _tap(tester, _key('positive-library-chunks'));
      await _tap(tester, find.byTooltip('删除'));
      await _tap(tester, find.widgetWithText(FilledButton, '删除'));
      expect(state.settings.promptChunks, isEmpty);
      expect((await Storage().getSettings()).promptChunks, isEmpty);
    });
  });

  testWidgets(
      'character rows append a saved character into the row and show library changes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 2800);
    addTearDown(tester.view.reset);
    final state = _state();
    state.extras.charCaptions = [
      CharCaptionItem(prompt: 'red coat', negativePrompt: 'hat')
    ];
    state.settings.positivePromptPresets = [
      _preset('role', '微笑', 'smile',
          captions: [CharCaptionItem(prompt: 'smile', negativePrompt: 'blur')]),
      _preset('plain', '闪光', 'sparkle'),
    ];
    state.settings.promptChunks = [_chunk('c1', '服装', 'white dress')];
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state, child: const MaterialApp(home: GenerateScreen())));
    await tester.pumpAndSettle();
    String rowPrompt() => tester
        .widget<EditableText>(find.descendant(
            of: _key('character-prompt-field-0'),
            matching: find.byType(EditableText)))
        .controller
        .text;
    final presets = _key('character-presets-0');
    await tester.scrollUntilVisible(presets, 400,
        scrollable: find.byType(Scrollable).first, maxScrolls: 15);
    await tester.pumpAndSettle();

    await _tap(tester, presets);
    // One saved character appended inside the row continues the row.
    expect(find.text('追加到当前提示词'), findsOneWidget);
    await _tap(tester, _key('positive-preset-append'));
    expect(state.extras.charCaptions.single.prompt, 'red coat, smile');
    expect(state.extras.charCaptions.single.negativePrompt, 'hat, blur');
    expect(rowPrompt(), 'red coat, smile');

    await _tap(tester, _key('character-presets-0'));
    await _tap(tester, _key('positive-preset-item-plain'));
    await _tap(tester, _key('positive-preset-append'));
    expect(rowPrompt(), 'red coat, smile, sparkle');

    await _tap(tester, _key('character-chunks-0'));
    await _tap(tester, _key('prompt-chunk-item-c1'));
    expect(state.extras.charCaptions.single.prompt,
        'red coat, smile, sparkle, white dress, ');
    expect(rowPrompt(), 'red coat, smile, sparkle, white dress, ');
    expect(state.extras.charCaptions.single.negativePrompt, 'hat, blur');
    expect(tester.takeException(), isNull);
  });
}
