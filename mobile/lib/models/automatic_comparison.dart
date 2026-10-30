const comparisonSurfaces=['generate:t2i','generate:i2i','generate:enhance','inpaint','postprocess:upscale','postprocess:director'];
bool automaticComparisonAllowed(String surface)=>comparisonSurfaces.contains(surface)&&surface!='generate:t2i';
Map<String,bool> normalizeAutomaticComparison(dynamic value)=>{for(final key in comparisonSurfaces) key:automaticComparisonAllowed(key)&&(value is Map && value[key] is bool ? value[key] as bool : true)};
List<String> comparisonLabels(String language)=>
 const ['自动对比','完成后自动打开对比；关闭后仍可手动查看。','查看对比','关闭对比','角色名称'];
