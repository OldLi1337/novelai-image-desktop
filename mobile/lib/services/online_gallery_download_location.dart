import 'unified_storage.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../state/app_state.dart';
import 'storage_permission.dart';

typedef OnlineGalleryDownloadPathText = ({
  String title,
  String defaultLabel,
  String hint,
  String choose,
  String reset,
  String dialogTitle,
});

OnlineGalleryDownloadPathText onlineGalleryDownloadPathText(Object? language, {bool? unified}) {
  final useUnified = unified ?? UnifiedStorage.active != null;
  return (title: '在线画廊下载路径', defaultLabel: useUnified ? '使用统一文件夹' : '首次下载时选择', hint: useUnified ? '未自选路径时保存到统一文件夹；单张图片和整个系列共用。' : '第一次下载会询问保存位置，以后单张图片和整个系列都默认使用该路径。', choose: '选择文件夹', reset: useUnified ? '恢复统一文件夹' : '下次重新询问', dialogTitle: '选择在线画廊下载文件夹');
}

Future<bool> ensureOnlineGalleryDownloadDirectory(AppState state) async {
  if (state.settings.onlineGalleryDownloadDir.trim().isNotEmpty) return true;
  await UnifiedStorage.initialize();
  if (UnifiedStorage.active != null) return true;
  final text = onlineGalleryDownloadPathText(state.settings.language);
  final picked = await FilePicker.platform.getDirectoryPath(dialogTitle: text.dialogTitle);
  if (picked == null || picked.trim().isEmpty) return false;
  if (Platform.isAndroid && !await StoragePermission.hasAllFilesAccess()) {
    await StoragePermission.requestAllFilesAccess();
  }
  await state.setSettings((settings) => settings.onlineGalleryDownloadDir = picked.trim());
  return true;
}
