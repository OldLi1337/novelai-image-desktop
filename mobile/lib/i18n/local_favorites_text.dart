import 'app_locales.dart';

const _labels = <String, Map<String, String>>{
  'zh-CN': {
    'savedAt': '收藏时间',
    'generatedAt': '本机生成完成时间',
    'desc': '新到旧',
    'asc': '旧到新',
    'sortTimeNote': '未知时间排在最后；生成时间仅使用可核实的本机完成记录，不是官方服务器时间。',
    'title': '收藏夹',
    'local': '本地原图',
    'apply': '应用到生成',
    'online': '在线收藏',
    'directory': '保存目录',
    'choose': '更换目录',
    'date': '日期',
    'all': '全部',
    'layout': '布局',
    'grid': '网格',
    'masonry': '瀑布流',
    'size': '每页张数',
    'empty': '还没有收藏图片',
    'rename': '命名',
    'remove': '移出收藏',
    'save': '保存',
    'cancel': '取消',
    'add': '收藏图片',
    'added': '已收藏原图',
    'missing': '文件不存在',
    'error': '操作失败',
    'previous': '上一张',
    'next': '下一张',
    'noFolder': '此设备不支持选择该目录；原目录不变。'
  },
};

String localFavoritesText(Object? language, String key) =>
    _labels[normalizeAppLocaleCode(language)]?[key] ??
    _labels['zh-CN']![key] ??
    key;

String localFavoritesLabelFor(Object? language) =>
    localFavoritesText(language, 'title');
