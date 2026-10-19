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
import '../../models/category.dart';
import '../../models/challan.dart';
import '../../models/stock_item.dart';
import '../../providers/category_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/stock_providers.dart';
import 'challan_format_picker.dart';
import 'challan_preview_screen.dart';

/// Create a delivery challan. Confirming deducts stock from local state.
class ChallanFormScreen extends ConsumerStatefulWidget {
  const ChallanFormScreen({super.key});

  @override
  ConsumerState<ChallanFormScreen> createState() => _ChallanFormScreenState();
}

class _ChallanFormScreenState extends ConsumerState<ChallanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customer = TextEditingController();
  final _site = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _vehicle = TextEditingController();
  final _notes = TextEditingController();

  String _number = '';
  DateTime _date = DateTime.now();
  ChallanFormat _format = ChallanFormat.letterhead;
  final List<ChallanLine> _lines = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _format = ref.read(appSettingsProvider).value?.defaultChallanFormat ??
        ChallanFormat.letterhead;
    _loadNumber();
  }

  Future<void> _loadNumber() async {
    try {
      final number =
          await ref.read(stockProvider.notifier).nextChallanNumber();
      if (mounted) setState(() => _number = number);
    } catch (_) {
      // Leave the placeholder number; the real one is assigned on issue.
    }
  }

  @override
  void dispose() {
    for (final c in [
      _customer,
      _site,
      _address,
      _contact,
      _vehicle,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
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

  int _availableFor(String itemId) {
    final item = ref.read(stockProvider).itemById(itemId);
    return item?.quantity ?? 0;
  }

  Future<void> _addItem() async {
    final item = await pickStockItem(
      context,
      filter: (i) =>
          i.quantity > 0 || _lines.any((l) => l.itemId == i.id),
    );
    if (item == null) return;

    final existingIndex = _lines.indexWhere((l) => l.itemId == item.id);
    await _editLine(
      item,
      existing: existingIndex == -1 ? null : _lines[existingIndex],
      index: existingIndex,
    );
  }

  Future<void> _editLine(
    StockItem item, {
    ChallanLine? existing,
    required int index,
  }) async {
    // Stock is only deducted on confirm, so the live on-hand quantity is the
    // ceiling for this line (the existing line's units are still part of it).
    final available = _availableFor(item.id);
    final categories =
        ref.read(categoriesProvider).valueOrNull ?? Category.defaults;
    final cat = categoryById(categories, item.categoryId);
    final gstRate = cat?.gstRate ?? 0;

    final line = await AppSheet.show<ChallanLine>(
      context,
      title: existing == null ? 'Add item' : 'Update quantity',
      subtitle: item.name,
      builder: (context) => _LineSheet(
        item: item,
        existing: existing,
        available: available,
        gstRate: gstRate,
      ),
    );

    if (line == null) return;
    setState(() {
      if (index == -1) {
        _lines.add(line);
      } else {
        _lines[index] = line;
      }
    });
  }

  Future<void> _confirm() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      AppToast.error(context, 'Add at least one item to the challan');
      return;
    }

    for (final l in _lines) {
      final available = _availableFor(l.itemId);
      if (l.quantity > available) {
        AppToast.error(
          context,
          '${l.itemName}: only $available ${l.unit} available',
        );
        return;
      }
    }

    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final challan = Challan(
      id: _number,
      number: _number,
      customerName: _customer.text.trim(),
      siteName: _site.text.trim(),
      address: _address.text.trim(),
      contact: _contact.text.trim(),
      date: _date,
      vehicleNo: _vehicle.text.trim(),
      notes: _notes.text.trim(),
      lines: List.unmodifiable(_lines),
      status: ChallanStatus.issued,
      format: _format,
    );

    final issue = await ref.read(stockProvider.notifier).issueChallan(challan);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!issue.result.ok) {
      AppToast.error(context, issue.result.message);
      return;
    }

    AppToast.success(context, issue.result.message);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChallanPreviewScreen(number: issue.number),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalUnits = _lines.fold<int>(0, (s, l) => s + l.quantity);
    final taxable = _lines.fold<double>(0, (s, l) => s + l.amount);
    final gst = _lines.fold<double>(0, (s, l) => s + l.gstAmount);
    final grandTotal = taxable + gst;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New delivery challan')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.navyGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHALLAN NUMBER',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white60,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _number,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.accentBright,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'AUTO',
                        style: TextStyle(
                          color: AppColors.accentBright,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Customer & site'),
              AppCard(
                child: Column(
                  children: [
                    AppTextField(
                      controller: _customer,
                      label: 'Customer name',
                      hint: 'e.g. Greenfield Estates',
                      prefixIcon: Icons.business_rounded,
                      required: true,
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Customer name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _site,
                      label: 'Site / project',
                      hint: 'e.g. Villa Block-C rooftop plant',
                      prefixIcon: Icons.location_on_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _address,
                      label: 'Delivery address',
                      hint: 'Street, area, city, pincode',
                      prefixIcon: Icons.map_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _contact,
                            label: 'Contact number',
                            hint: '+91 …',
                            prefixIcon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _vehicle,
                            label: 'Vehicle no.',
                            hint: 'RJ-14-XX-0000',
                            prefixIcon: Icons.local_shipping_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppPickerField(
                      label: 'Challan date',
                      value: Fmt.date(_date),
                      prefixIcon: Icons.calendar_today_rounded,
                      onTap: _selectDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Challan format'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose the PDF layout — the challan is generated in '
                      'this format.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ChallanFormatPicker(
                      value: _format,
                      onChanged: (f) => setState(() => _format = f),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionHeader(
                title: 'Items',
                actionLabel: '+ Add item',
                onAction: _addItem,
              ),
              if (_lines.isEmpty)
                AppCard(
                  child: EmptyState(
                    icon: Icons.add_shopping_cart_rounded,
                    title: 'No items added',
                    message: 'Add items — stock is deducted when you confirm.',
                    actionLabel: 'Add first item',
                    onAction: _addItem,
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < _lines.length; i++) ...[
                        if (i > 0) const Divider(indent: 60),
                        _LineTile(
                          line: _lines[i],
                          index: i,
                          available: _availableFor(_lines[i].itemId),
                          onEdit: () {
                            final item = ref
                                .read(stockProvider)
                                .itemById(_lines[i].itemId);
                            if (item == null) {
                              setState(() => _lines.removeAt(i));
                              return;
                            }
                            _editLine(item, existing: _lines[i], index: i);
                          },
                          onRemove: () =>
                              setState(() => _lines.removeAt(i)),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        _SummaryCell(
                            label: 'Items', value: '${_lines.length}'),
                        Container(
                            width: 1, height: 40, color: AppColors.border),
                        _SummaryCell(label: 'Units', value: '$totalUnits'),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCell(
                            label: 'Taxable value',
                            value: Fmt.currency(taxable),
                          ),
                        ),
                        Expanded(
                          child: _SummaryCell(
                            label: 'GST',
                            value: Fmt.currency(gst),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCell(
                            label: 'Grand total (incl. GST)',
                            value: Fmt.currency(grandTotal),
                            highlight: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primaryDeep,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Confirming creates the challan and automatically '
                        'deducts every line from local stock.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: AppButton(
          label: 'Confirm & issue challan',
          variant: AppButtonVariant.primary,
          icon: Icons.check_circle_outline_rounded,
          loading: _saving,
          onTap: _confirm,
        ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.index,
    required this.available,
    required this.onEdit,
    required this.onRemove,
  });

  final ChallanLine line;
  final int index;
  final int available;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final short = line.quantity > available;

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDeep,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    short
                        ? 'Only $available ${line.unit} left'
                        : '${line.quantity} ${line.unit} × ${Fmt.currency(line.rate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: short ? AppColors.danger : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Fmt.currency(line.amount),
              style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
            ),
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove item',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: highlight ? 15 : 14,
              color: highlight ? AppColors.primaryDeep : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Qty + rate editor shown while building a challan line.
class _LineSheet extends StatefulWidget {
  const _LineSheet({
    required this.item,
    required this.available,
    required this.gstRate,
    this.existing,
  });

  final StockItem item;
  final ChallanLine? existing;
  final int available;
  final double gstRate;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  late final TextEditingController _qty;
  late final TextEditingController _rate;
  String? _error;

  bool get _pricedPerWp => widget.item.isSolarModule;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(
      text: widget.existing == null ? '' : '${widget.existing!.quantity}',
    );
    // For panels the rate is ₹/Wp; otherwise ₹/unit.
    final initialRate = widget.existing != null
        ? (_pricedPerWp && widget.item.wattPeak > 0
            ? widget.existing!.rate / widget.item.wattPeak
            : widget.existing!.rate)
        : widget.item.sellingPrice;
    _rate = TextEditingController(text: initialRate.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _qty.dispose();
    _rate.dispose();
    super.dispose();
  }

  int get _quantity => int.tryParse(_qty.text.trim()) ?? 0;

  double get _rateValue => double.tryParse(_rate.text.trim()) ?? 0;

  /// Price for one piece (panels: Wp × ₹/Wp).
  double get _unitPrice =>
      _pricedPerWp ? widget.item.wattPeak * _rateValue : _rateValue;

  double get _taxable => _unitPrice * _quantity;

  double get _gstAmount => _taxable * widget.gstRate / 100;

  void _submit() {
    if (_quantity <= 0) {
      setState(() => _error = 'Enter a quantity greater than 0');
      return;
    }
    if (_quantity > widget.available) {
      setState(
        () => _error =
            'Only ${widget.available} ${widget.item.unit} available',
      );
      return;
    }
    if (_rate.text.trim().isEmpty || _rateValue <= 0) {
      setState(() => _error = 'Enter a rate greater than 0');
      return;
    }
    Navigator.of(context).pop(
      ChallanLine(
        itemId: widget.item.id,
        itemName: widget.item.name,
        sku: widget.item.sku,
        unit: widget.item.unit,
        quantity: _quantity,
        rate: _unitPrice,
        availableBefore: widget.available,
        gstRate: widget.gstRate,
        gstAmount: _gstAmount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ItemAvatar(item: widget.item, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.item.sku} • ${widget.available} ${widget.item.unit} available',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Quantity', style: theme.textTheme.labelMedium),
        const SizedBox(height: 7),
        Row(
          children: [
            IconAction(
              icon: Icons.remove_rounded,
              color: AppColors.danger,
              bg: AppColors.dangerSoft,
              size: 48,
              onTap: () {
                setState(() {
                  _qty.text = '${(_quantity - 1).clamp(0, 999999)}';
                  _error = null;
                });
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _qty,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22),
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(hintText: '0', counterText: ''),
              ),
            ),
            const SizedBox(width: 12),
            IconAction(
              icon: Icons.add_rounded,
              color: AppColors.success,
              bg: AppColors.successSoft,
              size: 48,
              onTap: () {
                setState(() {
                  _qty.text = '${_quantity + 1}';
                  _error = null;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _qty.text = '${widget.available}';
                _error = null;
              }),
              child: const Text('Use max'),
            ),
            const Spacer(),
            Text(
              'Taxable  ${Fmt.currency(_taxable)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.primaryDeep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _rate,
          label: _pricedPerWp
              ? 'Rate per Wp (₹)'
              : 'Rate per ${widget.item.unit} (₹)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.sell_rounded,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
          ],
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_pricedPerWp) ...[
          const SizedBox(height: 8),
          Text(
            '${widget.item.wattPeak} Wp × ${Fmt.currency(_rateValue)} = '
            '${Fmt.currency(_unitPrice)} / pc (excl. GST)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (widget.gstRate > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'GST @ ${widget.gstRate.toStringAsFixed(widget.gstRate == widget.gstRate.roundToDouble() ? 0 : 2)}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      Fmt.currency(_gstAmount),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('Total incl. GST',
                          style: theme.textTheme.titleSmall),
                    ),
                    Text(
                      Fmt.currency(_taxable + _gstAmount),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: AppColors.primaryDeep),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        AppButton(
          label: widget.existing == null ? 'Add to challan' : 'Update item',
          icon: Icons.add_rounded,
          onTap: _submit,
        ),
      ],
    );
  }
}
