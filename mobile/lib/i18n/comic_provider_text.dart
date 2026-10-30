String comicProviderText(Object? language, String key) {
  const texts = <String, String>{
    'title': '漫画 · 兼容图片服务',
    'rules':
        '每格发送“全局风格 + 分镜提示词”。统一尺寸使用图片服务配置，逐格尺寸使用分镜选择。仅发送服务中明确配置的扩展参数；不套用 NovelAI 模型、种子、采样器或负面提示词。',
    'references':
        '当前接口未接入参考图。已有参考配置保留；本批有启用参考时将停止，不会忽略参考偷偷生成。可移除/禁用本批参考，或切回 NovelAI。',
    'billing': '费用以图片服务商为准，不计为 0 Anlas；整批确认一次，失败停止，已保存图片保留。',
    'settings': '配置服务 / 切换模型',
  };
  return texts[key] ?? key;
}
