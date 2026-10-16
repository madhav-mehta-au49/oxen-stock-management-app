/// Information about an available update discovered from GitHub Releases.
class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkUrl,
    required this.apkFileName,
    required this.releasePageUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String apkUrl;
  final String apkFileName;
  final String releasePageUrl;
}
