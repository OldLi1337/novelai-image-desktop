import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/i18n/app_locales.dart';
import 'package:novelai_mobile/services/online_gallery_service.dart';
import 'package:novelai_mobile/services/quicktag_ui.dart';

void main() {
  test('QuickTagCloud keeps its gallery adapter and separate source identity',
      () {
    expect(OnlineGallerySource.quicktag.label, 'QuickTagCloud');
    expect(OnlineGallerySource.quicktag.siteUrl,
        'https://novelai.quicktagcloud.com');
    final implementation =
        File('lib/services/prompt_codex_service.dart').readAsStringSync();
    expect(implementation, contains('https://nai4.top'));
    expect(implementation, isNot(contains('quicktagcloud.com')));
    final gallery =
        File('lib/screens/online_gallery_screen.dart').readAsStringSync();
    expect(gallery, isNot(contains('QuickTagCloud ·')));
  });
  test('labels match the desktop locale and do not add a main destination',
      () {
    final shared =
        jsonDecode(File('../shared/quicktag-ui.json').readAsStringSync())
            as Map;
    // The desktop ships Simplified Chinese only; compare every locale it has.
    expect(shared.keys, contains('zh-CN'));
    for (final locale in shared.keys) {
      expect(quickTagUi(locale), shared[locale]);
    }
    expect(mobileUiTextFor('zh-CN', 'promptCodex.enabled'),
        contains('nai4.top'));
    expect(mainDestinationLabelsFor('zh-CN'), hasLength(12));
    expect(mainDestinationLabelsFor('zh-CN'), isNot(contains('QuickTagCloud')));
    expect(quickTagUi('zh-CN')['catalog'], '全部资料库');
  });
}
