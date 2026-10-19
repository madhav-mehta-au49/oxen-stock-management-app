import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/notification_repository.dart';
import '../../models/app_notification.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';
import '../challan/challan_preview_screen.dart';
import '../stock/item_detail_screen.dart';

/// Opens the in-app notification centre and marks everything as seen.
Future<void> showNotificationsSheet(BuildContext context) {
  return AppSheet.show<void>(
    context,
    title: 'Notifications',
    subtitle: 'Low stock, challans and daily summary',
    builder: (_) => const NotificationsBody(),
  );
}

class NotificationsBody extends ConsumerStatefulWidget {
  const NotificationsBody({super.key});

  @override
  ConsumerState<NotificationsBody> createState() => _NotificationsBodyState();
}

class _NotificationsBodyState extends ConsumerState<NotificationsBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return;
      await const NotificationRepository().markSeen(uid, DateTime.now());
    });
  }

  void _open(AppNotification n) {
    Navigator.of(context).pop();
    switch (n.type) {
      case AppNotificationType.lowStock:
        if (n.refId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ItemDetailScreen(itemId: n.refId),
            ),
          );
        }
      case AppNotificationType.challan:
        if (n.refId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChallanPreviewScreen(number: n.refId),
            ),
          );
        }
      case AppNotificationType.summary:
      case AppNotificationType.info:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = ref.watch(notificationsProvider).value ?? const [];

    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet',
        message:
            'Low-stock alerts, issued challans and the daily summary will appear here.',
      );
    }

    return Column(
      children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 56),
          InkWell(
            onTap: () => _open(list[i]),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _icon(list[i].type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 3),
                        Text(list[i].body, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          '${Fmt.relativeDay(list[i].createdAt)} • ${Fmt.timeOf(list[i].createdAt)}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _icon(AppNotificationType type) {
    final (icon, color) = switch (type) {
      AppNotificationType.lowStock => (
        Icons.warning_amber_rounded,
        AppColors.danger,
      ),
      AppNotificationType.challan => (
        Icons.receipt_long_rounded,
        AppColors.info,
      ),
      AppNotificationType.summary => (
        Icons.summarize_rounded,
        AppColors.primary,
      ),
      AppNotificationType.info => (Icons.info_rounded, AppColors.textSecondary),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
