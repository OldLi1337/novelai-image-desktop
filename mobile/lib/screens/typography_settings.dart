import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/ui_typography.dart';
import '../models/builtin_ui_fonts.dart';
import '../services/ui_fonts.dart';
import '../i18n/typography_text.dart';
import '../ui/studio_dropdown.dart';
class TypographySettings extends StatefulWidget {
  const TypographySettings({super.key});
  @override State<TypographySettings> createState()=>_TypographySettingsState();
}
class _TypographySettingsState extends State<TypographySettings> {
  List<UiFont> _fonts=[];
  String _message='';bool _busy=false;AppState? _owner;
  @override void didChangeDependencies(){super.didChangeDependencies();_owner=context.read<AppState>();}
  @override void dispose(){final owner=_owner;Future.microtask(()=>owner?.previewUiTypography(null));super.dispose();}
  @override void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {try{final items=await (await uiFontRepository()).list();if(mounted)setState(()=>_fonts=items);}catch(_){if(mounted)setState(()=>_message=typographyText(context.read<AppState>().settings.language)['failed']!);}}
  Future<void> _save(UiTypography value) async {
    setState(()=>_busy=true);final state=context.read<AppState>(),t=typographyText(state.settings.language);
    try{await state.setUiTypography(value);if(mounted)setState(()=>_message=t['saved']!);}catch(_){if(mounted)setState(()=>_message=t['failed']!);}finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context) {
    final state=context.watch<AppState>(),v=state.effectiveUiTypography,t=typographyText(state.settings.language);
    final missing=UiTypography.isImported(v.font)&&!uiFontLoaded(v.font);
    return Column(key:const ValueKey('typography-settings'),crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(t['title']!,style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:12),
      StudioDropdownButtonFormField<String>(value:v.font,isExpanded:true,decoration:InputDecoration(labelText:t['font'],border:const OutlineInputBorder()),items:[
        for(final id in ['default','sans','serif','mono'])DropdownMenuItem(value:id,child:Text(t[id]!)),
        for(final font in builtinUiFonts)DropdownMenuItem(value:font.id,child:Text(font.label(state.settings.language))),
        for(final font in _fonts)DropdownMenuItem(value:font.id,child:Text(font.name)),
        if(UiTypography.isImported(v.font)&&!_fonts.any((x)=>x.id==v.font))DropdownMenuItem(value:v.font,child:Text(t['missing']!)),
      ],onChanged:_busy?null:(font){if(font!=null)_save(v.copyWith(font:font));}),
      const SizedBox(height:12),Text('${t['scale']} · ${v.scale}%'),
      Text(_hierarchyHint(state.settings.language)),
      Slider(key:const ValueKey('typography-scale'),min:80,max:200,divisions:24,value:v.scale.toDouble(),label:'${v.scale}%',onChanged:_busy?null:(n)=>state.previewUiTypography(v.copyWith(scale:n.round())),onChangeEnd:(n)=>_save(v.copyWith(scale:n.round()))),
      Wrap(spacing:8,runSpacing:8,children:[
        OutlinedButton.icon(onPressed:_busy?null:()async{
          setState(()=>_busy=true);
          try{final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['ttf','otf']);if(result==null)return;
            final path=result.files.single.path;if(path==null)throw const FormatException('FONT_PATH');
            final entry=await (await uiFontRepository()).importFile(path);await state.setUiTypography(v.copyWith(font:entry.id));await _refresh();if(mounted)setState(()=>_message=t['saved']!);
          }catch(_){if(mounted)setState(()=>_message=t['failed']!);}finally{if(mounted)setState(()=>_busy=false);}
        },icon:const Icon(Icons.upload_file),label:Text('${t['import']} (TTF / OTF)')),
        if(UiTypography.isImported(v.font))OutlinedButton(onPressed:_busy?null:()async{setState(()=>_busy=true);try{await state.setUiTypography(v.copyWith(font:'default'));await (await uiFontRepository()).remove(v.font);await _refresh();}catch(_){if(mounted)setState(()=>_message=t['failed']!);}finally{if(mounted)setState(()=>_busy=false);}},child:Text(t['remove']!)),
        TextButton(onPressed:_busy?null:()=>_save(const UiTypography()),child:Text(t['reset']!)),
      ]),const SizedBox(height:12),
      Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(border:Border.all(color:Theme.of(context).dividerColor),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(t['default']!,style:Theme.of(context).textTheme.labelMedium),
        Text(t['preview']!,key:const ValueKey('typography-default-sample'),style:const TextStyle(fontFamily:'sans-serif')),
        const SizedBox(height:12),Text('${t['font']} · ${_fonts.where((f)=>f.id==v.font).map((f)=>f.name).firstOrNull ?? builtinUiFont(v.font)?.label(state.settings.language) ?? t[v.font] ?? v.font}',style:Theme.of(context).textTheme.labelMedium),
        Text(t['preview']!,key:const ValueKey('typography-current-sample')),const SizedBox(height:8),const Text('Prompt / Seed / CFG · 1girl, solo · 0123456789'),
        TextField(readOnly:true,minLines:1,maxLines:4,decoration:InputDecoration(hintText:t['preview'],border:const OutlineInputBorder())),
      ])),const SizedBox(height:8),Text(_familyHint(state.settings.language)),const SizedBox(height:8),Text(builtinUiFontHint(state.settings.language)),const SizedBox(height:8),Text(t['hint']!),if(missing)Text(t['missing']!),if(_message.isNotEmpty)Text(_message),
    ]);
  }
}

String _familyHint(String language) => '默认与无衬线字形接近属正常；导入字体若不含中文字形，中文会回退到系统字体。';

String _hierarchyHint(String language)=>'正文与提示词按完整比例放大；标题、导航和按钮温和放大，避免界面拥挤。';
