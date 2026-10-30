import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/services/data_backup_service.dart';
import 'package:novelai_mobile/services/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BackupPathProvider extends PathProviderPlatform {
  final String root;
  _BackupPathProvider(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

class _BackupStorage extends Storage {
  @override
  Future<String?> getToken() async => '';
  @override
  Future<String?> getVisionKey() async => '';
  @override
  Future<String?> getConvertKey() async => '';
  @override
  Future<String?> getTagKey() async => '';
  @override
  Future<String?> getBaiduSecret() async => '';

  @override
  Future<void> setToken(String value) async {}
  @override
  Future<void> setVisionKey(String value) async {}
  @override
  Future<void> setConvertKey(String value) async {}
  @override
  Future<void> setTagKey(String value) async {}
  @override
  Future<void> setBaiduSecret(String value) async {}
}

HistoryItem _item(String id, String path, int seed) => HistoryItem(
      id: id,
      filePath: path,
      date: '2026-08-30',
      createdAt: '2026-08-30T12:00:00.000Z',
      seed: seed,
      model: 'nai-diffusion-5-full',
      width: 832,
      height: 1216,
      prompt: 'test',
      params: GenerateParams(seed: seed).toJson(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late _BackupStorage storage;
  late DataBackupService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('data-backup-test-');
    PathProviderPlatform.instance = _BackupPathProvider(root.path);
    SharedPreferences.setMockInitialValues({});
    storage = _BackupStorage();
    service = DataBackupService(storage);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('public backup API preserves desktop native capsules through mobile',
      () async {
    final supplied = Platform.environment['STUDIO_PORTABLE_INTEROP'];
    final interop = supplied ?? root.path;
    if (supplied == null) {
      final bytes = utf8.encode('{"synthetic":true}');
      final inner = Archive();
      inner.addFile(
          ArchiveFile('files/runs/result.json', bytes.length, bytes));
      final manifest = utf8.encode(jsonEncode({
        'version': 1,
        'kind': 'detective',
        'files': [
          {
            'name': 'runs/result.json',
            'bytes': bytes.length,
            'hash': sha256.convert(bytes).toString()
          }
        ],
        'omitted': []
      }));
      inner.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
      final capsule = ZipEncoder().encode(inner);
      final outer = Archive();
      outer.addFile(ArchiveFile(
          'portable-projects/detective-${sha256.convert(capsule)}.zip',
          capsule.length,
          capsule));
      final old = utf8.encode(jsonEncode({
        'format': DataBackupService.format,
        'version': 1,
        'categories': [
          {'category': 'styleLab', 'items': 0, 'bytes': 0}
        ]
      }));
      outer.addFile(ArchiveFile('manifest.json', old.length, old));
      await File('$interop/desktop.naisbackup')
          .writeAsBytes(ZipEncoder().encode(outer));
    }
    final inspected = await service.inspect('$interop/desktop.naisbackup');
    expect(
        inspected.categories.any(
            (c) => c.category == DataBackupCategory.styleLab && c.items > 0),
        true);
    final selected = {DataBackupCategory.styleLab};
    final report = await service.importBackup(
        '$interop/desktop.naisbackup', selected,
        confirmConfigurationOverwrite: true);
    expect(report.retainedNativeArchives, greaterThan(0));
    final exported = await service.createBackup(selected,
        includeAssets: true, internal: true);
    await File(exported.path).copy('$interop/mobile.naisbackup');
    final before = ZipDecoder()
        .decodeBytes(await File('$interop/desktop.naisbackup').readAsBytes());
    final after = ZipDecoder()
        .decodeBytes(await File('$interop/mobile.naisbackup').readAsBytes());
    for (final file in before.files
        .where((e) => e.isFile && e.name.startsWith('portable-projects/'))) {
      expect(after.findFile(file.name)!.content, file.content);
    }
  });

  test(
      'imports both mobile and desktop workspace layers without replacing current state',
      () async {
    final archive = Archive();
    void json(String name, Object value) {
      final bytes = utf8.encode(jsonEncode(value));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    json('manifest.json', {
      'format': DataBackupService.format,
      'version': 1,
      'createdAt': '2026-09-27T00:00:00Z',
      'source': {'platform': 'win32', 'appVersion': 'test'},
      'categories': [
        {'category': 'workspaceData', 'items': 2, 'bytes': 0}
      ]
    });
    json('data/mobile-state.json',
        {'mobile-only-project': 'keep mobile', 'existing': 'incoming'});
    json('data/workspace.json', {
      'langbai.artist-detective.v1': jsonEncode({
        'prompt': 'keep desktop',
        'parameters': {'model': 'nai-diffusion-4-5-full'}
      })
    });
    final file = File('${root.path}/bridge.naisbackup')
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('existing', 'current');
    await service.importBackup(file.path, {DataBackupCategory.workspaceData},
        confirmConfigurationOverwrite: false);
    expect(prefs.getString('mobile-only-project'), 'keep mobile');
    expect(prefs.getString('existing'), 'current');
    expect(
        jsonDecode(prefs.getString('langbai.artist-detective.v1')!)['prompt'],
        'keep desktop');
    final exported =
        await service.createBackup({DataBackupCategory.workspaceData});
    final zip = ZipDecoder().decodeBytes(exported.readAsBytesSync());
    expect(zip.findFile('data/mobile-state.json'), isNotNull);
    expect(zip.findFile('data/workspace.json'), isNotNull);
  });

  test('migrates the old implicit image backup default to lightweight mode',
      () {
    final migrated = AppSettings.fromJson({
      'autoBackupIncludeImages': true,
    });
    final explicitlyEnabled = AppSettings.fromJson({
      'autoBackupIncludeImages': true,
      'autoBackupAssetPolicyVersion': 1,
    });

    expect(migrated.autoBackupIncludeImages, isFalse);
    expect(migrated.autoBackupAssetPolicyVersion, 1);
    expect(explicitlyEnabled.autoBackupIncludeImages, isTrue);
  });

  test('creates and inspects the shared versioned archive', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('batch_redraw_project_v1', jsonEncode({'name': 'A'}));
    await storage.setSettings(AppSettings(theme: 'dark'));
    await storage.setParams(GenerateParams(seed: 42, seedMode: 'fixed'));

    final file = await service.createBackup({
      DataBackupCategory.configuration,
      DataBackupCategory.workspaceData,
    });
    final inspection = await service.inspect(file.path);

    expect(file.existsSync(), isTrue);
    expect(inspection.sourcePlatform, isNotEmpty);
    expect(
      inspection.categories.map((item) => item.category),
      containsAll([
        DataBackupCategory.configuration,
        DataBackupCategory.workspaceData,
      ]),
    );
  });

  test(
      'old archives carrying removed Agent data and capsules still restore the kept categories',
      () async {
    final profile = utf8.encode('LEGACY AGENT PROFILE');
    final legacy = Archive()
      ..addFile(
          ArchiveFile('files/profiles/custom.yml', profile.length, profile));
    final legacyManifest = utf8.encode(jsonEncode({
      'version': 1,
      'kind': 'agent',
      'files': [
        {
          'name': 'profiles/custom.yml',
          'bytes': profile.length,
          'hash': sha256.convert(profile).toString()
        }
      ],
      'omitted': []
    }));
    legacy.addFile(
        ArchiveFile('manifest.json', legacyManifest.length, legacyManifest));
    final capsule = ZipEncoder().encode(legacy);
    final archive = Archive();
    void json(String name, Object value) {
      final bytes = utf8.encode(jsonEncode(value));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    json('manifest.json', {
      'format': DataBackupService.format,
      'version': 1,
      'categories': [
        {'category': 'agentWorkspace', 'items': 1, 'bytes': 0},
        {'category': 'tavernAgent', 'items': 1, 'bytes': profile.length},
        {'category': 'workspaceData', 'items': 2, 'bytes': 0}
      ]
    });
    json('data/agent-workspace.json', {
      'conversations': [
        {'id': 'legacy', 'messages': [], 'draftAttachments': []}
      ],
      'memories': []
    });
    archive.addFile(ArchiveFile(
        'portable-projects/agent-${sha256.convert(capsule)}.zip',
        capsule.length,
        capsule));
    json('data/mobile-state.json', {
      'agent_workspace_v1': jsonEncode({'conversations': []}),
      'mobile-only-project': 'kept'
    });
    json('data/workspace.json',
        {'langbai.artist-detective.v1': jsonEncode({'prompt': 'kept'})});
    final file = File('${root.path}/legacy.naisbackup')
      ..writeAsBytesSync(ZipEncoder().encode(archive));

    final inspected = await service.inspect(file.path);
    expect(inspected.categories.map((c) => c.category),
        [DataBackupCategory.workspaceData]);
    final report = await service.importBackup(file.path,
        {DataBackupCategory.workspaceData, DataBackupCategory.styleLab},
        confirmConfigurationOverwrite: false);
    final prefs = await SharedPreferences.getInstance();
    expect(report.retainedNativeArchives, 0);
    expect(prefs.getString('mobile-only-project'), 'kept');
    expect(prefs.containsKey('agent_workspace_v1'), isFalse);
    expect(
        jsonDecode(prefs.getString('langbai.artist-detective.v1')!)['prompt'],
        'kept');
    expect(Directory('${root.path}/portable-project-capsules').existsSync(),
        isFalse);
  });

  test('skips identical image records and suffixes same-name different bytes',
      () async {
    final sourceA = Directory('${root.path}/source-a')..createSync();
    final sourceB = Directory('${root.path}/source-b')..createSync();
    final first = File('${sourceA.path}/same.png')..writeAsBytesSync([1, 2, 3]);
    final second = File('${sourceB.path}/same.png')
      ..writeAsBytesSync([4, 5, 6]);
    await storage.writeHistory([
      _item('source-1', first.path, 1),
      _item('source-2', second.path, 2),
    ]);
    final archive =
        await service.createBackup({DataBackupCategory.imageHistory});

    final destination = Directory('${root.path}/images/2026-08-30')
      ..createSync(recursive: true);
    final existing = File('${destination.path}/same.png')
      ..writeAsBytesSync([1, 2, 3]);
    await storage.writeHistory([_item('existing', existing.path, 1)]);

    final report = await service.importBackup(
      archive.path,
      {DataBackupCategory.imageHistory},
      confirmConfigurationOverwrite: false,
    );
    final restored = await storage.getHistory();

    expect(report.skipped, greaterThanOrEqualTo(1));
    expect(report.renamed, 1);
    expect(
        File('${destination.path}/same (1).png').readAsBytesSync(), [4, 5, 6]);
    expect(restored.length, 2);
    expect(File(report.rescueBackupPath).existsSync(), isTrue);
  });

  test('exports mobile artist favorites in the shared flattened shape',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'artist_lab_random_v1_favorites',
      jsonEncode([
        {
          'recipe': {
            'id': 'mobile-favorite',
            'pairId': 'mobile-pair',
            'variant': 'plain',
            'prompt': '0.42::artist:foo_bar ::,',
            'basePrompt': '0.42::artist:foo_bar ::,',
            'artistPrompt': '0.42::artist:foo_bar ::,',
            'artists': ['foo_bar'],
            'mutations': [],
            'franchiseStyles': [],
          },
          'sequence': 3,
          'seed': 123,
          'status': 'done',
          'liked': true,
        }
      ]),
    );

    final file = await service.createBackup(
      {DataBackupCategory.artistLibrary},
      includeAssets: false,
    );
    final archive =
        ZipDecoder().decodeBytes(await file.readAsBytes(), verify: true);
    final payload = jsonDecode(utf8.decode(List<int>.from(
      archive.findFile('data/artist-library.json')!.content as List,
    ))) as Map<String, dynamic>;
    final favorite = ((payload['collections'] as Map)['random'] as List).single
        as Map<String, dynamic>;

    expect(favorite['id'], 'mobile-favorite');
    expect(favorite['pairId'], 'mobile-pair');
    expect(favorite['generationSeed'], 123);
    expect((favorite['artists'] as List).single,
        {'name': 'foo_bar', 'weight': 0.42});
  });

  test('imports a desktop artist favorite into the mobile nested shape',
      () async {
    final archive = Archive();
    void addJson(String name, Object value) {
      final bytes = utf8.encode(jsonEncode(value));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addJson('manifest.json', {
      'format': DataBackupService.format,
      'version': DataBackupService.formatVersion,
      'createdAt': '2026-08-30T12:00:00.000Z',
      'source': {'platform': 'win32', 'appVersion': 'test'},
      'categories': [
        {'category': 'artistLibrary', 'items': 1, 'bytes': 0}
      ],
    });
    addJson('data/artist-library.json', {
      'version': 1,
      'collections': {
        'random': [
          {
            'id': 'desktop-favorite',
            'pairId': 'desktop-pair',
            'variant': 'plain',
            'prompt': '0.75::artist:desktop_artist ::,',
            'basePrompt': '0.75::artist:desktop_artist ::,',
            'artists': [
              {'name': 'desktop_artist', 'weight': 0.75}
            ],
            'auxiliary': [],
            'mutations': [],
            'franchiseStyles': [],
            'sequence': 4,
            'status': 'done',
            'generationSeed': 456,
            'liked': true,
          }
        ],
        'v5-repair': [],
        'artist-string-draw': [],
      },
    });
    final encoded = ZipEncoder().encode(archive);
    final file = File('${root.path}/desktop.naisbackup')
      ..writeAsBytesSync(encoded);

    final report = await service.importBackup(
      file.path,
      {DataBackupCategory.artistLibrary},
      confirmConfigurationOverwrite: false,
    );
    final prefs = await SharedPreferences.getInstance();
    final favorite = (jsonDecode(
      prefs.getString('artist_lab_random_v1_favorites')!,
    ) as List)
        .single as Map<String, dynamic>;
    final recipe = Map<String, dynamic>.from(favorite['recipe'] as Map);

    expect(report.imported, greaterThanOrEqualTo(1));
    expect(recipe['id'], 'desktop-favorite');
    expect(recipe['artists'], ['desktop_artist']);
    expect(recipe['artistPrompt'], '0.75::artist:desktop_artist ::');
    expect(favorite['seed'], 456);
  });

  test(
      'merges positive prompt presets, restores view-only images, and reuses source ids',
      () async {
    final sourceImage = File('${root.path}/prompt-reference.png')
      ..writeAsBytesSync([7, 8, 9]);
    await storage.setSettings(AppSettings(
      positivePromptPresets: [
        PositivePromptPreset(
          id: 'portable-positive',
          name: '夜景',
          prompt: '1girl, night city, cinematic lighting',
          createdAt: '2026-08-30T12:00:00.000Z',
          previewImages: [
            StylePromptPreviewImage(
              id: 'source-preview',
              name: 'prompt-reference.png',
              filePath: sourceImage.path,
              createdAt: '2026-08-30T12:00:00.000Z',
            ),
          ],
        ),
      ],
    ));
    final archive =
        await service.createBackup({DataBackupCategory.promptPresets});

    await storage.setSettings(AppSettings(
      positivePromptPresets: [
        PositivePromptPreset(
          id: 'existing-positive',
          name: '夜景',
          prompt: 'different prompt',
          createdAt: '2026-08-31T12:00:00.000Z',
        ),
      ],
    ));
    final first = await service.importBackup(
      archive.path,
      {DataBackupCategory.promptPresets},
      confirmConfigurationOverwrite: false,
    );
    final afterFirst = await storage.getSettings();
    final imported = afterFirst.positivePromptPresets
        .where((preset) => preset.id == 'portable-positive')
        .single;

    expect(first.renamed, greaterThanOrEqualTo(1));
    expect(imported.name, '夜景 (1)');
    expect(imported.previewImages, hasLength(1));
    expect(File(imported.previewImages.single.filePath).readAsBytesSync(),
        [7, 8, 9]);

    final second = await service.importBackup(
      archive.path,
      {DataBackupCategory.promptPresets},
      confirmConfigurationOverwrite: false,
    );
    final afterSecond = await storage.getSettings();
    expect(afterSecond.positivePromptPresets, hasLength(2));
    expect(second.skipped, greaterThanOrEqualTo(1));
  });
  test('positive characters survive backup and different characters never collapse on repeated restore', () async {
    PositivePromptPreset preset(String character) => PositivePromptPreset(id:'same-source',name:'Neutral preset',prompt:'blue square',createdAt:'2026-10-11T00:00:00Z',captions:[CharCaptionItem(enabled:false,name:'Neutral character',prompt:character,negativePrompt:'red coat',useCoords:true,x:0,y:1)]);
    await storage.setSettings(AppSettings(positivePromptPresets:[preset('blue coat'),preset('green coat')]));
    final archive=await service.createBackup({DataBackupCategory.promptPresets});
    await storage.setSettings(AppSettings());
    await service.importBackup(archive.path,{DataBackupCategory.promptPresets},confirmConfigurationOverwrite:false);
    final first=await storage.getSettings();
    expect(first.positivePromptPresets,hasLength(2));
    expect(first.positivePromptPresets.map((p)=>p.id).toSet(),hasLength(2));
    for(final p in first.positivePromptPresets){expect(p.captions.single.name,'Neutral character');expect(p.captions.single.enabled,false);expect(p.captions.single.x,0);expect(p.captions.single.y,1);expect(p.captions.single.negativePrompt,'red coat');}
    await service.importBackup(archive.path,{DataBackupCategory.promptPresets},confirmConfigurationOverwrite:false);
    final second=await storage.getSettings();
    expect(second.positivePromptPresets,hasLength(2));
    expect(second.positivePromptPresets.map((p)=>p.captions.single.prompt),['blue coat','green coat']);
  });
  test('positive presets without source IDs remain repeatable after name collision', () async {
    Map<String,dynamic> preset(String character) => {'name':'Neutral preset','prompt':'blue square','createdAt':'2026-10-11T00:00:00Z','captions':[CharCaptionItem(prompt:character).toJson()]};
    final archive=Archive();
    void addJson(String path,Object data){final bytes=utf8.encode(jsonEncode(data));archive.addFile(ArchiveFile(path,bytes.length,bytes));}
    addJson('manifest.json',{'format':DataBackupService.format,'version':DataBackupService.formatVersion,'categories':[{'category':'promptPresets','items':2,'bytes':0}]});
    addJson('data/prompt-presets.json',{'positivePromptPresets':[preset('blue coat'),preset('green coat')]});
    final input=File('${root.path}/legacy.naisbackup')..writeAsBytesSync(ZipEncoder().encode(archive));
    for(var i=0;i<2;i++){await service.importBackup(input.path,{DataBackupCategory.promptPresets},confirmConfigurationOverwrite:false);}
    expect((await storage.getSettings()).positivePromptPresets,hasLength(2));
  });

  // The desktop app writes these records (electron/ipc/data-backup.ts); the
  // fixture keeps its exact JSON shape, so tags round-trip between the apps.
  test('desktop-shaped prompt library tags restore and are exported unchanged',
      () async {
    final fixture = jsonDecode(
            File('test/fixtures/desktop_prompt_library_tags.json')
                .readAsStringSync())
        as Map<String, dynamic>;
    final archive = Archive();
    void addJson(String path, Object? data) {
      final bytes = utf8.encode(jsonEncode(data));
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    addJson('manifest.json', {
      'format': DataBackupService.format,
      'version': DataBackupService.formatVersion,
      'categories': [
        {'category': 'configuration', 'items': 1, 'bytes': 0},
        {'category': 'promptPresets', 'items': 4, 'bytes': 0},
      ],
    });
    addJson('data/prompt-presets.json', fixture['promptPresets']);
    addJson('data/configuration.json', fixture['configuration']);
    final input = File('${root.path}/desktop-tags.naisbackup')
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    await service.importBackup(input.path,
        {DataBackupCategory.configuration, DataBackupCategory.promptPresets},
        confirmConfigurationOverwrite: true);
    final restored = await storage.getSettings();
    expect(restored.positivePromptPresets.map((preset) => preset.tags), [
      ['夜景', 'night sky'],
      <String>[],
    ]);
    expect(restored.promptChunks.map((chunk) => chunk.tags), [
      ['服装', '角色'],
      <String>[],
    ]);
    expect(restored.negativePromptPresets.map((preset) => preset['tags']), [
      ['手部', '质量'],
      null,
    ]);

    final exported = await service.createBackup(
        {DataBackupCategory.configuration, DataBackupCategory.promptPresets});
    final bundle = ZipDecoder().decodeBytes(exported.readAsBytesSync());
    Map<String, dynamic> read(String name) => jsonDecode(utf8.decode(
            List<int>.from(bundle.findFile(name)!.content as List)))
        as Map<String, dynamic>;
    final prompts = read('data/prompt-presets.json');
    final presets = fixture['promptPresets'] as Map<String, dynamic>;
    expect(prompts['positivePromptPresets'], presets['positivePromptPresets']);
    expect(prompts['promptChunks'], presets['promptChunks']);
    final configuration = read('data/configuration.json');
    expect(configuration['negativePromptPresets'],
        (fixture['configuration'] as Map)['negativePromptPresets']);
    // Chunks travel with the prompt presets only, as on the desktop.
    expect(configuration.containsKey('promptChunks'), isFalse);
  });

  test('restores saved-prompt tags and merges them into matching existing entries',
      () async {
    Future<void> restore(Map<String, dynamic> payload) async {
      final archive = Archive();
      void addJson(String path, Object data) {
        final bytes = utf8.encode(jsonEncode(data));
        archive.addFile(ArchiveFile(path, bytes.length, bytes));
      }

      addJson('manifest.json', {
        'format': DataBackupService.format,
        'version': DataBackupService.formatVersion,
        'categories': [
          {'category': 'promptPresets', 'items': 2, 'bytes': 0}
        ],
      });
      addJson('data/prompt-presets.json', payload);
      final input = File('${root.path}/tags.naisbackup')
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      await service.importBackup(input.path, {DataBackupCategory.promptPresets},
          confirmConfigurationOverwrite: false);
    }

    final preset = {
      'id': 'same-source',
      'name': 'Neutral preset',
      'prompt': 'blue square',
      'captions': <Object>[],
      'createdAt': '2026-10-11T00:00:00Z',
    };
    Map<String, dynamic> payload(List<String> tags) => {
          'positivePromptPresets': [
            {...preset, 'tags': tags}
          ],
          'promptChunks': [
            {
              'id': 'chunk',
              'name': 'Outfit',
              'content': 'white dress',
              'tags': tags,
              'createdAt': 'x',
              'updatedAt': 'y',
            }
          ],
        };
    await restore(payload([' 夜景 ', '#夜景']));
    var settings = await storage.getSettings();
    expect(settings.positivePromptPresets.map((p) => p.tags), [
      ['夜景']
    ]);
    expect(settings.promptChunks.map((c) => c.tags), [
      ['夜景']
    ]);
    await restore(payload(['城市']));
    settings = await storage.getSettings();
    expect(settings.positivePromptPresets.single.tags, ['夜景', '城市']);
    expect(settings.promptChunks.single.tags, ['夜景', '城市']);
    expect(settings.promptChunks.single.toJson(), {
      'id': 'chunk',
      'name': 'Outfit',
      'content': 'white dress',
      'tags': ['夜景', '城市'],
      'createdAt': 'x',
      'updatedAt': 'y',
    });
    await restore({
      'positivePromptPresets': [
        {...preset, 'id': 'untagged', 'name': 'Untagged', 'prompt': 'plain'}
      ],
      'promptChunks': [
        {'id': 'chunk', 'name': 'Outfit 2', 'content': ' smile ', 'tags': '表情'}
      ],
    });
    settings = await storage.getSettings();
    expect(settings.positivePromptPresets[1].toJson().containsKey('tags'),
        isFalse);
    // A different chunk whose source ID is taken gets a new ID; text is
    // trimmed and missing dates are filled in.
    final added = settings.promptChunks.last;
    expect(added.id, isNot('chunk'));
    expect((added.name, added.content), ('Outfit 2', 'smile'));
    expect(added.tags, ['表情']);
    expect(added.createdAt, isNotEmpty);
  });

}
