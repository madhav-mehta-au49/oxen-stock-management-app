import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/update_info.dart';

/// Checks GitHub Releases for a newer APK — no server, no credentials (the
/// repository is public). Any failure is treated as "no update" so it can
/// never block the app.
class GitHubUpdateService {
  const GitHubUpdateService();

  static const String owner = 'madhav-mehta-au49';
  static const String repo = 'oxen-stock-management-app';

  static const String _apiLatest =
      'https://api.github.com/repos/$owner/$repo/releases/latest';
  static const String _assetPrefix =
      'https://github.com/$owner/$repo/releases/download/';

  Future<UpdateInfo?> checkForUpdate({bool includePrerelease = false}) async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = _stripV(pkg.version);

      final res = await http.get(
        Uri.parse(_apiLatest),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'OxenEnergies-Updater',
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['draft'] == true) return null;
      if (data['prerelease'] == true && !includePrerelease) return null;

      final latest = _stripV((data['tag_name'] as String? ?? '').trim());
      if (latest.isEmpty) return null;
      if (compareVersions(latest, current) <= 0) return null;

      Map<String, dynamic>? apk;
      for (final raw in (data['assets'] as List? ?? const [])) {
        final asset = Map<String, dynamic>.from(raw as Map);
        final name = (asset['name'] as String? ?? '');
        if (name.toLowerCase().endsWith('.apk')) {
          apk = asset;
          break;
        }
      }
      if (apk == null) return null;

      final url = apk['browser_download_url'] as String? ?? '';
      // Security: only accept assets downloaded from this repository.
      if (!url.startsWith(_assetPrefix)) return null;

      return UpdateInfo(
        currentVersion: current,
        latestVersion: latest,
        releaseNotes: (data['body'] as String? ?? '').trim(),
        apkUrl: url,
        apkFileName: apk['name'] as String? ?? 'oxen-energies-$latest.apk',
        releasePageUrl: data['html_url'] as String? ??
            'https://github.com/$owner/$repo/releases',
      );
    } catch (_) {
      return null;
    }
  }

  static String _stripV(String tag) {
    var t = tag.trim();
    if (t.startsWith('v') || t.startsWith('V')) t = t.substring(1);
    return t.split('+').first;
  }

  /// Semantic comparison of `x.y.z` versions. Returns <0, 0 or >0.
  static int compareVersions(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    for (var i = 0; i < 3; i++) {
      final c = pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return 0;
  }

  static List<int> _parts(String v) {
    final core = v.split('-').first.split('+').first;
    final seg = core.split('.');
    return [
      int.tryParse(seg.isNotEmpty ? seg[0] : '0') ?? 0,
      int.tryParse(seg.length > 1 ? seg[1] : '0') ?? 0,
      int.tryParse(seg.length > 2 ? seg[2] : '0') ?? 0,
    ];
  }
}
