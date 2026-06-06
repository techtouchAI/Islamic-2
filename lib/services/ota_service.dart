import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class OTAService {
  static final OTAService _instance = OTAService._internal();
  static OTAService get instance => _instance;

  OTAService._internal();

  final ValueNotifier<double> downloadProgress = ValueNotifier(-1.0);
  bool _isDownloading = false;

  Future<void> downloadAndInstallApk(
    String url,
    String? expectedChecksum, {
    required Function(String) onError,
  }) async {
    if (_isDownloading) return;

    if (Platform.isAndroid) {
      var installStatus = await Permission.requestInstallPackages.status;
      if (!installStatus.isGranted) {
        installStatus = await Permission.requestInstallPackages.request();
        if (!installStatus.isGranted) {
          onError('يجب منح صلاحية تثبيت التطبيقات لتتمكن من تحديث التطبيق');
          return;
        }
      }
    }

    _isDownloading = true;
    downloadProgress.value = 0.0;

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String savePath = '${tempDir.path}/app-update.apk';

      final Dio dio = Dio();

      // الفصل عن الواجهة: التنزيل يعمل بشكل مستقل هنا
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgress.value = received / total;
          }
        },
      );

      downloadProgress.value = -1.0; // Reset progress after download

      final File file = File(savePath);

      // تأمين التثبيت (File Checksum Validation)
      if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
        final List<int> bytes = await file.readAsBytes();
        final String fileChecksum = sha256.convert(bytes).toString();

        if (fileChecksum != expectedChecksum) {
          await file.delete();
          debugPrint("OTA ERROR: Checksum mismatch. Expected: $expectedChecksum, Got: $fileChecksum");
          onError('تعذر التحديث: ملف التنزيل تالف أو تم التلاعب به.');
          _isDownloading = false;
          return;
        }
      }

      final result = await OpenFile.open(savePath);
      debugPrint("OpenFile result: ${result.message}");

    } catch (e) {
      debugPrint("Download/Install error: $e");
      downloadProgress.value = -1.0;
      onError('فشل تحميل التحديث');
    } finally {
      _isDownloading = false;
    }
  }
}
