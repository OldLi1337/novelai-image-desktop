import 'tavern_models.dart';
import 'lyra_preset_data.dart';

const lyraImageSamplerId = 'builtin-lyra-beta-3-8-sampler';

TavernSamplerPreset createLyraImageSamplerPreset() {
  return TavernSamplerPreset(
    id: lyraImageSamplerId,
    name: lyraPresetName,
    systemPrompt: lyraPresetSystemPrompt,
    jailbreakPrompt: lyraPresetJailbreakPrompt,
    temperature: 1,
    topP: .95,
    maxOutputTokens: 65535,
    source: 'builtin',
    sourceName: lyraPresetSourceName,
    sourceHash: lyraPresetSourceSha256,
  );
}
