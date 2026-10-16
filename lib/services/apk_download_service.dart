import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads the APK over HTTPS into the app cache and validates it.
class ApkDownloadService {
  const ApkDownloadService._();

  static bool _downloading = false;
  static bool get isDownloading => _downloading;

  /// Downloads [url] to the app temp directory and returns the file.
  /// Throws on failure. Prevents concurrent downloads.
  static Future<File> download(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    if (_downloading) {
      throw StateError('A download is already in progress');
    }
    _downloading = true;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) await file.delete();

      final client = http.Client();
      try {
        final resp = await client.send(http.Request('GET', Uri.parse(url)));
        if (resp.statusCode != 200) {
          throw HttpException('HTTP ${resp.statusCode}');
        }
        final total = resp.contentLength ?? 0;
        final sink = file.openWrite();
        var received = 0;
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
        }
        await sink.flush();
        await sink.close();
      } finally {
        client.close();
      }

      if (!await file.exists() || await file.length() < 1024) {
        throw const FormatException('Downloaded file is empty');
      }
      await _validateApk(file);
      return file;
    } finally {
      _downloading = false;
    }
  }

  /// A valid APK is a ZIP archive — verify the `PK\x03\x04` magic bytes.
  static Future<void> _validateApk(File file) async {
    final raf = await file.open();
    try {
      final head = await raf.read(4);
      if (head.length < 4 ||
          head[0] != 0x50 ||
          head[1] != 0x4B ||
          head[2] != 0x03 ||
          head[3] != 0x04) {
        throw const FormatException('Downloaded file is not a valid APK');
      }
    } finally {
      await raf.close();
    }
  }
}
