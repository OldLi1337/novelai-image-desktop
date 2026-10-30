import 'app_locales.dart';
String inpaintParityText(Object? language,String key){
 const labels={
 'zh-CN':{'select':'框选工作区域','return':'返回编辑','work':'工作尺寸','preserve':'保留原图尺寸；自定义尺寸保持不变','restoreError':'无法恢复原图与蒙版，当前编辑内容已保留。'},
 };
 return labels[normalizeAppLocaleCode(language)]?[key]??key;
}
