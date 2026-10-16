import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../../models/stock_item.dart';
import '../../providers/stock_providers.dart';
import 'app_button.dart';
import 'app_sheet.dart';
import 'app_text_field.dart';
import 'common.dart';
import 'toast.dart';

/// Reusable searchable inventory picker used by Stock In/Out and Challan.
/// [allowQuickAdd] shows an "add item instantly" entry so a missing item can
/// be created on the spot and returned without leaving the current flow.
Future<StockItem?> pickStockItem(
  BuildContext context, {
  bool Function(StockItem item)? filter,
  bool allowQuickAdd = true,
}) {
  return AppSheet.show<StockItem>(
    context,
    title: 'Select item',
    subtitle: 'Search by name, SKU or supplier',
    builder: (context) => _ItemPickerBody(
      filter: filter,
      allowQuickAdd: allowQuickAdd,
    ),
  );
}

/// Opens the instant add sheet on its own and returns the new item (null if
/// cancelled). Used by the Stock In/Out shortcut next to the Item label.
Future<StockItem?> quickAddStockItem(
  BuildContext context, {
  String prefillName = '',
}) {
  return AppSheet.show<StockItem>(
    context,
    title: 'New item',
    subtitle: 'Only the name is required — add the rest any time',
    builder: (context) => _QuickAddBody(prefillName: prefillName),
  );
}

class _ItemPickerBody extends ConsumerStatefulWidget {
  const _ItemPickerBody({this.filter, this.allowQuickAdd = true});

  final bool Function(StockItem item)? filter;
  final bool allowQuickAdd;

  @override
  ConsumerState<_ItemPickerBody> createState() => _ItemPickerBodyState();
}

class _ItemPickerBodyState extends ConsumerState<_ItemPickerBody> {
  String _q = '';

  Future<void> _quickAdd() async {
    final created = await quickAddStockItem(context, prefillName: _q.trim());
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var items = ref.watch(itemsProvider);
    if (widget.filter != null) items = items.where(widget.filter!).toList();

    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? items
        : items
            .where(
              (i) =>
                  i.name.toLowerCase().contains(q) ||
                  i.sku.toLowerCase().contains(q) ||
                  i.supplier.toLowerCase().contains(q),
            )
            .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            hintText: 'Search inventory…',
            prefixIcon: Icon(Icons.search_rounded, size: 21),
          ),
        ),
        const SizedBox(height: 14),
        if (widget.allowQuickAdd && list.isNotEmpty) ...[
          SheetOptionTile(
            title: 'Add new item',
            subtitle: 'Not in the list? Create it in seconds',
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.success,
                size: 22,
              ),
            ),
            onTap: _quickAdd,
          ),
          const SizedBox(height: 8),
        ],
        if (list.isEmpty)
          widget.allowQuickAdd
              ? EmptyState(
                  icon: Icons.add_box_rounded,
                  title: q.isEmpty ? 'No items yet' : 'No items found',
                  message: q.isEmpty
                      ? 'Create your first item right here — only the name is needed.'
                      : '"${_q.trim()}" is not in the inventory. Add it in seconds.',
                  actionLabel:
                      q.isEmpty ? 'Add first item' : 'Add "${_q.trim()}"',
                  onAction: _quickAdd,
                )
              : const EmptyState(
                  icon: Icons.inventory_2_rounded,
                  title: 'No items found',
                  message: 'Nothing matches that search.',
                )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = list[i];
                return SheetOptionTile(
                  title: item.name,
                  subtitle:
                      '${item.sku} • ${item.quantity} ${item.unit} available',
                  leading: ItemAvatar(item: item, size: 42, radius: 10),
                  trailing: item.needsAttention
                      ? StatusPill(
                          label: item.isOutOfStock ? 'OUT' : 'LOW',
                          color: AppColors.danger,
                          dense: true,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(item),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Minimal add-item sheet: the name is enough. Category and unit are plain
/// tappable chips (no extra pop-ups), everything else sits behind an
/// "Optional details" toggle so the happy path stays one screen long.
class _QuickAddBody extends ConsumerStatefulWidget {
  const _QuickAddBody({this.prefillName = ''});

  final String prefillName;

  @override
  ConsumerState<_QuickAddBody> createState() => _QuickAddBodyState();
}

class _QuickAddBodyState extends ConsumerState<_QuickAddBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _price;
  late final TextEditingController _supplier;
  late final TextEditingController _unitNos;

  late ItemCategory _category;
  bool _saving = false;
  bool _showOptional = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.prefillName);
    _sku = TextEditingController();
    _price = TextEditingController();
    _supplier = TextEditingController();
    _unitNos = TextEditingController();
    _category = ItemCategory.panels;
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _price, _supplier, _unitNos]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final item = await ref.read(stockProvider.notifier).quickAddItem(
          name: _name.text,
          sku: _sku.text,
          category: _category,
          unit: 'Unit',
          purchasePrice: double.tryParse(_price.text.trim()) ?? 0,
          supplier: _supplier.text,
          unitNos: _unitNos.text,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (item == null) {
      AppToast.error(
        context,
        'Could not add — this name or SKU already exists',
      );
      return;
    }
    AppToast.success(context, '${item.name} selected');
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.primaryDeep,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add the item here — you will come right back to this '
                    'entry with it selected.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _name,
            label: 'Item name',
            hint: 'e.g. Monocrystalline Panel 330W',
            prefixIcon: Icons.label_outline_rounded,
            required: true,
            autofocus: widget.prefillName.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            validator: (v) => (v ?? '').trim().length < 3
                ? 'Enter at least 3 characters'
                : null,
          ),
          const SizedBox(height: 16),
          Text('Category', style: theme.textTheme.labelMedium),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in ItemCategory.values)
                ChoiceChip(
                  avatar: Icon(
                    c.icon,
                    size: 15,
                    color: _category == c
                        ? AppColors.primaryDeep
                        : AppColors.textMuted,
                  ),
                  label: Text(c.label),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: AppColors.primarySoft,
                  labelStyle: TextStyle(
                    color: _category == c
                        ? AppColors.primaryDeep
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  side: BorderSide(
                    color: _category == c ? AppColors.primary : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _showOptional = !_showOptional),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    'Optional details',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primaryDeep,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(SKU, price, unit nos, supplier)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showOptional
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primaryDeep,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _showOptional
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _sku,
                              label: 'SKU code',
                              hint: 'Auto if blank',
                              prefixIcon: Icons.qr_code_rounded,
                              textCapitalization:
                                  TextCapitalization.characters,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _price,
                              label: 'Purchase price (₹)',
                              hint: '0',
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.shopping_bag_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _unitNos,
                        label: 'Unit Nos',
                        hint: 'e.g. UN-001 – UN-025',
                        prefixIcon: Icons.confirmation_number_rounded,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _supplier,
                        label: 'Supplier',
                        hint: 'e.g. SunRay Energies',
                        prefixIcon: Icons.local_shipping_rounded,
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 14),
          Text(
            'Opening stock starts at 0 — the quantity you enter next becomes '
            'the first entry in the ledger.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Add & continue',
            variant: AppButtonVariant.success,
            icon: Icons.add_rounded,
            loading: _saving,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}
