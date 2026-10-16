import 'package:flutter/services.dart';

/// Bridges to the native Android APK installer (FileProvider + package
/// installer intent) via a MethodChannel handled in `MainActivity.kt`.
class ApkInstaller {
  const ApkInstaller._();

  static const MethodChannel _channel =
      MethodChannel('com.oxensolar.oxen_solar_stock/updater');

  /// Whether this app is allowed to request package installs (Android 8+).
  static Future<bool> canRequestPackageInstalls() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
          true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the "Install unknown apps" settings page for this app.
  static Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod('openInstallSettings');
    } catch (_) {
      // Ignore — the user can enable it manually from Android settings.
    }
  }

  /// Launches the Android package installer for [path].
  static Future<void> install(String path) async {
    await _channel.invokeMethod('installApk', {'path': path});
  }
}
