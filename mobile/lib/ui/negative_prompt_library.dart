import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../state/app_state.dart';
import '../prompts/negative_prompt_library.dart';
import '../prompts/prompt_library_tags.dart';
import 'prompt_library_bar.dart';
import 'prompt_tag_controls.dart';

/// [tagFilter] is the filter selected the last time this field's library was open; [onTagFilterChanged] reports changes so the next opening keeps it.
Future<(String,String)?> _openLibrary(BuildContext context,{required String value,required String tagFilter,required ValueChanged<String> onTagFilterChanged,bool createFromCurrent=false})=>showDialog<(String,String)>(context:context,builder:(_)=>_LibraryDialog(current:value,tagFilter:tagFilter,onTagFilterChanged:onTagFilterChanged,createFromCurrent:createFromCurrent));

class NegativePromptLibraryButton extends StatefulWidget {
 final String value;final void Function(String prompt,String mode) onApply;
 const NegativePromptLibraryButton({super.key,required this.value,required this.onApply});
 @override State<NegativePromptLibraryButton> createState()=>_NegativePromptLibraryButtonState();
}
class _NegativePromptLibraryButtonState extends State<NegativePromptLibraryButton> {
 // Kept while the button lives, like the desktop library's selected tag.
 String tagFilter='';
 @override Widget build(BuildContext context){final text=negativeLibraryLabels(context.watch<AppState>().settings.language);
  return IconButton(icon:const Icon(Icons.library_books_outlined),tooltip:text[0],onPressed:()async{
   final result=await _openLibrary(context,value:widget.value,tagFilter:tagFilter,onTagFilterChanged:(value)=>tagFilter=value);
   if(mounted&&result!=null)widget.onApply(result.$1,result.$2);
  });
 }
}
/// Library actions that stay visible under the negative prompt, as on the desktop app: 负面提示词库 and 保存当前 (straight into a new entry made from the prompt).
class NegativePromptLibraryBar extends StatefulWidget {
 final String value;final void Function(String prompt,String mode) onApply;
 const NegativePromptLibraryBar({super.key,required this.value,required this.onApply});
 @override State<NegativePromptLibraryBar> createState()=>_NegativePromptLibraryBarState();
}
class _NegativePromptLibraryBarState extends State<NegativePromptLibraryBar> {
 // Kept while the bar lives, like the desktop library's selected tag.
 String tagFilter='';
 Future<void> open({bool createFromCurrent=false})async{
  final result=await _openLibrary(context,value:widget.value,tagFilter:tagFilter,onTagFilterChanged:(value)=>tagFilter=value,createFromCurrent:createFromCurrent);
  if(mounted&&result!=null)widget.onApply(result.$1,result.$2);
 }
 @override Widget build(BuildContext context){final text=negativeLibraryLabels(context.watch<AppState>().settings.language);
  return PromptLibraryBar(semanticLabel:text[15],actions:[
   (key:const ValueKey('negative-library-open'),icon:Icons.library_books_outlined,label:text[0],onPressed:open),
   (key:const ValueKey('negative-library-save-current'),icon:Icons.push_pin_outlined,label:text[3],onPressed:widget.value.trim().isEmpty?null:()=>open(createFromCurrent:true)),
  ]);
 }
}
class _LibraryDialog extends StatefulWidget {
 final String current;final String tagFilter;final ValueChanged<String> onTagFilterChanged;final bool createFromCurrent;
 const _LibraryDialog({required this.current,required this.tagFilter,required this.onTagFilterChanged,this.createFromCurrent=false});
 @override State<_LibraryDialog> createState()=>_LibraryDialogState();
}
class _LibraryDialogState extends State<_LibraryDialog> {
 String query='',selectedId='',error='';bool busy=false;Map<String,Object>? draft;
 late String tagFilter=widget.tagFilter;
 final name=TextEditingController(),prompt=TextEditingController(),tags=TextEditingController();
 @override void initState(){super.initState();if(widget.createFromCurrent)begin(context.read<AppState>().settings.negativePromptPresets,true);}
 @override void dispose(){name.dispose();prompt.dispose();tags.dispose();super.dispose();}
 String id()=>'negative-${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1<<30)}';
 void setTagFilter(String value){tagFilter=value;widget.onTagFilterChanged(value);}
 void edit(Map<String,Object> entry){setState((){draft={...entry};name.text=entry['name'] as String;prompt.text=entry['prompt'] as String;tags.text=formatPromptTagInput(negativePresetTags(entry));error='';});}
 // 保存当前 on the library bar opens the editor directly, with the filter remembered from an earlier opening: a tag removed since then is dropped, not pre-filled.
 void begin(List<Map<String,Object>> entries,bool current){if(isStalePromptTagFilter([for(final p in entries)negativePresetTags(p)],tagFilter))setTagFilter('');draft={'id':id(),'name':'','prompt':current?widget.current:'','createdAt':DateTime.now().toUtc().toIso8601String()};name.text='';prompt.text=current?widget.current:'';tags.text=tagFilter.isNotEmpty&&tagFilter!=untaggedPromptFilter?tagFilter:'';error='';}
 void create(List<Map<String,Object>> entries,bool current)=>setState(()=>begin(entries,current));
 Future<void> run(Future<void> Function() action)async{setState((){busy=true;error='';});try{await action();}catch(e){if(mounted)setState(()=>error='$e');}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> save()async{if(draft==null||name.text.trim().isEmpty||prompt.text.trim().isEmpty)return;final entry=<String,Object>{...draft!,'name':name.text.trim(),'prompt':prompt.text}..remove('tags')..addAll(promptTagField(tags.text));await context.read<AppState>().mutateNegativePresets((old)=>old.any((p)=>p['id']==entry['id'])?old.map((p)=>p['id']==entry['id']?entry:p).toList():mergeNegativeLibrary(old,[entry],id));if(mounted)setState((){selectedId=entry['id'] as String;draft=null;});}
 Future<void> importFile()async{
  final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true);
  if(result==null)return;final picked=result.files.single;if(picked.size>5000000)throw const FormatException('Library file exceeds 5 MB');
  final raw=picked.bytes!=null?String.fromCharCodes(picked.bytes!):await File(picked.path!).readAsString();
  // File.readAsString uses UTF-8; decode byte-based picker results identically.
  final imported=parseNegativeLibrary(picked.bytes!=null?decodeNegativeFile(picked.bytes!):raw);
  if(!mounted)return;await context.read<AppState>().mutateNegativePresets((old)=>mergeNegativeLibrary(old,imported,id));
 }
 Future<void> exportFile()async{
  final entries=context.read<AppState>().settings.negativePromptPresets;
  final dir=await getTemporaryDirectory();final file=File('${dir.path}/negative-prompt-library-${DateTime.now().microsecondsSinceEpoch}.json');await file.writeAsString(exportNegativeLibrary(entries));
  if(!mounted)return;final box=context.findRenderObject();final origin=box is RenderBox?box.localToGlobal(Offset.zero)&box.size:const Rect.fromLTWH(0,0,1,1);
  await Share.shareXFiles([XFile(file.path,mimeType:'application/json')],sharePositionOrigin:origin);
 }
 Future<void> remove(Map<String,Object> entry,List<String> t)async{
  final confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(t[6]),content:Text(t[19]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(t[13])),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(t[6]))]));
  if(confirmed!=true||!mounted)return;await context.read<AppState>().mutateNegativePresets((old)=>old.where((p)=>p['id']!=entry['id']).toList());
 }
 @override Widget build(BuildContext context){final state=context.watch<AppState>(),t=negativeLibraryLabels(state.settings.language),entries=state.settings.negativePromptPresets;
  final tagLists=[for(final p in entries)negativePresetTags(p)];
  // A selected tag whose last entry was deleted or untagged resets the filter, so a hidden filter never makes the library look empty.
  if(isStalePromptTagFilter(tagLists,tagFilter))setTagFilter('');
  final tagSuggestions=[for(final item in collectPromptTags(tagLists))item.tag];
  final filtered=entries.where((p)=>matchesPromptLibraryEntry(negativePresetTags(p),[p['name'] as String,p['prompt'] as String],query,tagFilter)).toList();
  final selected=filtered.where((p)=>p['id']==selectedId).firstOrNull??filtered.firstOrNull;
  final list=Card(margin:EdgeInsets.zero,child:ListView(children:[if(filtered.isEmpty)Padding(padding:const EdgeInsets.all(16),child:Text(t[16])),for(final p in filtered)ListTile(key:ValueKey('negative-preset-item-${p['id']}'),selected:p['id']==selected?['id'],isThreeLine:negativePresetTags(p).isNotEmpty,title:Text(p['name'] as String),subtitle:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p['prompt'] as String,maxLines:1,overflow:TextOverflow.ellipsis),PromptTagList(negativePresetTags(p),singleLine:true)]),onTap:busy||draft!=null?null:()=>setState(()=>selectedId=p['id'] as String))]));
  final detail=Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   if(draft!=null)Expanded(child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    TextField(controller:name,enabled:!busy,maxLength:100,decoration:InputDecoration(labelText:t[14])),const SizedBox(height:8),
    TextField(controller:prompt,enabled:!busy,maxLength:100000,minLines:5,maxLines:12,textAlignVertical:TextAlignVertical.top,decoration:InputDecoration(labelText:t[15],alignLabelWithHint:true)),const SizedBox(height:8),
    PromptTagInput(controller:tags,suggestions:tagSuggestions,enabled:!busy),const SizedBox(height:8),
    Wrap(alignment:WrapAlignment.end,spacing:8,children:[TextButton(onPressed:busy?null:()=>setState(()=>draft=null),child:Text(t[13])),FilledButton(onPressed:busy?null:()=>run(save),child:Text(t[12]))]),
   ])))else if(selected!=null) ...[
    Wrap(alignment:WrapAlignment.spaceBetween,spacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[Text(selected['name'] as String,style:Theme.of(context).textTheme.titleMedium),TextButton.icon(onPressed:busy?null:()=>edit(selected),icon:const Icon(Icons.edit_outlined),label:Text(t[5])),TextButton.icon(onPressed:busy?null:()=>run(()=>remove(selected,t)),icon:const Icon(Icons.delete_outline),label:Text(t[6]))]),
    PromptTagList(negativePresetTags(selected)),
    Expanded(child:SingleChildScrollView(padding:const EdgeInsets.all(12),child:SelectableText(selected['prompt'] as String))),
    Wrap(alignment:WrapAlignment.end,spacing:8,children:[OutlinedButton(onPressed:busy?null:()=>Navigator.pop(context,(selected['prompt'] as String,'append')),child:Text(t[10])),FilledButton(onPressed:busy?null:()=>Navigator.pop(context,(selected['prompt'] as String,'replace')),child:Text(t[9]))]),
   ]else Expanded(child:Center(child:Text(t[16]))),
  ]);
  // The tag chips scroll with the list so the fixed header keeps its height on small screens and large text.
  final chips=draft!=null?const SizedBox.shrink():PromptTagFilter(entries:tagLists,value:tagFilter,onChanged:(value)=>setState(()=>setTagFilter(value)),padding:const EdgeInsets.only(bottom:8));
  final size=MediaQuery.sizeOf(context);
  final listHeight=tagLists.any((tags)=>tags.isNotEmpty)?136.0:96.0;
  return PopScope(canPop:!busy,child:Dialog(child:SizedBox(width:math.min(1000,size.width-32),height:size.height*.88,child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Row(children:[Expanded(child:Text(t[0],style:Theme.of(context).textTheme.titleLarge)),IconButton(tooltip:t[11],onPressed:busy?null:()=>Navigator.pop(context),icon:const Icon(Icons.close))]),Text(t[1]),const SizedBox(height:8),
   TextField(decoration:InputDecoration(labelText:t[2],hintText:promptTagText.searchHint,prefixIcon:const Icon(Icons.search)),onChanged:(v)=>setState(()=>query=v)),
   Wrap(spacing:8,runSpacing:4,children:[TextButton(onPressed:busy?null:()=>create(entries,false),child:Text(t[4])),TextButton(onPressed:busy||widget.current.trim().isEmpty?null:()=>create(entries,true),child:Text(t[3])),TextButton(onPressed:busy?null:()=>run(importFile),child:Text(t[7])),TextButton(onPressed:busy?null:()=>run(exportFile),child:Text(t[8]))]),
   if(error.isNotEmpty)Text(error,style:TextStyle(color:Theme.of(context).colorScheme.error)),if(busy)const LinearProgressIndicator(),const SizedBox(height:8),
   Expanded(child:LayoutBuilder(builder:(context,box)=>box.maxWidth>=650?Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[SizedBox(width:220,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[chips,Expanded(child:list)])),const SizedBox(width:16),Expanded(child:detail)]):SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[chips,SizedBox(height:listHeight,child:list),const SizedBox(height:8),SizedBox(height:math.max(320,box.maxHeight-listHeight-8),child:detail)])))),
  ])))));
 }
}
