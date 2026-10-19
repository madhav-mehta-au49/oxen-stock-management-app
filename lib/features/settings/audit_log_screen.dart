import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../models/audit_entry.dart';
import '../../providers/stock_providers.dart';

/// Read-only trail of who created, edited, deleted or cancelled records.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries =
        ref.watch(auditLogProvider).valueOrNull ?? const <AuditEntry>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Audit log')),
      body: SafeArea(
        top: false,
        child: entries.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  Text(
                    'Every create, edit, delete and cancel is recorded here '
                    'with the user and reason.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No activity yet',
                      message: 'Changes made in the app will show up here.',
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _AuditTile(entry: entries[i]),
              ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AuditEntry entry;

  (IconData, Color) get _visual => switch (entry.action) {
    'created' => (Icons.add_circle_outline_rounded, AppColors.success),
    'updated' => (Icons.edit_outlined, AppColors.primaryDeep),
    'deleted' => (Icons.delete_outline_rounded, AppColors.danger),
    'cancelled' => (Icons.cancel_outlined, AppColors.danger),
    _ => (Icons.history_rounded, AppColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _visual;

    Widget detail(
      IconData i,
      String label,
      String value, {
      FontStyle? fontStyle,
    }) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(i, size: 14, color: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontStyle: fontStyle,
              ),
            ),
          ),
        ],
      ),
    );

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.actionLabel} ${entry.entityTypeLabel}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Fmt.dayTime(entry.at),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
                if (entry.entityLabel.isNotEmpty)
                  detail(
                    Icons.inventory_2_rounded,
                    'Record',
                    entry.entityLabel,
                  ),
                detail(Icons.person_rounded, 'By', entry.userName),
                if (entry.remarks.isNotEmpty)
                  detail(
                    Icons.notes_rounded,
                    'Reason',
                    entry.remarks,
                    fontStyle: FontStyle.italic,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
