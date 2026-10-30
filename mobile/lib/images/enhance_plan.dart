import '../models/nai_models.dart';

/// One Enhance run. [width] x [height] is the image-to-image size that is sent
/// and billed; [outputWidth] x [outputHeight] is the image that comes back.
/// They differ only for MAX on V5 models, which NovelAI enlarges itself
/// (upscaled_enhance). [exceedsLimit] marks a 1.5x target above the official
/// pixel area: it is shown as requested and never sent.
typedef EnhancePlan = ({
  int width,
  int height,
  int outputWidth,
  int outputHeight,
  bool upscaledEnhance,
  bool exceedsLimit
});

/// NovelAI's official Enhance amounts: [scale] is 1 (keep the size), 1.5
/// (enlarge on the 64-pixel grid) or 0 for MAX.
EnhancePlan planEnhance(int width, int height, double scale, String model) {
  if (scale == 0 && model.startsWith('nai-diffusion-5-')) {
    final input = adaptiveNaiImageSize(width, height,
        fallbackWidth: width, fallbackHeight: height);
    final output = maxNaiEnhanceSize(input.$1, input.$2);
    return (
      width: input.$1,
      height: input.$2,
      outputWidth: output.width,
      outputHeight: output.height,
      upscaledEnhance: true,
      exceedsLimit: false
    );
  }
  if (scale > 1) {
    final target = resolveNaiEnhanceOutputSize(width, height, scale,
        fallbackWidth: width, fallbackHeight: height);
    return (
      width: target.width,
      height: target.height,
      outputWidth: target.width,
      outputHeight: target.height,
      upscaledEnhance: false,
      exceedsLimit: target.exceedsLimit
    );
  }
  // 1x, and MAX on other models: up to 2x image-to-image within the area.
  final factor = scale == 0 ? 2 : 1;
  final target = adaptiveNaiImageSize(width * factor, height * factor,
      fallbackWidth: width, fallbackHeight: height);
  return (
    width: target.$1,
    height: target.$2,
    outputWidth: target.$1,
    outputHeight: target.$2,
    upscaledEnhance: false,
    exceedsLimit: false
  );
}
