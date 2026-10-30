import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novelai_mobile/services/unified_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp, docs, target;
  late Map<String, dynamic> values;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('studio-migration-');
    docs = Directory(p.join(temp.path, 'old-documents'));
    target = Directory(p.join(temp.path, 'LangbaiStudio'));
    await Directory(p.join(docs.path, 'images')).create(recursive: true);
    await File(p.join(docs.path, 'images', 'original.png'))
        .writeAsBytes([1, 2, 3, 4]);
    values = {
      'history_index_v2': jsonEncode([
        {
          'id': 'image-id',
          'filePath': p.join(docs.path, 'images', 'original.png'),
          'customPath': '/other/chosen/image.png'
        }
      ]),
      'app_settings': jsonEncode({
        'stylePromptPresets': [
          {'id': 'style-id', 'name': '画风'}
        ],
        'proxyUrl': 'http://user:secret@localhost:8080',
        'imageOutputDir': '/custom/images'
      })
    };
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(values));
    UnifiedStorage.active = null;
  });
  tearDown(() async {
    UnifiedStorage.active = null;
    await temp.delete(recursive: true);
  });
  test('BASELINE: original private data and source image remain readable',
      () async {
    final prefs = UnifiedPreferences(await SharedPreferences.getInstance());
    expect(prefs.getString('history_index_v2'), values['history_index_v2']);
    expect(
        await File(p.join(docs.path, 'images', 'original.png')).readAsBytes(),
        [1, 2, 3, 4]);
  });
  test(
      'MODIFIED: copies verified data, rebases only managed paths, excludes private credentials',
      () async {
    final result = await UnifiedStorage.migrateFiles(
        documents: docs, target: target, preferences: values);
    expect(result['oldDataRetained'], true);
    expect(
        await File(p.join(docs.path, 'images', 'original.png')).readAsBytes(),
        [1, 2, 3, 4]);
    final raw = await File(p.join(target.path, 'data', 'image-history.json'))
        .readAsString();
    expect(raw, contains('image-id'));
    expect(jsonDecode(raw)[0]['filePath'],
        p.join(target.path, 'images', 'original.png'));
    expect(jsonDecode(raw)[0]['customPath'], '/other/chosen/image.png');
    expect(
        await File(p.join(target.path, 'presets', 'prompt-presets.json'))
            .readAsString(),
        isNot(contains('secret')));
    final manifest = jsonDecode(
        await File(p.join(target.path, 'storage-manifest.json'))
            .readAsString());
    expect(manifest['files'], isNotEmpty);
  });
  test(
      'ROLLBACK: new data uses shared folder; original data is retained when selection returns to private',
      () async {
    await UnifiedStorage.migrateFiles(
        documents: docs, target: target, preferences: values);
    UnifiedStorage.active = target;
    final prefs = UnifiedPreferences(await SharedPreferences.getInstance());
    await prefs.setString('history_index_v2', '[{"id":"new"}]');
    expect(prefs.getString('history_index_v2'), contains('new'));
    UnifiedStorage.active = null;
    expect(prefs.getString('history_index_v2'), values['history_index_v2']);
    expect(
        await File(p.join(target.path, 'data', 'image-history.json'))
            .readAsString(),
        contains('new'));
  });
  test('pre-existing destination is never overwritten', () async {
    await target.create();
    final other = File(p.join(target.path, 'keep.txt'));
    await other.writeAsString('keep');
    await expectLater(
        UnifiedStorage.migrateFiles(
            documents: docs, target: target, preferences: values),
        throwsA(isA<FileSystemException>()));
    expect(await other.readAsString(), 'keep');
  });
  test('concurrent writes serialize and invalid JSON cannot replace good data',
      () async {
    final file = File(p.join(temp.path, 'queued.json'));
    await Future.wait(List.generate(
        20, (i) => UnifiedPreferences.atomicJson(file, jsonEncode({'i': i}))));
    expect(jsonDecode(await file.readAsString())['i'], 19);
    await expectLater(
        UnifiedPreferences.atomicJson(file, 'broken'), throwsFormatException);
    expect(jsonDecode(await file.readAsString())['i'], 19);
    await UnifiedPreferences.atomicJson(file, '{"i":20}');
    expect(jsonDecode(await file.readAsString())['i'], 20);
  });
  test('editing shared presets preserves original private preset library',
      () async {
    await UnifiedStorage.migrateFiles(
        documents: docs, target: target, preferences: values);
    UnifiedStorage.active = target;
    final prefs = UnifiedPreferences(await SharedPreferences.getInstance());
    final updated = jsonDecode(prefs.getString('app_settings')!) as Map;
    updated['stylePromptPresets'] = [
      {'id': 'new-style'}
    ];
    await prefs.setString('app_settings', jsonEncode(updated));
    expect(prefs.getString('app_settings'), contains('new-style'));
    UnifiedStorage.active = null;
    expect(prefs.getString('app_settings'), contains('style-id'));
    expect(prefs.getString('app_settings'), isNot(contains('new-style')));
  });
  test('missing migrated data raises error rather than returning empty data',
      () async {
    await UnifiedStorage.migrateFiles(
        documents: docs, target: target, preferences: values);
    UnifiedStorage.active = target;
    await File(p.join(target.path, 'data/image-history.json')).delete();
    final prefs = UnifiedPreferences(await SharedPreferences.getInstance());
    expect(() => prefs.getString('history_index_v2'),
        throwsA(isA<FileSystemException>()));
  });
  test('space estimate covers managed files', () async {
    expect(await UnifiedStorage.estimateCopyBytes(docs), 4);
  });
  test('malformed source prevents activation and retains originals', () async {
    values['history_index_v2'] = 'not-json';
    await expectLater(
        UnifiedStorage.migrateFiles(
            documents: docs, target: target, preferences: values),
        throwsFormatException);
    expect(await target.exists(), false);
    expect(
        await File(p.join(docs.path, 'images', 'original.png')).exists(), true);
  });
}
