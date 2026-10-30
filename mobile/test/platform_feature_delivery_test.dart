import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as im;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novelai_mobile/services/storage.dart';
import 'package:novelai_mobile/services/unified_storage.dart';
import 'package:novelai_mobile/screens/gallery_screen.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/state/app_state.dart';

class Paths extends PathProviderPlatform {
  final String root;
  Paths(this.root);
  @override Future<String?> getApplicationDocumentsPath() async=>root;
  @override Future<String?> getApplicationSupportPath() async=>root;
  @override Future<String?> getTemporaryPath() async=>root;
}
HistoryItem item(String id,String path)=>HistoryItem(id:id,filePath:path,date:'2026-10-11',createdAt:'2026-10-11',seed:1,model:'fixture',width:32,height:32,prompt:'blue coat');

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;late Storage storage;late AppState app;
  late File source,mask;final servers=<HttpServer>[];
  setUp(() async {
    HttpOverrides.global=null;
    root=await Directory.systemTemp.createTemp('five-port-delivery-');
    PathProviderPlatform.instance=Paths(root.path);
    UnifiedStorage.active=null;
    SharedPreferences.setMockInitialValues({});FlutterSecureStorage.setMockInitialValues({});
    storage=Storage();app=AppState(storage:storage,preloadCompletedImage:(_) async {})
      ..settings=AppSettings(proxyMode:'direct',saveToGallery:false);
    await storage.setSettings(app.settings);
    final pixels=im.Image(width:32,height:32,numChannels:4);
    im.fill(pixels,color:im.ColorRgba8(220,30,30,255));pixels.textData={'Comment':jsonEncode({'prompt':'blue coat','seed':123})};
    source=File('${root.path}/source.png');await source.writeAsBytes(im.encodePng(pixels));
    final selected=im.Image(width:32,height:32,numChannels:4);
    im.fillRect(selected,x1:12,y1:12,x2:19,y2:19,color:im.ColorRgba8(255,255,255,255));
    mask=File('${root.path}/mask.png');await mask.writeAsBytes(im.encodePng(selected));
  });
  tearDown(() async {
    app.dispose();for(final s in servers){await s.close(force:true);}servers.clear();
    await Future<void>.delayed(const Duration(milliseconds:30));
    await root.delete(recursive:true);
  });
  Future<String> serve(Future<void> Function(HttpRequest) handler) async {
    final s=await HttpServer.bind(InternetAddress.loopbackIPv4,0);servers.add(s);s.listen(handler);return 'http://127.0.0.1:${s.port}/v1';
  }
  Future<void> config(String url) async {
    await app.saveOpenAIEditSettings({'baseUrl':url,'model':'fixture-edit','size':'32x32','quality':'auto','inputFidelity':''},'fixture-edit-secret','');
    app.inpaintEngine='openai';app.inpaintSourceMode='latest';app.inpaintPositivePrompt='blue helmet';
    await app.setWorkbenchPath(source.path);
  }
  test('independent edit secure key survives reopening without changing native provider',() async {
    await config('https://example.test/v1');
    final fresh=await Storage().getSettings();
    expect(fresh.imageProvider,'novelai');expect(fresh.compatibleImage,isEmpty);
    expect(await storage.getOpenAIEditKey(fresh.openAIEdit['credentialId']),'fixture-edit-secret');
    expect(jsonEncode(fresh.toJson()),isNot(contains('fixture-edit-secret')));
    await expectLater(app.saveOpenAIEditSettings(fresh.openAIEdit,'another-key','stale-id'),throwsStateError);
    expect((await storage.getSettings()).openAIEdit['credentialId'],fresh.openAIEdit['credentialId']);
  });
  for(final status in [200,422]){
    test('actual AppState edit $status submits once and never uses a native token',() async {
      var posts=0;
      final url=await serve((r) async {
        expect(r.method,'POST');expect(r.uri.path,'/v1/images/edits');posts++;
        expect(r.headers.value('authorization'),'Bearer fixture-edit-secret');
        await r.drain<void>();r.response.statusCode=status;
        final out=im.Image(width:32,height:32);im.fill(out,color:im.ColorRgb8(0,0,255));
        r.response.write(status==200?jsonEncode({'data':[{'b64_json':base64Encode(im.encodePng(out))}]}):'fixture rejected');await r.response.close();
      });
      await config(url);await app.inpaint(await mask.readAsBytes());
      expect(posts,1);expect(app.busy,isFalse);expect(await storage.getToken(),isNull);
      expect(app.history.length,status==200?1:0);
      if(status==200){final row=app.history.single;expect(row.feature,'openai-inpaint');
        final saved=im.decodePng(await File(row.filePath).readAsBytes())!;
        expect([saved.getPixel(0,0).r,saved.getPixel(0,0).g,saved.getPixel(0,0).b],[220,30,30]);
        expect(jsonEncode(row.toJson()),isNot(contains('fixture-edit-secret')));
        expect(app.comparisonBefore?.filePath,source.path);
      }
    });
  }
  test('real Storage batch move/delete/reconcile commits and invalidates another cache',() async {
    final images=await storage.imagesDir(),a=File('${images.path}/a.png'),b=File('${images.path}/b.png');
    await a.writeAsBytes(await source.readAsBytes());await b.writeAsBytes(await source.readAsBytes());
    await storage.writeGroups(const [HistoryGroup(id:'group',name:'Group',createdAt:'2026-10-11')]);
    await storage.writeHistory([item('a',a.path),item('b',b.path),item('external',source.path)]);
    app.history=await storage.getHistory();app.groups=await storage.getGroups();app.current=app.history.first;
    final other=Storage();expect((await other.getHistory()).length,3);
    await app.moveHistoryItems({'a','b'},'group');
    expect((await other.getHistory()).take(2).every((h)=>h.groupId=='group'),isTrue);
    await app.setWorkbenchPath(a.path);
    final removed=await app.deleteHistoryItems({'a','external'});expect(removed.removedIds,{'a','external'});
    expect(await a.exists(),isFalse);expect(await source.exists(),isTrue);expect(app.workbenchImage,isNull);
    await b.delete();app.booted=true;await app.reconcileMissingHistory();
    expect(app.history,isEmpty);expect(await other.getHistory(),isEmpty);
  });
  for(final width in [360.0,390.0]){
    testWidgets('batch controls fit phone width $width at 200 percent text', (tester) async {
      tester.view.devicePixelRatio=1;tester.view.physicalSize=Size(width,800);addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider.value(value:app,child:MaterialApp(home:MediaQuery(data:MediaQueryData(size:Size(width,800),textScaler:const TextScaler.linear(2)),child:const GalleryScreen()))));
      await tester.tap(find.byKey(const ValueKey('works-batch-edit')));await tester.pump();
      expect(find.text('选择筛选结果'),findsOneWidget);expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
