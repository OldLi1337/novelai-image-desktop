import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile uses the existing NovelAI API instead of a second image model', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final generate = File('lib/screens/generate_screen.dart').readAsStringSync();
    final state = File('lib/state/app_state.dart').readAsStringSync();
    expect(settings, contains('const CompatibleImageSettingsCard()'));
    expect(generate, contains('CompatibleGenerateScreen(preview:preview)'));
    expect(state, contains("settings.imageProvider = 'novelai';"));
  });
}
