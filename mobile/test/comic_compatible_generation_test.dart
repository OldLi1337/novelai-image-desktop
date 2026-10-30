import 'package:http/testing.dart';
import 'package:novelai_mobile/services/novelai_image_envelope.dart';
import 'package:novelai_mobile/services/nai_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:novelai_mobile/screens/comic_screen.dart';
import 'package:novelai_mobile/i18n/comic_provider_text.dart';
import 'package:novelai_mobile/services/openai_images.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novelai_mobile/comic/comic_models.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/services/storage.dart';
import 'package:novelai_mobile/services/unified_storage.dart';
import 'package:novelai_mobile/state/app_state.dart';

class ComicPaths extends PathProviderPlatform {
  final String root;
  ComicPaths(this.root);
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

class ComicStorage extends Storage {
  int nativeReads = 0;
  bool failHistory = false;
  Future<void> Function()? onKey;
  @override
  Future<String?> getCompatibleImageKey(String id) async {
    await onKey?.call();
    return super.getCompatibleImageKey(id);
  }

  @override
  Future<void> writeHistory(List<HistoryItem> items) async {
    if (failHistory) throw StateError('fixture history full');
    await super.writeHistory(items);
  }

  @override
  Future<String?> getToken() async {
    nativeReads++;
    throw StateError('native credential must not be read');
  }
}

Future<void> fixtureVerifyEnvelope(AppSettings settings,Map<String,dynamic> config,String key) async {
 final client=MockClient((request)async {if(request.method!='GET'||!request.url.path.endsWith('/models'))throw StateError('Not readonly');return http.Response(jsonEncode({'data':[{'id':config['model']}]}),200);});
 try {await verifyNovelAiImageEnvelope(client,config,key);}finally{client.close();}
}
class _VerifiedFixtureApi extends NaiApi {@override Future<void> verifyCompatibleNovelAi(AppSettings s,Map<String,dynamic> c,String key)=>fixtureVerifyEnvelope(s,c,key);}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late HttpServer server;
  late AppState app;
  late ComicStorage storage;
  var posts = 0;
  final bodies = <Map<String, dynamic>>[];
  final bytes = img.encodePng(img.Image(width: 8, height: 6));
  const key = 'fixture-compatible-key';
  FutureOr<void> Function(HttpRequest)? handler;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    HttpOverrides.global = null;
    UnifiedStorage.active = null;
    root = await Directory.systemTemp.createTemp('comic-compatible-');
    PathProviderPlatform.instance = ComicPaths(root.path);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    posts = 0;
    bodies.clear();
    handler = null;
    server.listen((req) async {
      if (req.method == 'POST') {
        posts++;
        expect(req.uri.path, '/v1/images/generations');
        expect(req.headers.value('authorization'), 'Bearer $key');
        bodies.add(Map<String, dynamic>.from(
            jsonDecode(await utf8.decoder.bind(req).join())));
      }
      if (handler != null) {
        await handler!(req);
        return;
      }
      req.response.write(jsonEncode({
        'data': [
          {'b64_json': base64Encode(bytes)}
        ]
      }));
      await req.response.close();
    });
    storage = ComicStorage();
    app = AppState(api:_VerifiedFixtureApi(),storage: storage, preloadCompletedImage: (_) async {})
      ..settings = AppSettings(proxyMode: 'direct', saveToGallery: false);
    await storage.setSettings(app.settings);
    await app.saveCompatibleSettings({
      'baseUrl': 'http://127.0.0.1:${server.port}/v1',
      'model': 'nai-diffusion-5-full',
      'size': '1024x1024',
      'responseFormat': 'auto',
      'extensions': <String, dynamic>{}
    }, key);
    await app.comic.load();
    app.comic.project
      ..title = 'comic fixture'
      ..globalStylePrompt = 'ink'
      ..panels = [
        for (var i = 0; i < 2; i++)
          ComicPanel(
              id: 'p$i', index: i + 1, title: 'panel $i', prompt: 'forest $i')
      ];
    await app.comic.flush();
  });
  tearDown(() async {
    app.dispose();
    await server.close(force: true);
    await root.delete(recursive: true);
  });
  test(
      'baseline software comic queue uses saved compatible service without native credentials',
      () async {
    await app.comic.generateInitial();
    expect(app.comic.runPhase, 'completed', reason: app.comic.runError);
    expect(posts, 2);
    expect(storage.nativeReads, 0);
    expect(app.comic.project.panels.map((p) => p.candidates.length), [1, 1]);
    expect(bodies.first, {
      'model': 'nai-diffusion-5-full',
      'prompt': 'ink, forest 0',
      'size': '1024x1024',
      'n': 1
    });
  });

  Future<void> imageResponse(HttpRequest req, {int count = 1}) async {
    req.response.write(jsonEncode({
      'data': [
        for (var i = 0; i < count; i++) {'b64_json': base64Encode(bytes)}
      ]
    }));
    await req.response.close();
  }

  test(
      'compatible quote is unknown and explicit per-panel sizes plus extensions are sent',
      () async {
    app.comic.project
      ..sizeMode = ComicSizeMode.perPanel
      ..globalNegativePrompt = 'NATIVE NEGATIVE';
    app.comic.project.globalParams
      ..seed = 55
      ..steps = 28;
    for (final panel in app.comic.project.panels) {
      panel
        ..imageWidth = 832
        ..imageHeight = 1216;
    }
    app.settings.compatibleImage['extensions'] = {
      'negative_prompt': 'configured negative',
      'steps': 17,
      'seed': 123
    };
    expect(await app.comic.quoteTasks(app.comic.project.panels), isNull);
    expect(posts, 0);
    expect(storage.nativeReads, 0);
    await app.comic.generateInitial();
    expect(app.comic.runPhase, 'completed');
    expect(bodies.first, {
      'model': 'nai-diffusion-5-full',
      'prompt': 'ink, forest 0',
      'size': '832x1216',
      'n': 1,
      'negative_prompt': 'configured negative',
      'steps': 17,
      'seed': 123
    });
  });
  test(
      'invalid later panel or enabled references reject the entire batch before first POST',
      () async {
    final file = File('${root.path}/reference.png');
    await file.writeAsBytes(bytes);
    app.comic.project.preciseReferences
        .add(ComicReferenceAsset(id: 'r', name: 'r', filePath: file.path));
    await app.comic.generateInitial();
    expect(app.comic.runPhase, 'failed');
    expect(posts, 0);
    app.comic.project.preciseReferences.clear();
    app.comic.project.panels.last.prompt = '';
    await expectLater(app.comic.generateInitial(), throwsFormatException);
    expect(posts, 0);
  });
  test(
      'service changes after an accepted first request retain its image and prevent the next POST',
      () async {
    handler = (req) async {
      app.settings.compatibleImage['model'] = 'new service';
      await imageResponse(req);
    };
    await app.comic.generateInitial();
    expect(posts, 1);
    expect(app.comic.runPhase, 'failed');
    expect(app.comic.project.panels.first.candidates, hasLength(1));
    expect(app.comic.project.panels.last.candidates, isEmpty);
    expect(
        File(app.comic.project.panels.first.candidates.single.outputPath)
            .existsSync(),
        true);
  });
  test('credential-loading race stops before queue submit', () async {
    var reads = 0;
    storage.onKey = () async {
      if (++reads == 2) {
        app.settings.compatibleImage['credentialId'] = 'changed-key-version';
      }
    };
    await app.comic.generateInitial();
    expect(posts, 0);
    expect(app.comic.runPhase, 'failed');
    expect(app.busy, false);
  });
  test(
      'final transport guard runs after async client setup and reports no submitted POST',
      () async {
    var changed = false;
    final batch = await generateCompatibleImages(
        CompatibleImageConfig(
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            model: 'test',
            apiKey: key),
        prompt: 'forest',
        size: 'auto',
        n: 1, clientForUri: (uri) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      changed = true;
      return http.Client();
    }, beforeSubmit: () {
      if (changed) throw StateError('changed before socket send');
    });
    expect(batch.complete, false);
    expect(batch.submitted, false);
    expect(posts, 0);
  });
  test(
      'HTTP rejection stops without retry and does not expose server secret text',
      () async {
    handler = (req) async {
      req.response.statusCode = 429;
      req.response.write('private error $key');
      await req.response.close();
    };
    await app.comic.generateInitial();
    expect(posts, 1);
    expect(app.comic.runPhase, 'failed');
    expect(app.comic.runError, contains('429'));
    expect(app.comic.runError, isNot(contains(key)));
    expect(app.comic.project.panels.expand((p) => p.candidates), isEmpty);
  });
  test(
      'URL images download without Authorization and remain in same project group',
      () async {
    handler = (req) async {
      if (req.method == 'POST') {
        req.response.write(jsonEncode({
          'data': [
            {'url': 'http://127.0.0.1:${server.port}/image'}
          ]
        }));
      } else {
        expect(req.headers.value('authorization'), isNull);
        req.response.add(bytes);
      }
      await req.response.close();
    };
    await app.comic.generateInitial();
    expect(posts, 2);
    expect(app.comic.runPhase, 'completed');
    expect(app.history, hasLength(2));
    expect(app.history.map((i) => i.groupId).toSet(),
        {app.comic.project.historyGroupId});
    expect(
        app.history
            .every((i) => i.model == 'nai-diffusion-5-full' && i.seed == -1),
        true);
  });
  test(
      'unexpected extra valid images are all retained and the next request is not submitted',
      () async {
    handler = (req) => imageResponse(req, count: 2);
    await app.comic.generateInitial();
    expect(posts, 1);
    expect(app.comic.runPhase, 'failed');
    expect(app.comic.project.panels.first.candidates, hasLength(2));
    expect(app.history, hasLength(2));
    for (final c in app.comic.project.panels.first.candidates) {
      expect(File(c.outputPath).existsSync(), true);
    }
  });
  test('disk history failure retains saved candidate and stops later panels',
      () async {
    handler = (req) async {
      storage.failHistory = true;
      await imageResponse(req);
    };
    await app.comic.generateInitial();
    expect(posts, 1);
    expect(app.comic.runPhase, 'failed');
    expect(app.comic.project.panels.first.candidates, hasLength(1));
    expect(
        File(app.comic.project.panels.first.candidates.single.outputPath)
            .existsSync(),
        true);
    expect((await storage.getComicProject(app.params)).panels.first.candidates,
        hasLength(1));
  });
  test(
      'compatible confirmation stamp changes with output settings and secure credential version',
      () async {
    final first = await app.comic.authorizationStamp();
    app.settings.saveToGallery = true;
    expect(await app.comic.authorizationStamp(), isNot(first));
    app.settings.saveToGallery = false;
    await app.saveCompatibleSettings(
        Map<String, dynamic>.from(app.settings.compatibleImage), 'rotated');
    expect(await app.comic.authorizationStamp(), isNot(first));
    expect(storage.nativeReads, 0);
  });
  test('comic provider notice has Chinese text for every key', () {
    for (final k in ['title', 'rules', 'references', 'billing', 'settings']) {
      expect(comicProviderText('zh-CN', k), isNot(k));
    }
  });
  testWidgets(
      'comic UI no longer exposes the retired independent image provider',
      (tester) async {
    app.comic.step = ComicStep.generate;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(home: ComicScreen(controller: app.comic))));
    await tester.pumpAndSettle();
    expect(find.text(comicProviderText(app.settings.language, 'title')),
        findsNothing);
    expect(find.text('fixture-image-model · 1024x1024'), findsNothing);
    expect(posts, 0);
    expect(storage.nativeReads, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
