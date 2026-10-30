import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/services/storage.dart';
import 'package:novelai_mobile/services/works_batch.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/state/app_state.dart';

class DiskHistory extends Storage {
 final Directory root;
 DiskHistory(this.root);
 @override Future<WorksBatchFiles> worksFiles() async => WorksBatchFiles([root]);
 @override Future<List<HistoryItem>> getHistory() async => (jsonDecode(await File('${root.path}/history.json').readAsString()) as List).map((x)=>HistoryItem.fromJson(Map<String,dynamic>.from(x))).toList();
 @override Future<void> writeHistory(List<HistoryItem> items) => File('${root.path}/history.json').writeAsString(jsonEncode(items.map((x)=>x.toJson()).toList()),flush:true).then((_){ });
}
HistoryItem item(String id,String file)=>HistoryItem(id:id,filePath:file,date:'2026-09-28',createdAt:'2026-09-28',seed:0,model:'fixture',width:1,height:1,prompt:'synthetic');
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory root;late DiskHistory storage;
 setUp(()async{root=Directory.systemTemp.createTempSync('studio-delete-delivery-');storage=DiskHistory(root);await storage.writeHistory([]);});
 tearDown(()=>root.deleteSync(recursive:true));
 test('invalid file type fails without removing the disk record',()async{
  final directory=Directory('${root.path}/not-an-image.png')..createSync();await storage.writeHistory([item('bad',directory.path)]);
  await expectLater(storage.deleteHistory('bad'),throwsA(isA<FileSystemException>()));expect((await storage.getHistory()).single.id,'bad');expect(directory.existsSync(),true);
 });
 test('missing file and valid file delete are both truthful',()async{
  final file=File('${root.path}/normal.png')..writeAsStringSync('synthetic');await storage.writeHistory([item('normal',file.path),item('gone','${root.path}/missing.png')]);
  await storage.deleteHistory('normal');expect(file.existsSync(),false);await storage.deleteHistory('gone');expect(await storage.getHistory(),isEmpty);
 });
 test('shared file is retained until its last record is deleted',()async{
  final file=File('${root.path}/shared.png')..writeAsStringSync('synthetic shared');await storage.writeHistory([item('one',file.path),item('two',file.path)]);
  await storage.deleteHistory('one');expect(file.readAsStringSync(),'synthetic shared');expect((await storage.getHistory()).single.id,'two');
 });
 test('failed storage deletion restores current selection and history in AppState',()async{
  final directory=Directory('${root.path}/bad.png')..createSync();final row=item('bad',directory.path);await storage.writeHistory([row]);final app=AppState(storage:storage);app.history.add(row);app.current=row;
  try{await expectLater(app.deleteHistory('bad'),throwsA(isA<FileSystemException>()));expect(app.current?.id,'bad');expect(app.history.single.id,'bad');expect((await storage.getHistory()).single.id,'bad');}finally{app.dispose();}
 });
}
