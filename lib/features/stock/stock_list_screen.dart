import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/toast.dart';
import '../../models/category.dart';
import '../../models/stock_item.dart';
import '../../providers/auth_providers.dart';
import '../../providers/category_providers.dart';
import '../../providers/stock_providers.dart';
import 'item_detail_screen.dart';
import 'item_form_screen.dart';
import 'movement_screen.dart';

enum _Sort { nameAsc, qtyAsc, qtyDesc, valueDesc }

class StockListScreen extends ConsumerStatefulWidget {
  const StockListScreen({super.key});

  @override
  ConsumerState<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends ConsumerState<StockListScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _categoryId;
  bool _deletedOnly = false;
  _Sort _sort = _Sort.nameAsc;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _sortLabel => switch (_sort) {
    _Sort.nameAsc => 'Name A → Z',
    _Sort.qtyAsc => 'Stock: low first',
    _Sort.qtyDesc => 'Stock: high first',
    _Sort.valueDesc => 'Value: high first',
  };

  List<StockItem> _apply(List<StockItem> source) {
    final q = _query.trim().toLowerCase();
    var list = source.where((i) {
      final matchesDeleted = _deletedOnly ? i.isDeleted : !i.isDeleted;
      final matchesQuery =
          q.isEmpty ||
          i.name.toLowerCase().contains(q) ||
          i.sku.toLowerCase().contains(q) ||
          i.supplier.toLowerCase().contains(q);
      final matchesCat = _categoryId == null || i.categoryId == _categoryId;
      return matchesDeleted && matchesQuery && matchesCat;
    }).toList();

    list.sort(
      (a, b) => switch (_sort) {
        _Sort.nameAsc => a.name.compareTo(b.name),
        _Sort.qtyAsc => a.quantity.compareTo(b.quantity),
        _Sort.qtyDesc => b.quantity.compareTo(a.quantity),
        _Sort.valueDesc => b.stockValue.compareTo(a.stockValue),
      },
    );
    return list;
  }

  Future<void> _pickSort() async {
    final picked = await AppSheet.show<_Sort>(
      context,
      title: 'Sort inventory',
      subtitle: 'Choose how items are ordered',
      builder: (context) => Column(
        children: [
          for (final s in _Sort.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SheetOptionTile(
                title: switch (s) {
                  _Sort.nameAsc => 'Name A → Z',
                  _Sort.qtyAsc => 'Stock level: low to high',
                  _Sort.qtyDesc => 'Stock level: high to low',
                  _Sort.valueDesc => 'Stock value: high to low',
                },
                selected: _sort == s,
                onTap: () => Navigator.of(context).pop(s),
              ),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _sort = picked);
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    AppToast.info(context, 'Inventory is up to date');
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final everyItem = ref.watch(allItemsProvider);
    final active = everyItem.where((i) => !i.isDeleted).toList();
    final deletedCount = everyItem.length - active.length;
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? Category.defaults;
    final list = _apply(everyItem);
    final canCreateItem = can(ref, 'itemCreate');
    final canEditItem = can(ref, 'itemEdit');
    final canStockIn = can(ref, 'stockIn');
    final canStockOut = can(ref, 'stockOut');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inventory',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${list.length} of ${(_deletedOnly ? everyItem : active).length} items • $_sortLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _pickSort,
                        tooltip: 'Sort',
                        icon: const Icon(Icons.sort_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search name, SKU or supplier…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 21),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded, size: 19),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: 'All',
                          count: active.length,
                          selected: _categoryId == null && !_deletedOnly,
                          onTap: () => setState(() {
                            _categoryId = null;
                            _deletedOnly = false;
                          }),
                        ),
                        for (final c in categories)
                          if (active.any((i) => i.categoryId == c.id))
                            _FilterChip(
                              label: c.name,
                              count: active
                                  .where((i) => i.categoryId == c.id)
                                  .length,
                              selected: _categoryId == c.id,
                              onTap: () => setState(() {
                                _deletedOnly = false;
                                _categoryId = _categoryId == c.id ? null : c.id;
                              }),
                            ),
                        if (deletedCount > 0)
                          _FilterChip(
                            label: 'Deleted',
                            count: deletedCount,
                            selected: _deletedOnly,
                            onTap: () => setState(() {
                              _deletedOnly = !_deletedOnly;
                              _categoryId = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryDeep,
                onRefresh: _refresh,
                child: list.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.only(top: 40),
                        children: [
                          EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No items match',
                            message: _query.isEmpty
                                ? 'No stock in this category yet.'
                                : 'Try a different name, SKU or supplier.',
                            actionLabel: 'Clear filters',
                            onAction: () {
                              _search.clear();
                              setState(() {
                                _query = '';
                                _categoryId = null;
                              });
                            },
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _ItemCard(
                          item: list[i],
                          onTap: () =>
                              _open(ItemDetailScreen(itemId: list[i].id)),
                          onIn: canStockIn
                              ? () => _open(
                                  MovementScreen(
                                    isIn: true,
                                    itemId: list[i].id,
                                  ),
                                )
                              : null,
                          onOut: canStockOut
                              ? () => _open(
                                  MovementScreen(
                                    isIn: false,
                                    itemId: list[i].id,
                                  ),
                                )
                              : null,
                          onEdit: canEditItem
                              ? () => _open(ItemFormScreen(item: list[i]))
                              : null,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canCreateItem
          ? FloatingActionButton.extended(
              onPressed: () => _open(const ItemFormScreen()),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add item',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.navy : AppColors.border,
            ),
          ),
          child: Text(
            '$label ($count)',
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeletedRow extends StatelessWidget {
  const _DeletedRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onTap,
    required this.onIn,
    required this.onOut,
    required this.onEdit,
  });

  final StockItem item;
  final VoidCallback onTap;
  final VoidCallback? onIn;
  final VoidCallback? onOut;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool deleted = item.isDeleted;
    final Color statusColor = deleted
        ? AppColors.danger
        : item.isOutOfStock
        ? AppColors.danger
        : item.isLowStock
        ? AppColors.primaryDeep
        : AppColors.success;
    final String statusLabel = deleted
        ? 'DELETED'
        : item.isOutOfStock
        ? 'OUT OF STOCK'
        : item.isLowStock
        ? 'LOW STOCK'
        : 'IN STOCK';

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ItemAvatar(item: item, size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(
                            label: statusLabel,
                            color: statusColor,
                            dense: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${item.sku}  •  ${item.categoryName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${Fmt.number(item.quantity)} ${item.unit}',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  TextSpan(
                                    text: '  • reorder ${item.reorderLevel}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Fmt.price(item.stockValue),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (deleted) ...[
            const Divider(indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DeletedRow(
                      icon: Icons.person_rounded,
                      label: 'Deleted by',
                      value: item.deletedByName.isEmpty
                          ? '—'
                          : item.deletedByName,
                    ),
                    if (item.deletedAt != null) ...[
                      const SizedBox(height: 6),
                      _DeletedRow(
                        icon: Icons.schedule_rounded,
                        label: 'On',
                        value: Fmt.dayTime(item.deletedAt!),
                      ),
                    ],
                    if (item.deleteRemarks.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _DeletedRow(
                        icon: Icons.notes_rounded,
                        label: 'Reason',
                        value: item.deleteRemarks,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else if (onIn != null || onOut != null || onEdit != null) ...[
            const Divider(indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  if (onOut != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onOut,
                        icon: const Icon(Icons.remove_rounded, size: 17),
                        label: const Text('Stock Out'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                      ),
                    ),
                  if (onOut != null && (onIn != null || onEdit != null))
                    Container(width: 1, height: 20, color: AppColors.divider),
                  if (onIn != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onIn,
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text('Stock In'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.success,
                        ),
                      ),
                    ),
                  if (onIn != null && onEdit != null)
                    Container(width: 1, height: 20, color: AppColors.divider),
                  if (onEdit != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 15),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
