import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novelai_mobile/services/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('bulk file deletion rejects a directory instead of reporting success',
      () async {
    final dir = await Directory.systemTemp.createTemp('batch-delete-probe-');
    try {
      await expectLater(Storage().deleteHistoryFiles([dir.path]),
          throwsA(isA<FileSystemException>()));
    } finally {
      await dir.delete();
    }
  });
}
