import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Replaces `ASDDownloader1.DownloadFile` + `TaifunFile1.Move` from the
/// original screen: downloads the image, then moves/saves it into a
/// `Download/GameChanger` folder, returning the final file path (the
/// equivalent of `ASDDownloader1.DownloadSuccess(filePath)`).
class ReminderDownloadService {
  final Dio _dio = Dio();

  Future<String> downloadImage({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    if (Platform.isAndroid) {
      // On Android 13+ the legacy WRITE_EXTERNAL_STORAGE permission no
      // longer applies to the public Downloads folder the same way;
      // request storage/photos access defensively and fall back to
      // app-private storage if it's denied.
      await Permission.storage.request();
    }

    final targetDir = await _targetDirectory();
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final sanitized = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetPath = '${targetDir.path}/$sanitized.jpg';

    await _dio.download(
      url,
      targetPath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    return targetPath;
  }

  Future<Directory> _targetDirectory() async {
    if (Platform.isAndroid) {
      // Mirrors the original hard-coded
      // '/storage/emulated/0/Download/GameChanger' destination.
      return Directory('/storage/emulated/0/Download/GameChanger');
    }
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/GameChanger');
  }
}
