import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/toast.dart';
import '../../models/update_info.dart';
import '../../services/apk_download_service.dart';
import '../../services/apk_installer.dart';

/// Shows the "Update available" dialog and, if the user accepts, downloads and
/// launches the Android package installer.
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  UpdateInfo info,
) async {
  final action = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Update available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A new version of the app is available.'),
              const SizedBox(height: 14),
              _kv(theme, 'Current version', info.currentVersion),
              const SizedBox(height: 6),
              _kv(theme, 'New version', info.latestVersion),
              if (info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text("What's new", style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  info.releaseNotes,
                  style: theme.textTheme.bodySmall,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('later'),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('update'),
            child: const Text('Update now'),
          ),
        ],
      );
    },
  );

  if (action != 'update' || !context.mounted) return;
  await _downloadAndInstall(context, info);
}

Widget _kv(ThemeData theme, String label, String value) => Row(
  children: [
    Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
    Text(
      value,
      style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primaryDeep),
    ),
  ],
);

Future<void> _downloadAndInstall(BuildContext context, UpdateInfo info) async {
  final progress = ValueNotifier<double>(0);

  // Non-dismissible progress dialog.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ProgressDialog(progress: progress, fileName: info.apkFileName),
  );

  try {
    final file = await ApkDownloadService.download(
      info.apkUrl,
      info.apkFileName,
      onProgress: (p) => progress.value = p,
    );

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // close progress
    }

    final allowed = await ApkInstaller.canRequestPackageInstalls();
    if (!allowed) {
      if (context.mounted) await _showEnableInstallDialog(context);
      return;
    }

    await ApkInstaller.install(file.path);
  } catch (_) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      AppToast.error(
        context,
        'Update download failed. Please check your connection and try again.',
      );
    }
  }
}

Future<void> _showEnableInstallDialog(BuildContext context) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Allow app installs'),
      content: const Text(
        'To install this update, Android needs permission for this app to '
        'install other apps. Tap "Open settings", enable "Allow from this '
        'source", then return and tap Update again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Open settings'),
        ),
      ],
    ),
  );
  if (open == true) await ApkInstaller.openInstallSettings();
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.progress, required this.fileName});

  final ValueNotifier<double> progress;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Downloading update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, value, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: LinearProgressIndicator(
                    value: value == 0 ? null : value,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceAlt,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value == 0
                      ? 'Starting…'
                      : '${(value * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please keep the app open until the download finishes.',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
