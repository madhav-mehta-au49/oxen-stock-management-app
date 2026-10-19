import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/toast.dart';
import '../../data/repositories/category_repository.dart';
import '../../models/category.dart';
import '../../models/item_glyph.dart';
import '../../models/stock_item.dart';
import '../../providers/category_providers.dart';
import '../../providers/stock_providers.dart';

/// Add / edit / delete stock categories. GST lives on each category.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _addOrEdit(
    BuildContext context,
    WidgetRef ref, {
    Category? existing,
  }) async {
    final categories =
        ref.read(categoriesProvider).valueOrNull ?? Category.defaults;
    final name = TextEditingController(text: existing?.name ?? '');
    final gst = TextEditingController(text: _fmt(existing?.gstRate ?? 0));
    var iconKey = existing?.iconKey ?? 'box';
    var pricedPerWp = existing?.pricedPerWp ?? false;

    final saved = await AppSheet.show<bool>(
      context,
      title: existing == null ? 'Add category' : 'Edit category',
      subtitle: 'Name, GST % and icon',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: name,
              label: 'Category name',
              hint: 'e.g. Solar PV Modules',
              prefixIcon: Icons.category_rounded,
              required: true,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: gst,
              label: 'GST %',
              hint: '0',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icons.percent_rounded,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: 16),
            Text('Icon', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in ItemGlyph.all)
                  GestureDetector(
                    onTap: () => setSheet(() => iconKey = g.key),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: g.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              iconKey == g.key ? g.color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(g.icon, color: g.color, size: 24),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: pricedPerWp,
              onChanged: (v) => setSheet(() => pricedPerWp = v),
              title: const Text('Priced per Wp'),
              subtitle: const Text('Solar modules: enter the price in ₹/Wp'),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: existing == null ? 'Add category' : 'Save changes',
              icon: existing == null ? Icons.add_rounded : Icons.check_rounded,
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !context.mounted) return;
    final cleanName = name.text.trim();
    if (cleanName.length < 2) {
      AppToast.error(context, 'Enter a category name');
      return;
    }
    final rate = double.tryParse(gst.text.trim()) ?? 0;
    final repo = const CategoryRepository();

    if (existing == null) {
      final res = await repo.create(
        Category(
          id: '',
          name: cleanName,
          gstRate: rate,
          iconKey: iconKey,
          pricedPerWp: pricedPerWp,
          sortOrder: (categories.isEmpty ? 0 : categories.last.sortOrder + 1),
        ),
      );
      if (!context.mounted) return;
      if (res.ok) {
        AppToast.success(context, res.message);
      } else {
        AppToast.error(context, res.message);
      }
    } else {
      final res = await repo.update(
        existing.copyWith(
          name: cleanName,
          gstRate: rate,
          iconKey: iconKey,
          pricedPerWp: pricedPerWp,
        ),
      );
      if (res.ok && existing.name != cleanName) {
        await repo.renameItems(existing.id, cleanName);
      }
      if (!context.mounted) return;
      if (res.ok) {
        AppToast.success(context, res.message);
      } else {
        AppToast.error(context, res.message);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Category category,
    List<StockItem> items,
  ) async {
    final count = items.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete category?'),
        content: Text(
          count == 0
              ? 'Delete "${category.name}"?'
              : '"${category.name}" contains $count item${count == 1 ? '' : 's'}. '
                  'Deleting it will also permanently delete '
                  '${count == 1 ? 'that item' : 'those items'} and their stock '
                  'ledger. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    for (final item in items) {
      await ref.read(stockProvider.notifier).deleteItem(item.id);
    }
    await const CategoryRepository().delete(category.id);
    if (!context.mounted) return;
    AppToast.success(
      context,
      count == 0
          ? '${category.name} deleted'
          : '${category.name} and $count item${count == 1 ? '' : 's'} deleted',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? Category.defaults;
    final items = ref.watch(itemsProvider);

    int countFor(String id) =>
        items.where((i) => i.categoryId == id).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Categories')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Add, edit or delete categories. GST is set per category and '
              'shown on the delivery note.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < categories.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          ItemGlyph.byKey(categories[i].iconKey).icon,
                          color: AppColors.primaryDeep,
                          size: 20,
                        ),
                      ),
                      title: Text(categories[i].name),
                      subtitle: Text(
                        'GST ${_fmt(categories[i].gstRate)}% • '
                        '${countFor(categories[i].id)} item'
                        '${countFor(categories[i].id) == 1 ? '' : 's'}'
                        '${categories[i].pricedPerWp ? ' • ₹/Wp' : ''}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _delete(
                          context,
                          ref,
                          categories[i],
                          items
                              .where(
                                  (it) => it.categoryId == categories[i].id)
                              .toList(),
                        ),
                      ),
                      onTap: () =>
                          _addOrEdit(context, ref, existing: categories[i]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Add category',
              icon: Icons.add_rounded,
              onTap: () => _addOrEdit(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
