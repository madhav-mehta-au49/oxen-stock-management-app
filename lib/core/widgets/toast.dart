import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ToastType { success, error, info }

/// Lightweight in-memory snackbar used for save / confirm / sync feedback.
class AppToast {
  const AppToast._(this.context);

  final BuildContext context;

  static void success(BuildContext context, String message) =>
      AppToast._(context)._show(message, ToastType.success);

  static void error(BuildContext context, String message) =>
      AppToast._(context)._show(message, ToastType.error);

  static void info(BuildContext context, String message) =>
      AppToast._(context)._show(message, ToastType.info);

  void _show(String message, ToastType type) {
    final (icon, color) = switch (type) {
      ToastType.success => (Icons.check_circle_rounded, AppColors.success),
      ToastType.error => (Icons.error_rounded, AppColors.danger),
      ToastType.info => (Icons.info_rounded, AppColors.infoLight),
    };

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: EdgeInsets.zero,
        dismissDirection: DismissDirection.horizontal,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x331A2332),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
