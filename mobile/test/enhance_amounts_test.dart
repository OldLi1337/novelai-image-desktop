import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:novelai_mobile/billing/anlas.dart';
import 'package:novelai_mobile/images/enhance_plan.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/screens/tools_screen.dart';
import 'package:novelai_mobile/services/nai_api.dart';
import 'package:novelai_mobile/services/storage.dart';
import 'package:novelai_mobile/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _v45 = 'nai-diffusion-4-5-full';
const _v5 = 'nai-diffusion-5-full';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('planEnhance', () {
    test('1x keeps the size and fits an oversized source', () {
      expect(planEnhance(832, 1216, 1, _v45), (
        width: 832,
        height: 1216,
        outputWidth: 832,
        outputHeight: 1216,
        upscaledEnhance: false,
        exceedsLimit: false
      ));
      final large = planEnhance(2048, 2048, 1, _v45);
      expect((large.width, large.height, large.exceedsLimit),
          (1728, 1728, false));
    });

    test('1.5x is sent on the 64-pixel grid and never shrunk to fit', () {
      expect(planEnhance(832, 1216, 1.5, _v5), (
        width: 1280,
        height: 1856,
        outputWidth: 1280,
        outputHeight: 1856,
        upscaledEnhance: false,
        exceedsLimit: false
      ));
      expect(planEnhance(1024, 1536, 1.5, _v45), (
        width: 1536,
        height: 2304,
        outputWidth: 1536,
        outputHeight: 2304,
        upscaledEnhance: false,
        exceedsLimit: true
      ));
    });

    test('MAX uses upscaled_enhance on V5 and about 2x within the area elsewhere',
        () {
      expect(planEnhance(832, 1216, 0, _v5), (
        width: 832,
        height: 1216,
        outputWidth: 1467,
        outputHeight: 2144,
        upscaledEnhance: true,
        exceedsLimit: false
      ));
      final legacy = planEnhance(832, 1216, 0, _v45);
      expect(legacy, (
        width: 1408,
        height: 2112,
        outputWidth: 1408,
        outputHeight: 2112,
        upscaledEnhance: false,
        exceedsLimit: false
      ));
      expect(legacy.width * legacy.height, lessThanOrEqualTo(naiMaxPixelArea));
      final small = planEnhance(512, 768, 0, _v45);
      expect((small.width, small.height), (1024, 1536));
    });
  });

  group('AppState Enhance', () {
    test('the estimate quotes the size and strength the run sends', () {
      final state = AppState()
        ..params.model = _v45
        ..enhanceMagnitude = 5
        ..workbenchImage =
            const WorkingImage(filePath: 'source.png', width: 832, height: 1216);
      addTearDown(state.dispose);
      int? quote(int width, int height, {bool upscaledEnhance = false}) =>
          calculateImageGenerationAnlas(
            params: state.params.copy()
              ..width = width
              ..height = height,
            account: state.account,
            extras: state.extras,
            imageToImage: true,
            upscaledEnhance: upscaledEnhance,
            strength: .5,
          ).amount;

      expect(state.enhanceAnlasQuote.amount, quote(832, 1216));
      state.enhanceScale = 1.5;
      expect(state.enhanceAnlasQuote.amount, quote(1280, 1856));
      expect(quote(1280, 1856), greaterThan(quote(832, 1216)!));
      state.enhanceScale = 0;
      expect(state.enhanceAnlasQuote.amount, quote(1408, 2112));
      state.params.model = _v5;
      // V5 MAX sends the source size and is billed for the enlarged result.
      expect(state.enhanceAnlasQuote.amount,
          quote(832, 1216, upscaledEnhance: true));
      expect(quote(832, 1216, upscaledEnhance: true),
          greaterThan(quote(832, 1216)!));
    });

    test('an oversized 1.5x target is explained in Chinese and never sent',
        () async {
      final api = _EnhanceApi();
      final state = AppState(api: api, storage: _EnhanceStorage())
        ..params.positivePrompt = 'synthetic prompt'
        ..workbenchImage =
            const WorkingImage(filePath: 'source.png', width: 1024, height: 1536)
        ..enhanceScale = 1.5;
      addTearDown(state.dispose);
      final before = (
        state.params.width,
        state.params.height,
        state.i2i.strength,
        state.i2iSizeMode
      );
      const reason = '增强并放大后的目标尺寸 1536×2304（3,538,944 像素）'
          '超过 NovelAI 允许的 3,145,728 像素上限。请选择 1×、MAX 或换用更小的原图；未发送请求。';

      expect(state.enhanceAnlasQuote.ok, isFalse);
      expect(state.enhanceAnlasQuote.message, reason);
      await state.enhance();

      expect(api.requests, isEmpty);
      expect(state.status, reason);
      expect(
          (
            state.params.width,
            state.params.height,
            state.i2i.strength,
            state.i2iSizeMode
          ),
          before);
    });

    for (final run in [
      (model: _v45, scale: 1.5, source: 832, sent: (1280, 1856, false)),
      (model: _v45, scale: 0.0, source: 64, sent: (128, 128, false)),
      (model: _v5, scale: 0.0, source: 64, sent: (64, 64, true)),
    ]) {
      test(
          '${run.model} at ${run.scale == 0 ? 'MAX' : '${run.scale}x'} sends '
          'the planned size, as quoted, and restores the parameters', () async {
        final api = _EnhanceApi();
        final state = AppState(
          api: api,
          storage: _EnhanceStorage(),
          preloadCompletedImage: (_) async {},
        )
          ..params.model = run.model
          ..params.positivePrompt = 'synthetic prompt'
          ..enhanceScale = run.scale
          ..workbenchImage = WorkingImage(
              filePath: 'source.png',
              width: run.source,
              height: run.source == 64 ? 64 : 1216);
        addTearDown(state.dispose);
        api.onRequest = () => api.reserved = state.queueReservedAnlas;
        final quoted = state.enhanceAnlasQuote.amount;
        final before = (
          state.params.width,
          state.params.height,
          state.i2i.strength,
          state.i2i.noise,
          state.i2iSizeMode,
          state.i2iSourceMode
        );

        await state.enhance();

        expect(api.requests.single, (
          width: run.sent.$1,
          height: run.sent.$2,
          upscaledEnhance: run.sent.$3,
          strength: .5
        ));
        expect(api.reserved, quoted);
        final saved = state.history.single;
        final output = run.sent.$3 ? (128, 128) : (run.sent.$1, run.sent.$2);
        expect((saved.width, saved.height), output);
        expect(
            (
              state.params.width,
              state.params.height,
              state.i2i.strength,
              state.i2i.noise,
              state.i2iSizeMode,
              state.i2iSourceMode
            ),
            before);
        expect(state.i2i.upscaledEnhance, isFalse);
      });
    }
  });

  testWidgets('offers 1x, 1.5x and MAX and blocks an oversized 1.5x target',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1600);
    addTearDown(tester.view.reset);
    final temp = Directory.systemTemp.createTempSync('enhance-amounts-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final file = File('${temp.path}/source.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 64, height: 64)));
    final state = AppState()
      ..params.model = _v5
      ..workbenchImage =
          WorkingImage(filePath: file.path, width: 832, height: 1216);
    addTearDown(state.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
            home: ToolsScreen(kind: ToolPageKind.postprocess))));
    await tester.pump();

    Finder run(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    expect(find.text('1× 保持分辨率'), findsOneWidget);
    expect(find.text('1.5× 同时放大'), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);
    expect(find.textContaining('2× 同时放大'), findsNothing);
    expect(find.text('832×1216 → 832×1216'), findsOneWidget);
    expect(find.text('1× 只做二次扩散增强；1.5× 与 MAX 会同时提高分辨率。尺寸会按 NovelAI 支持范围自动对齐。'),
        findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(run('增强图像 1×')).enabled, isTrue);

    await tester.tap(find.text('1.5× 同时放大'));
    await tester.pump();
    expect(state.enhanceScale, 1.5);
    expect(find.text('832×1216 → 1280×1856'), findsOneWidget);
    expect(find.textContaining('Anlas'), findsWidgets);
    expect(tester.widget<ButtonStyleButton>(run('增强图像 1.5×')).enabled, isTrue);

    await tester.tap(find.text('MAX'));
    await tester.pump();
    expect(find.text('832×1216 → 1467×2144'), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(run('增强图像 MAX')).enabled, isTrue);

    state
      ..enhanceScale = 1.5
      ..workbenchImage =
          WorkingImage(filePath: file.path, width: 1024, height: 1536)
      ..markChanged();
    await tester.pump();
    expect(find.text('1024×1536 → 1536×2304'), findsOneWidget);
    expect(find.textContaining('3,145,728 像素上限。请选择 1×、MAX'), findsOneWidget);
    expect(find.textContaining('Anlas'), findsNothing);
    expect(
        tester.widget<ButtonStyleButton>(run('增强图像 1.5×')).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _EnhanceApi extends NaiApi {
  final requests =
      <({int width, int height, bool upscaledEnhance, double strength})>[];
  void Function()? onRequest;
  int? reserved;

  @override
  Future<AccountSummary> fetchAccount(String token, AppSettings settings) async =>
      const AccountSummary(hasToken: true, tierLevel: 1, anlasBalance: 1000);

  @override
  Future<(List<Uint8List>, int)> img2img(
    String token,
    AppSettings settings,
    GenerateParams params,
    GenerateExtras extras,
    Uint8List imageBytes,
    I2IParams i2i,
  ) async {
    onRequest?.call();
    requests.add((
      width: params.width,
      height: params.height,
      upscaledEnhance: i2i.upscaledEnhance,
      strength: i2i.strength
    ));
    // MAX on V5 returns the enlarged image; its size is read from the bytes.
    final side = i2i.upscaledEnhance ? params.width * 2 : 8;
    return (
      [Uint8List.fromList(img.encodePng(img.Image(width: side, height: side)))],
      7
    );
  }
}

class _EnhanceStorage extends Storage {
  @override
  Future<String?> getToken() async => 'test-token';

  @override
  Future<Uint8List> readImage(String path,
          {int maxBytes = 64 * 1024 * 1024}) async =>
      Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));

  @override
  Future<HistoryItem> saveImage(
    Uint8List bytes,
    GenerateParams params,
    int seed, {
    String feature = 't2i',
    String? model,
    int? width,
    int? height,
    String? groupId,
  }) async =>
      HistoryItem(
        id: 'enhanced',
        filePath: 'enhanced.png',
        date: '2026-10-30',
        createdAt: '2026-10-30T00:00:00',
        seed: seed,
        model: model ?? params.model,
        width: width ?? params.width,
        height: height ?? params.height,
        prompt: params.positivePrompt,
        feature: feature,
        groupId: groupId,
        params: params.toJson(),
      );
}
