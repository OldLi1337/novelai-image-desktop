String parityText(Object? locale, String key) {
  const words = {
    'sound': '提示音',
    'enabled': '生成完成提示音',
    'when': '生成页单张或整批任务完成且保存了图片时播放一次；取消或全部失败不播放。',
    'volume': '音量',
    'custom': '自定义音频：MP3 / WAV / OGG，最多 1 MiB，播放最多 10 秒',
    'choose': '选择音频',
    'builtin': '内置双音提示',
    'preview': '试听',
    'reset': '恢复内置提示音',
    'audioError': '音频格式、大小或播放失败，请选择有效音频。',
    'i2i': '记住图生图参数',
    'i2iHint': '跨次保存强度、噪声、随机种子与尺寸模式；不自动加载旧图片。',
  };
  return words[key] ?? key;
}
