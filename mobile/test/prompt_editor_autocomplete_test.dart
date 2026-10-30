import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/screens/generate_screen.dart' show PromptEditor;
import 'package:novelai_mobile/services/nai_api.dart';
import 'package:novelai_mobile/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The session rules follow the desktop's PromptTextarea (src/App.tsx); the
// insertion itself is covered by prompt_autocomplete_test.dart.
class _SuggestState extends AppState {
  final queries = <String>[];
  final pending = <Completer<List<TagSuggestion>>>[];
  List<String>? reply;

  @override
  Future<List<TagSuggestion>> suggestTags(String query) {
    queries.add(query);
    final tags = reply;
    if (tags != null) {
      return Future.value(
          [for (final tag in tags) TagSuggestion(tag: tag, description: '说明')]);
    }
    final request = Completer<List<TagSuggestion>>();
    pending.add(request);
    return request.future;
  }
}

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);
final _field = find.byType(TextField);

TextEditingController _controller(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!;

bool _focused(WidgetTester tester) =>
    tester.state<EditableTextState>(find.byType(EditableText)).widget.focusNode.hasFocus;

Future<_SuggestState> _pumpEditor(WidgetTester tester,
    {List<String>? reply = const ['blue hair', 'blue eyes']}) async {
  SharedPreferences.setMockInitialValues({});
  final state = _SuggestState()
    ..settings.language = 'zh-CN'
    ..reply = reply;
  addTearDown(state.dispose);
  var text = '';
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(16), children: [
          StatefulBuilder(
            builder: (context, setState) => PromptEditor(
              label: '正面提示词',
              value: text,
              maxLines: 5,
              onChanged: (value) => setState(() => text = value),
            ),
          ),
          const SizedBox(height: 40),
          const Text('页面其他区域'),
        ]),
      ),
    ),
  ));
  await tester.showKeyboard(_field);
  return state;
}

// What the keyboard or an input method reports after an edit.
Future<void> _input(WidgetTester tester, String text,
    {int? caret, TextRange composing = TextRange.empty}) async {
  tester.testTextInput.updateEditingValue(TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret ?? text.length),
    composing: composing,
  ));
  await tester.pump();
}

// Waits out the lookup delay and shows the reply.
Future<void> _lookup(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 320));
  await tester.pump();
}

void main() {
  testWidgets('a tapped suggestion replaces the word it was made for',
      (tester) async {
    final state = await _pumpEditor(tester);
    await _input(tester, '1girl, blu, smile', caret: 10);
    await _lookup(tester);
    expect(state.queries, ['blu']);

    await tester.tap(find.text('blue eyes'));
    await tester.pump();
    expect(_controller(tester).text, '1girl, blue eyes, smile');
    expect(_controller(tester).selection.isCollapsed, isTrue);
    expect(_controller(tester).selection.baseOffset, 18);
    expect(find.text('blue hair'), findsNothing);
    expect(_focused(tester), isTrue);
  }, variant: _ios);

  testWidgets('any press outside the list closes it, in the prompt box too',
      (tester) async {
    await _pumpEditor(tester);
    await _input(tester, 'blu');
    await _lookup(tester);
    expect(find.text('blue hair'), findsOneWidget);

    // Below the text: the caret stays where it was, yet the list closes.
    await tester.tapAt(tester.getBottomLeft(_field) + const Offset(24, -12));
    await tester.pump();
    expect(_controller(tester).selection.isCollapsed, isTrue);
    expect(_controller(tester).selection.baseOffset, 3);
    expect(find.text('blue hair'), findsNothing);

    await _input(tester, 'blue');
    await _lookup(tester);
    expect(find.text('blue hair'), findsOneWidget);
    await tester.tap(find.text('页面其他区域'));
    await tester.pump();
    expect(find.text('blue hair'), findsNothing);
  }, variant: _ios);

  testWidgets('Escape closes only the list and keeps typing in the box',
      (tester) async {
    await _pumpEditor(tester);
    await _input(tester, 'blu');
    await _lookup(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('blue hair'), findsNothing);
    expect(_focused(tester), isTrue);
  }, variant: _ios);

  testWidgets('in a dialog, Escape and back close the list before the dialog',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = _SuggestState()
      ..settings.language = 'zh-CN'
      ..reply = ['blue hair'];
    addTearDown(state.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: PromptEditor(
                    label: '负面提示词', value: '', onChanged: (_) {}),
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.showKeyboard(_field);

    await _input(tester, 'blu');
    await _lookup(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('blue hair'), findsNothing);
    expect(find.byType(Dialog), findsOneWidget);

    await _input(tester, 'blue');
    await _lookup(tester);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('blue hair'), findsNothing);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  }, variant: _ios);

  testWidgets('focus loss and caret moves close the list and drop late replies',
      (tester) async {
    final state = await _pumpEditor(tester);
    await _input(tester, 'blu');
    await _lookup(tester);
    await _input(tester, 'blu', caret: 1);
    expect(find.text('blue hair'), findsNothing);

    await _input(tester, 'blue');
    await _lookup(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text('blue hair'), findsNothing);

    state.reply = null;
    await tester.showKeyboard(_field);
    await _input(tester, 'blue h', caret: 4);
    await _lookup(tester);
    await _input(tester, 'blue h', caret: 6);
    state.pending.removeLast().complete([const TagSuggestion(tag: 'blue hair')]);
    await tester.pump();
    expect(find.text('blue hair'), findsNothing, reason: 'the caret moved');

    await _input(tester, 'blue');
    await _lookup(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    state.pending.removeLast().complete([const TagSuggestion(tag: 'blue hair')]);
    await tester.pump();
    expect(find.text('blue hair'), findsNothing, reason: 'the box lost focus');
  }, variant: _ios);

  testWidgets('a reply for an older word never replaces the current one',
      (tester) async {
    final state = await _pumpEditor(tester, reply: null);
    await _input(tester, 'bl');
    await _lookup(tester);
    await _input(tester, 'blo');
    await _lookup(tester);
    expect(state.queries, ['bl', 'blo']);
    state.pending.last.complete([const TagSuggestion(tag: 'blonde hair')]);
    await tester.pump();
    state.pending.first.complete([const TagSuggestion(tag: 'black hair')]);
    await tester.pump();
    expect(find.text('blonde hair'), findsOneWidget);
    expect(find.text('black hair'), findsNothing);

    await tester.tap(find.text('blonde hair'));
    await tester.pump();
    expect(_controller(tester).text, 'blonde hair, ');

    // The word is replaced at the same caret position.
    await _input(tester, 'bl');
    await _lookup(tester);
    await _input(tester, 'cu');
    await _lookup(tester);
    state.pending[2].complete([const TagSuggestion(tag: 'black hair')]);
    await tester.pump();
    expect(find.text('black hair'), findsNothing);
    state.pending[3]
        .complete([const TagSuggestion(tag: 'cute', description: '可爱')]);
    await tester.pump();
    expect(find.text('cute'), findsOneWidget);
  }, variant: _ios);

  testWidgets('an input method composition never shows suggestions',
      (tester) async {
    final state = await _pumpEditor(tester, reply: ['blue eyes']);
    await _input(tester, 'lan', composing: const TextRange(start: 0, end: 3));
    await _lookup(tester);
    expect(state.queries, isEmpty);

    await _input(tester, '蓝眼');
    await _lookup(tester);
    expect(state.queries, ['蓝眼']);
    expect(find.text('blue eyes'), findsOneWidget);

    // Starting the next composition closes the list at once.
    await _input(tester, '蓝眼l', composing: const TextRange(start: 2, end: 3));
    expect(find.text('blue eyes'), findsNothing);
    await _input(tester, '蓝眼lo', composing: const TextRange(start: 2, end: 4));
    await _lookup(tester);
    expect(state.queries, ['蓝眼']);

    // Committing the letters unchanged makes them prompt text.
    await _input(tester, '蓝眼lo');
    await _lookup(tester);
    expect(state.queries, ['蓝眼', '蓝眼lo']);
    expect(find.text('blue eyes'), findsOneWidget);
  }, variant: _ios);

  testWidgets(
      'arrow keys keep the highlighted row in view, and a new list starts at its first row',
      (tester) async {
    final tags = [for (var i = 0; i < 8; i++) 'tag$i'];
    final state = await _pumpEditor(tester, reply: tags);
    await _input(tester, 'ta');
    await _lookup(tester);
    final list = find.ancestor(of: find.text('tag0'), matching: find.byType(Card));
    bool shown(String tag) {
      final rect = tester.getRect(list);
      final row = tester.getRect(find.text(tag));
      return row.top >= rect.top && row.bottom <= rect.bottom;
    }

    expect(shown('tag7'), isFalse, reason: 'eight rows do not fit the list');
    for (var i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(shown('tag7'), isTrue);
    expect(shown('tag0'), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_controller(tester).text, 'tag6, ');

    await _input(tester, 'tag6, ta');
    await _lookup(tester);
    expect(shown('tag0'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_controller(tester).text, 'tag6, tag0, ');

    // Typing moves the highlight back to the first row of the list shown.
    await _input(tester, 'tag6, tag0, ta');
    await _lookup(tester);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await _input(tester, 'tag6, tag0, tag');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_controller(tester).text, 'tag6, tag0, tag0, ');

    // Arrows pressed on the old list while the next lookup runs.
    await _input(tester, 'tag6, tag0, tag0, ta');
    await _lookup(tester);
    state.reply = ['tagA', 'tagB', 'tagC'];
    await _input(tester, 'tag6, tag0, tag0, tag');
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await _lookup(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_controller(tester).text, 'tag6, tag0, tag0, tagA, ');
  }, variant: _ios);

  testWidgets(
      'a mouse resting over the new list does not pick a row; moving and clicking do',
      (tester) async {
    await _pumpEditor(tester, reply: ['tag0', 'tag1', 'tag2']);
    await _input(tester, 'ta');
    await _lookup(tester);
    final rowCenter = tester.getCenter(find.text('tag2'));
    await tester.tap(find.text('页面其他区域'));
    await tester.pump();
    expect(find.text('tag2'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: rowCenter);
    await _input(tester, 'tag');
    await _lookup(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_controller(tester).text, 'tag0, ');

    await _input(tester, 'tag0, ta');
    await _lookup(tester);
    await mouse.moveTo(tester.getCenter(find.text('tag1')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_controller(tester).text, 'tag0, tag1, ');

    await _input(tester, 'tag0, tag1, ta');
    await _lookup(tester);
    await tester.tap(find.text('tag2'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(_controller(tester).text, 'tag0, tag1, tag2, ');
    expect(_focused(tester), isTrue);
  }, variant: _ios);

  testWidgets('with autocomplete off nothing is looked up', (tester) async {
    final state = await _pumpEditor(tester);
    state.settings.autoComplete = false;
    await _input(tester, 'blue');
    await _lookup(tester);
    expect(state.queries, isEmpty);
    expect(find.text('blue hair'), findsNothing);
  }, variant: _ios);
}
