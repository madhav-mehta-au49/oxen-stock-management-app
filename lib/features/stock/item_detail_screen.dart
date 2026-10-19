import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/toast.dart';
import '../../models/stock_item.dart';
import '../../models/stock_transaction.dart';
import '../../providers/auth_providers.dart';
import '../../providers/stock_providers.dart';
import 'item_form_screen.dart';
import 'movement_screen.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(stockProvider);
    final item = state.itemById(itemId);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item')),
        body: const EmptyState(
          icon: Icons.inventory_2_rounded,
          title: 'Item not found',
          message: 'It may have been removed from inventory.',
        ),
      );
    }

    final ledger = ref.watch(itemLedgerProvider(itemId));
    final itemImage = ref.watch(itemImageProvider(itemId)).valueOrNull;
    final canEditItem = can(ref, 'itemEdit');
    final canDeleteItem = can(ref, 'itemDelete');
    final canIn = can(ref, 'stockIn');
    final canOut = can(ref, 'stockOut');
    final statusColor = item.isOutOfStock
        ? AppColors.danger
        : item.isLowStock
        ? AppColors.primaryDeep
        : AppColors.success;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Item detail'),
        actions: [
          if (!item.isDeleted && (canEditItem || canDeleteItem))
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'More options',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (v) async {
                if (v == 'edit') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ItemFormScreen(item: item),
                    ),
                  );
                } else if (v == 'delete') {
                  await _confirmDelete(context, ref, item);
                }
              },
              itemBuilder: (_) => [
                if (canEditItem)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_rounded),
                      title: Text('Edit item'),
                    ),
                  ),
                if (canDeleteItem)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.danger,
                      ),
                      title: Text(
                        'Delete item',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            if (itemImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: Image.memory(
                  itemImage,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(height: 14),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ItemAvatar(item: item, size: 60, radius: 16),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '${item.sku} • ${item.categoryName}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            StatusPill(
                              label: item.isOutOfStock
                                  ? 'OUT OF STOCK'
                                  : item.isLowStock
                                  ? 'LOW STOCK'
                                  : 'IN STOCK',
                              color: statusColor,
                              icon: Icons.circle,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ON HAND',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Fmt.number(item.quantity),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: 30,
                                  color: statusColor,
                                ),
                              ),
                              Text(item.unit, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 56,
                          color: AppColors.border,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STOCK VALUE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Fmt.price(item.stockValue),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: 22,
                                ),
                              ),
                              Text(
                                'cost ${Fmt.price(item.purchasePrice)} / ${item.unit}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MetaGrid(item: item),
                  if (item.isDeleted) ...[
                    const SizedBox(height: 16),
                    _DeletedInfo(item: item),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!item.isDeleted && (canIn || canOut || canEditItem))
              Row(
                children: [
                  if (canIn)
                    Expanded(
                      child: AppButton(
                        label: 'Stock In',
                        dense: true,
                        height: 46,
                        variant: AppButtonVariant.success,
                        icon: Icons.add_rounded,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                MovementScreen(isIn: true, itemId: item.id),
                          ),
                        ),
                      ),
                    ),
                  if (canIn && (canOut || canEditItem))
                    const SizedBox(width: 10),
                  if (canOut)
                    Expanded(
                      child: AppButton(
                        label: 'Stock Out',
                        dense: true,
                        height: 46,
                        variant: AppButtonVariant.danger,
                        icon: Icons.remove_rounded,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                MovementScreen(isIn: false, itemId: item.id),
                          ),
                        ),
                      ),
                    ),
                  if (canOut && canEditItem) const SizedBox(width: 10),
                  if (canEditItem)
                    Expanded(
                      child: AppButton(
                        label: 'Edit',
                        dense: true,
                        height: 46,
                        variant: AppButtonVariant.outline,
                        icon: Icons.edit_rounded,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ItemFormScreen(item: item),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Stock ledger',
              trailing: StatusPill(
                label: '${ledger.length} ENTRIES',
                color: AppColors.textSecondary,
                dense: true,
              ),
            ),
            if (ledger.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No movements yet',
                  message: 'Stock in and out entries will show up here.',
                ),
              )
            else
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: _LedgerList(entries: ledger),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StockItem item,
  ) async {
    final remarks = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Delete item?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.name} will be removed from the stock list. The record and '
                'ledger are kept for audit (visible in the audit log).',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: remarks,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g. Damaged / discontinued',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (remarks.text.trim().isEmpty) {
                  setDialog(() => error = 'Please enter a reason');
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );

    final reason = remarks.text.trim();
    remarks.dispose();

    if (confirmed != true) return;
    final result = await ref
        .read(stockProvider.notifier)
        .deleteItem(item.id, remarks: reason);
    if (!context.mounted) return;
    if (result.ok) {
      AppToast.success(context, result.message);
      Navigator.of(context).pop();
    } else {
      AppToast.error(context, result.message);
    }
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.item});

  final StockItem item;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Reorder level', '${item.reorderLevel} ${item.unit}'),
      ('Supplier', item.supplier.isEmpty ? '—' : item.supplier),
      ('Unit Nos', item.unitNos.isEmpty ? '—' : item.unitNos),
      ('Selling price', Fmt.price(item.sellingPrice)),
      ('Margin', '${item.margin.toStringAsFixed(1)}%'),
      ('Added on', Fmt.shortDate(item.createdAt)),
    ];

    return Column(
      children: [
        for (var i = 0; i < rows.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Meta(label: rows[i].$1, value: rows[i].$2),
              ),
              const SizedBox(width: 12),
              if (i + 1 < rows.length)
                Expanded(
                  child: _Meta(label: rows[i + 1].$1, value: rows[i + 1].$2),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }
}

class _DeletedInfo extends StatelessWidget {
  const _DeletedInfo({required this.item});

  final StockItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(icon, size: 15, color: AppColors.danger),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
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
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            Icons.person_rounded,
            'Deleted by',
            item.deletedByName.isEmpty ? '—' : item.deletedByName,
          ),
          if (item.deletedAt != null)
            row(Icons.schedule_rounded, 'On', Fmt.dayTime(item.deletedAt!)),
          if (item.deleteRemarks.isNotEmpty)
            row(Icons.notes_rounded, 'Reason', item.deleteRemarks),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
        ),
      ],
    );
  }
}

class _LedgerList extends StatelessWidget {
  const _LedgerList({required this.entries});

  final List<StockTransaction> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    String? lastDay;

    for (final e in entries) {
      final day = Fmt.relativeDay(e.date);
      if (day != lastDay) {
        lastDay = day;
        children.add(_dayHeader(theme, day));
      }
      children.add(_entry(theme, e));
    }

    return Column(children: children);
  }

  Widget _dayHeader(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _entry(ThemeData theme, StockTransaction e) {
    final isIn = e.isIn;
    final color = isIn ? AppColors.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (isIn ? AppColors.successSoft : AppColors.dangerSoft),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isIn ? 'IN' : 'OUT'} • ${e.reference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  '${e.party} • ${Fmt.dayTime(e.date)} • ${e.user}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                if (e.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    e.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                e.signedLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'bal ${e.balanceAfter}',
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
