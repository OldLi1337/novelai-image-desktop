// Shared wording with src/typography.ts.
const typographyLabels = <String,Map<String,String>> {
  "zh-CN": {
    "title": "全局字体与字号",
    "font": "字体",
    "default": "软件默认",
    "sans": "无衬线",
    "serif": "衬线 / 宋体",
    "mono": "等宽",
    "scale": "全局字号缩放",
    "import": "导入字体",
    "remove": "移除当前导入字体",
    "reset": "恢复默认字体与字号",
    "preview": "预览：中文 English 日本語 한국어 0123456789",
    "hint": "适用于软件内所有文字（含提示词、对话和参数）；系统原生窗口遵循系统设置。支持 TTF / OTF，每个最多 20 MiB；字体保存在本机，不修改原字体文件。",
    "failed": "操作失败，原设置保持不变。",
    "missing": "导入字体不可用，暂时使用默认字体；请重新导入。",
    "saved": "已保存"
  },
};
Map<String,String> typographyText(String language)=>typographyLabels[language]??typographyLabels["zh-CN"]!;
