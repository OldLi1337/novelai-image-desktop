import 'focused_inpaint.dart';

export 'focused_inpaint.dart';

typedef InpaintSize = ({int width, int height});

Map<String, String> inpaintSizeText(String language) => const {'title':'重绘尺寸','original':'原图尺寸','custom':'自定义尺寸','width':'宽','height':'高','missing':'请先加载原图。','rule':'宽高需为 64–1600 之间的 64 整数倍；不会自动修改尺寸。','output':'输出尺寸'};

InpaintSize resolveInpaintSize(String mode, InpaintSize custom, InpaintSize source, [String language = 'zh-CN']) {
  final size = mode == 'custom' ? custom : source;
  if ([size.width, size.height].any((v) => v < 64 || v > 1600 || v % 64 != 0)) {
    throw FormatException('${size.width}×${size.height}: ${inpaintSizeText(language)['rule']}');
  }
  return size;
}

({String mode, InpaintSize custom}) restoreInpaintSizeState(Map<String, dynamic> saved) {
  final raw = saved['inpaintCustomSize'];
  int dimension(dynamic v) => v is num && v.isFinite && v == v.round() && v >= 64 && v <= 1600 ? v.toInt() : 1024;
  return (mode: saved['inpaintSizeMode'] == 'custom' ? 'custom' : 'original',
    custom: (width: dimension(raw is Map ? raw['width'] : null), height: dimension(raw is Map ? raw['height'] : null)));
}

({InpaintSize outputSize,InpaintSize requestSize,InpaintRegion? region}) inpaintSizePlan(String mode,InpaintSize custom,InpaintSize source,{InpaintRegion? region,String language='zh-CN'}){
 if(region!=null){final plan=focusedInpaintPlan(region,source.width,source.height);return(outputSize:source,requestSize:plan.size,region:plan.region);}
 final size=resolveInpaintSize(mode,custom,source,language);return(outputSize:size,requestSize:size,region:null);
}
