import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/item_picker.dart';
import '../../core/widgets/toast.dart';
import '../../data/mock_data.dart';
import '../../models/stock_item.dart';
import '../../providers/stock_providers.dart';

/// Shared IN / OUT movement form. Local state only — confirm mutates the
/// in-memory [stockProvider] and shows a toast.
class MovementScreen extends ConsumerStatefulWidget {
  const MovementScreen({super.key, required this.isIn, this.itemId});

  final bool isIn;
  final String? itemId;

  @override
  ConsumerState<MovementScreen> createState() => _MovementScreenState();
}

class _MovementScreenState extends ConsumerState<MovementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();

  StockItem? _item;
  String? _option;
  DateTime _date = DateTime.now();
  bool _override = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemId != null) {
      _item = ref.read(stockProvider).itemById(widget.itemId!);
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isIn => widget.isIn;

  int get _entered {
    final v = int.tryParse(_qty.text.trim()) ?? 0;
    return v;
  }

  bool get _insufficient =>
      !_isIn && _item != null && _entered > _item!.quantity;

  List<String> get _options =>
      _isIn ? MockData.stockSources : MockData.stockOutParties;

  Future<void> _selectItem() async {
    final picked = await pickStockItem(context);
    if (picked != null) {
      setState(() {
        _item = picked;
        _override = false;
      });
    }
  }

  /// One-tap shortcut: create the item and land straight back on this form.
  Future<void> _addItemInstantly() async {
    final item = await quickAddStockItem(context);
    if (item == null || !mounted) return;
    setState(() {
      _item = item;
      _override = false;
    });
  }

  Future<void> _selectOption() async {
    final picked = await AppSheet.show<String>(
      context,
      title: _isIn ? 'Stock source' : 'Issue reason',
      subtitle: _isIn ? 'Where is this material coming from?' : 'Why is this leaving stock?',
      builder: (context) => Column(
        children: [
          for (final o in _options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SheetOptionTile(
                title: o,
                selected: _option == o,
                onTap: () => Navigator.of(context).pop(o),
              ),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _option = picked);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _setMax() {
    if (_item == null) return;
    setState(() => _qty.text = '${_item!.quantity}');
  }

  Future<void> _confirm() async {
    if (_saving) return;
    if (_item == null) {
      AppToast.error(context, 'Select an item first');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_option == null) {
      AppToast.error(
        context,
        _isIn ? 'Choose a stock source' : 'Choose an issue reason',
      );
      return;
    }
    if (_insufficient && !_override) {
      AppToast.error(
        context,
        'Insufficient stock — enable admin override to continue',
      );
      return;
    }

    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final notifier = ref.read(stockProvider.notifier);
    final result = _isIn
        ? await notifier.stockIn(
            itemId: _item!.id,
            quantity: _entered,
            source: _option!,
            reference: _reference.text,
            date: _date,
            notes: _notes.text,
          )
        : await notifier.stockOut(
            itemId: _item!.id,
            quantity: _entered,
            party: _option!,
            reference: _reference.text,
            date: _date,
            notes: _notes.text,
            adminOverride: _override,
          );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.ok) {
      AppToast.success(context, result.message);
      Navigator.of(context).pop();
    } else {
      AppToast.error(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _isIn ? AppColors.success : AppColors.danger;
    final bg = _isIn ? AppColors.successSoft : AppColors.dangerSoft;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 17,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            Text(_isIn ? 'Stock In' : 'Stock Out'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Item', style: theme.textTheme.labelMedium),
                ),
                GestureDetector(
                  onTap: _addItemInstantly,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 13,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'New item',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            AppCard(
              padding: const EdgeInsets.all(13),
              onTap: _selectItem,
              child: _item == null
                  ? Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.touch_app_rounded,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tap to select an item',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to select an item — or add one instantly',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        ItemAvatar(item: _item!, size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _item!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_item!.sku} • ${Fmt.number(_item!.quantity)} ${_item!.unit} in stock',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.primaryDeep,
                          size: 20,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Quantity', style: theme.textTheme.labelMedium),
                ),
                if (_item != null && !_isIn)
                  GestureDetector(
                    onTap: _setMax,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'MAX',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                IconAction(
                  icon: Icons.remove_rounded,
                  color: AppColors.danger,
                  bg: AppColors.dangerSoft,
                  size: 52,
                  onTap: () {
                    final next = (_entered - 1).clamp(0, 999999);
                    setState(() => _qty.text = '$next');
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 26,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim()) ?? 0;
                      if (n <= 0) return 'Enter a valid quantity';
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: '0',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconAction(
                  icon: Icons.add_rounded,
                  color: AppColors.success,
                  bg: AppColors.successSoft,
                  size: 52,
                  onTap: () {
                    final next = _entered + 1;
                    setState(() => _qty.text = '$next');
                  },
                ),
              ],
            ),
            if (_item != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _InfoChip(
                      label: 'Available',
                      value: '${_item!.quantity} ${_item!.unit}',
                    ),
                    const SizedBox(width: 18),
                    _InfoChip(
                      label: 'After move',
                      value: '${_isIn
                          ? _item!.quantity + _entered
                          : _item!.quantity - _entered} ${_item!.unit}',
                      color: _insufficient ? AppColors.danger : null,
                    ),
                    const Spacer(),
                    Text(
                      Fmt.currency(
                        _entered *
                            (_isIn
                                ? _item!.purchasePrice
                                : _item!.sellingPrice),
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_insufficient) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Insufficient stock',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Only ${_item!.quantity} ${_item!.unit} available. '
                      'Short by ${_entered - _item!.quantity}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _override,
                      onChanged: (v) => setState(() => _override = v),
                      title: Text(
                        'Admin override',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 13.5,
                        ),
                      ),
                      subtitle: Text(
                        'Allow negative stock for this entry',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            AppPickerField(
              label: _isIn ? 'Source' : 'Issue reason',
              value: _option ?? '',
              hint: _isIn ? 'Select source' : 'Select reason',
              prefixIcon: _isIn
                  ? Icons.input_rounded
                  : Icons.outbox_rounded,
              required: true,
              onTap: _selectOption,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _reference,
              label: _isIn ? 'Invoice / challan reference' : 'Requisition / order no.',
              hint: _isIn ? 'e.g. INV-2481' : 'e.g. SO-7741',
              prefixIcon: Icons.tag_rounded,
            ),
            const SizedBox(height: 16),
            AppPickerField(
              label: 'Date',
              value: Fmt.date(_date),
              prefixIcon: Icons.calendar_today_rounded,
              onTap: _selectDate,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _notes,
              label: 'Notes',
              hint: 'Optional remark for the ledger',
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: AppButton(
          label: _isIn ? 'Confirm stock in' : 'Confirm stock out',
          variant: _isIn ? AppButtonVariant.success : AppButtonVariant.danger,
          icon: _isIn ? Icons.download_rounded : Icons.upload_rounded,
          loading: _saving,
          onTap: _confirm,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 13.5,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
