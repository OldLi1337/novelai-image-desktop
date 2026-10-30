import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:novelai_mobile/state/app_state.dart';
import 'package:novelai_mobile/screens/data_backup_settings.dart';
import 'package:novelai_mobile/services/data_backup_service.dart';

class _BackupPaths extends PathProviderPlatform {
  final String root;
  _BackupPaths(this.root);
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('backup categories render independently', (tester) async {
    final root = Directory.systemTemp.createTempSync('backup-ui-contract-');
    PathProviderPlatform.instance = _BackupPaths(root.path);
    SharedPreferences.setMockInitialValues({});
    final state = AppState()..booted = true;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child:
                        DataBackupSettingsPanel(initiallyExpanded: true))))));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump();
    final tiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(tiles.length, DataBackupCategory.values.length);
    final labels = tiles.map((tile) => (tile.title as Text).data!).toList();
    expect(labels.toSet().length, DataBackupCategory.values.length);
    expect(labels.any((label) => label.contains('Agent')), isFalse);
    expect(tiles.every((tile) => tile.onChanged != null), true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    await tester.runAsync(() => root.delete(recursive: true));
  });
}
