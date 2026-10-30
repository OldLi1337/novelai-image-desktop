class MetadataRecoveryText {
  final String label, online, offline, onlineInfo, offlineInfo, onlineFailure, retry;
  const MetadataRecoveryText(this.label, this.online, this.offline,
      this.onlineInfo, this.offlineInfo, this.onlineFailure, this.retry);
}

MetadataRecoveryText metadataRecoveryText(Object? language) =>
    const MetadataRecoveryText(
        '原数据恢复方式',
        '联网：官方解析器（默认）',
        '离线：本机解析器',
        '联网只下载官方解析器；图片在本机读取，不上传。PNG / WebP 可联网，JPEG 请明确选择离线。',
        '离线读取：不发送网络请求、不调用 AI、不消耗 Anlas。',
        '联网恢复失败，未切换离线。请重试或明确选择离线。',
        '重试');
