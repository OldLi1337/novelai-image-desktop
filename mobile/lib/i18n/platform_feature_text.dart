String platformFeatureText(String language,String key) {
  const zh=<String,String>{'customSize':'自定义尺寸（宽x高）','engine':'重绘引擎','edit':'OpenAI 图像编辑','configure':'配置','baseUrl':'接口地址','model':'模型',
    'key':'API 密钥','size':'请求尺寸','quality':'质量','fidelity':'输入保真度','save':'保存','saved':'已保存','saveFailed':'未保存，请检查配置。',
    'editBilling':'由服务商计费，不消耗 Anlas。只提交一次，失败不自动重试。','editRunning':'正在编辑图片…','editDone':'重绘图片已保存',
    'editStopped':'已停止。再次提交前请核对服务商记录。','editFailed':'重绘失败，未自动重发，请核对服务商记录。','historyFailed':'图片已保存，但历史索引失败，请勿重新提交。',
    'batchEdit':'批量编辑','selectAll':'选择筛选结果','clearSelection':'取消选择','move':'移动到分组','delete':'删除所选','done':'完成',
    'deleteConfirm':'删除所选图片及记录？外部导入的原文件会保留。','partialDelete':'部分文件删除失败，已保留对应记录。','refresh':'刷新',
    'cancel':'取消'};
  return zh[key]??key;
}
