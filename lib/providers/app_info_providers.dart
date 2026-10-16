import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed app version (e.g. "1.0.1"), read from the platform package.
/// Always reflects the real build — never hardcode a version in the UI.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
