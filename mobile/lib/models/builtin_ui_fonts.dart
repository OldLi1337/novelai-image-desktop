/// Offline catalog; stable IDs and original font bytes match desktop.
class BuiltinUiFont {
  final String id,name,style,file;
  const BuiltinUiFont(this.id,this.name,this.style,this.file);
  String label(String language)=>'$name · $style';
}
const builtinUiFonts=<BuiltinUiFont>[
  BuiltinUiFont("builtin-wenkai","霞鹜文楷 轻便版","文雅楷书","LXGWWenKaiLite-Regular.ttf"),
  BuiltinUiFont("builtin-xiaolai","小赖字体","圆润手写","Xiaolai-Regular.ttf"),
  BuiltinUiFont("builtin-yozai","悠哉字体","随性手写","Yozai-Regular.ttf"),
  BuiltinUiFont("builtin-marker","霞鹜漫黑","漫画马克笔","LXGWMarkerGothic-Regular.ttf"),
  BuiltinUiFont("builtin-smiley","得意黑","倾斜美术黑体","SmileySans-Oblique.ttf"),
  BuiltinUiFont("builtin-source-serif","思源宋体 CN","文艺宋体","SourceHanSerifCN-Regular.otf"),
 ];
BuiltinUiFont? builtinUiFont(String id) {
  for(final font in builtinUiFonts){if(font.id==id)return font;}return null;
}
String builtinUiFontHint(String language)=>'内置风格字体可离线使用，不占导入名额；缺字使用系统字体。得意黑偏美术风格，长篇阅读建议文楷或宋体。';
