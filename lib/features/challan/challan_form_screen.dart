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
import '../../data/repositories/customer_repository.dart';
import '../../models/category.dart';
import '../../models/challan.dart';
import '../../models/customer.dart';
import '../../models/stock_item.dart';
import '../../providers/category_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/customer_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/stock_providers.dart';
import 'challan_format_picker.dart';
import 'challan_preview_screen.dart';

/// Create or edit a delivery challan (admin-only edit).
class ChallanFormScreen extends ConsumerStatefulWidget {
  const ChallanFormScreen({super.key, this.existing});

  /// The challan being edited (null when creating a new one).
  final Challan? existing;

  @override
  ConsumerState<ChallanFormScreen> createState() => _ChallanFormScreenState();
}

class _ChallanFormScreenState extends ConsumerState<ChallanFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _billName = TextEditingController();
  final _billAddress = TextEditingController();
  final _billPhone = TextEditingController();
  final _billGstin = TextEditingController();
  final _billContact = TextEditingController();

  final _shipName = TextEditingController();
  final _shipSite = TextEditingController();
  final _shipAddress = TextEditingController();
  final _shipPhone = TextEditingController();
  final _shipGstin = TextEditingController();
  final _shipContact = TextEditingController();

  final _vehicle = TextEditingController();
  final _notes = TextEditingController();

  Customer? _customer;
  bool _sameAsBillTo = false;
  bool _saving = false;

  String _number = '';
  DateTime _date = DateTime.now();
  ChallanFormat _format = ChallanFormat.letterhead;
  final List<ChallanLine> _lines = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _number = e.number;
      _date = e.date;
      _format = e.format;
      _sameAsBillTo = e.sameAsBillTo;
      _lines.addAll(e.lines);
      _vehicle.text = e.vehicleNo;
      _notes.text = e.notes;
      _fillBill(e.billTo);
      _fillShip(e.shipTo);
      _resolveCustomer(e.customerId);
    } else {
      _format =
          ref.read(appSettingsProvider).valueOrNull?.defaultChallanFormat ??
          ChallanFormat.letterhead;
      _loadNumber();
    }
  }

  void _resolveCustomer(String id) {
    final customers = ref.read(customersProvider).valueOrNull ?? const [];
    for (final c in customers) {
      if (c.id == id) {
        _customer = c;
        return;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _billName,
      _billAddress,
      _billPhone,
      _billGstin,
      _billContact,
      _shipName,
      _shipSite,
      _shipAddress,
      _shipPhone,
      _shipGstin,
      _shipContact,
      _vehicle,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadNumber() async {
    try {
      final number = await ref.read(stockProvider.notifier).nextChallanNumber();
      if (mounted) setState(() => _number = number);
    } catch (_) {
      // Leave the placeholder; the real number is assigned on issue.
    }
  }

  void _fillBill(ChallanParty p) {
    _billName.text = p.name;
    _billAddress.text = p.address;
    _billPhone.text = p.phone;
    _billGstin.text = p.gstin;
    _billContact.text = p.contactPerson;
  }

  void _fillShip(ChallanParty p) {
    _shipName.text = p.name;
    _shipSite.text = p.siteProject;
    _shipAddress.text = p.address;
    _shipPhone.text = p.phone;
    _shipGstin.text = p.gstin;
    _shipContact.text = p.contactPerson;
  }

  void _applyCustomer(Customer c) {
    setState(() {
      _customer = c;
      _billName.text = c.name;
      _billAddress.text = c.billToAddress;
      _billPhone.text = c.phone;
      _billGstin.text = c.gstin;
      _billContact.text = c.contactPerson;
      _syncBillToShip();
    });
  }

  Future<void> _pickCustomer() async {
    final customers = ref.read(customersProvider).valueOrNull ?? const [];
    final picked = await AppSheet.show<String>(
      context,
      title: 'Customer',
      subtitle: 'Select a saved customer or add a new one',
      builder: (context) => Column(
        children: [
          SheetOptionTile(
            title: 'New customer',
            subtitle: 'Enter bill-to details for a new customer',
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.success,
                size: 20,
              ),
            ),
            onTap: () => Navigator.of(context).pop('__new__'),
          ),
          const SizedBox(height: 8),
          for (final c in customers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SheetOptionTile(
                title: c.name,
                subtitle: c.phone,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryDeep,
                    size: 20,
                  ),
                ),
                selected: _customer?.id == c.id,
                onTap: () => Navigator.of(context).pop(c.id),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    if (picked == '__new__') {
      setState(() {
        _customer = null;
        _billName.clear();
        _billAddress.clear();
        _billPhone.clear();
        _billGstin.clear();
        _billContact.clear();
      });
      return;
    }
    Customer? c;
    for (final x in customers) {
      if (x.id == picked) {
        c = x;
        break;
      }
    }
    if (c != null) _applyCustomer(c);
  }

  void _syncBillToShip() {
    if (!_sameAsBillTo) return;
    _shipName.text = _billName.text;
    _shipAddress.text = _billAddress.text;
    _shipPhone.text = _billPhone.text;
    _shipGstin.text = _billGstin.text;
    _shipContact.text = _billContact.text;
  }

  int _availableFor(String itemId) =>
      ref.read(stockProvider).itemById(itemId)?.quantity ?? 0;

  Future<void> _addItem() async {
    final item = await pickStockItem(
      context,
      filter: (i) => i.quantity > 0 || _lines.any((l) => l.itemId == i.id),
    );
    if (item == null) return;
    final idx = _lines.indexWhere((l) => l.itemId == item.id);
    await _editLine(item, existing: idx == -1 ? null : _lines[idx], index: idx);
  }

  Future<void> _editLine(
    StockItem item, {
    ChallanLine? existing,
    required int index,
  }) async {
    final available = _availableFor(item.id) + (existing?.quantity ?? 0);
    final categories =
        ref.read(categoriesProvider).valueOrNull ?? Category.defaults;
    Category? cat;
    for (final c in categories) {
      if (c.id == item.categoryId) {
        cat = c;
        break;
      }
    }
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

  ChallanParty _billParty() => ChallanParty(
    name: _billName.text.trim(),
    address: _billAddress.text.trim(),
    phone: _billPhone.text.trim(),
    gstin: _billGstin.text.trim(),
    contactPerson: _billContact.text.trim(),
  );

  ChallanParty _shipParty() => ChallanParty(
    name: _shipName.text.trim(),
    siteProject: _shipSite.text.trim(),
    address: _shipAddress.text.trim(),
    phone: _shipPhone.text.trim(),
    gstin: _shipGstin.text.trim(),
    contactPerson: _shipContact.text.trim(),
  );

  /// Returns the customer id to store on the challan (may be empty). Saving the
  /// customer is best-effort: a permission/network error or a duplicate name
  /// must never block issuing the challan itself.
  Future<String> _ensureCustomer() async {
    final bill = _billParty();
    final name = bill.name.trim();
    if (name.isEmpty) return _customer?.id ?? '';

    final repo = const CustomerRepository();

    // Editing an already-selected customer.
    if (_customer != null) {
      try {
        await repo.update(
          _customer!.copyWith(
            name: name,
            phone: bill.phone,
            gstin: bill.gstin,
            billToAddress: bill.address,
            contactPerson: bill.contactPerson,
          ),
        );
      } catch (_) {}
      return _customer!.id;
    }

    // Only attempt to save a brand-new customer when permitted.
    if (!can(ref, 'customerCreate')) return '';

    try {
      final id = await repo.create(
        Customer(
          id: '',
          name: name,
          phone: bill.phone,
          gstin: bill.gstin,
          billToAddress: bill.address,
          contactPerson: bill.contactPerson,
          createdAt: DateTime.now(),
        ),
      );
      if (id != null) return id;

      // The name already exists — reuse that customer instead of failing.
      final all = await repo.getAll();
      final key = name.toLowerCase();
      for (final c in all) {
        if (c.name.trim().toLowerCase() == key) return c.id;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _confirm() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      AppToast.error(context, 'Add at least one item to the challan');
      return;
    }

    for (final l in _lines) {
      final available =
          _availableFor(l.itemId) +
          (widget.existing?.lines
                  .where((x) => x.itemId == l.itemId)
                  .fold<int>(0, (s, x) => s + x.quantity) ??
              0);
      if (l.quantity > available) {
        AppToast.error(
          context,
          '${l.itemName}: only $available ${l.unit} available',
        );
        return;
      }
    }

    setState(() => _saving = true);
    final customerId = await _ensureCustomer();
    if (!mounted) return;

    final challan = Challan(
      id: widget.existing?.id ?? _number,
      number: widget.existing?.number ?? _number,
      customerId: customerId,
      billTo: _billParty(),
      shipTo: _shipParty(),
      sameAsBillTo: _sameAsBillTo,
      date: _date,
      lines: List.unmodifiable(_lines),
      status: ChallanStatus.issued,
      vehicleNo: _vehicle.text.trim(),
      notes: _notes.text.trim(),
      format: _format,
    );

    if (_isEdit) {
      final result = await ref
          .read(stockProvider.notifier)
          .editChallan(oldChallan: widget.existing!, updated: challan);
      if (!mounted) return;
      setState(() => _saving = false);
      if (!result.ok) {
        AppToast.error(context, result.message);
        return;
      }
      AppToast.success(context, result.message);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ChallanPreviewScreen(
            number: challan.number,
            initial: challan.copyWith(status: ChallanStatus.issued),
          ),
        ),
      );
      return;
    }

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
        builder: (_) => ChallanPreviewScreen(
          number: issue.number,
          initial: challan.copyWith(
            id: issue.number.replaceAll('/', '-'),
            number: issue.number,
            status: ChallanStatus.issued,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalUnits = _lines.fold<int>(0, (s, l) => s + l.quantity);
    final taxable = _lines.fold<double>(0, (s, l) => s + l.amount);
    final gst = _lines.fold<double>(0, (s, l) => s + l.gstAmount);
    final gross = taxable + gst;
    final grand = gross.roundToDouble();
    final roundOff = grand - gross;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit challan' : 'New delivery challan'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              _number.isEmpty ? '…' : _number,
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
                          _isEdit ? 'EDITING' : 'AUTO',
                          style: const TextStyle(
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
                const SectionHeader(title: 'Customer'),
                AppCard(
                  child: AppPickerField(
                    label: 'Customer',
                    value: _customer?.name ?? '',
                    hint: 'Select a customer or add new',
                    prefixIcon: Icons.person_rounded,
                    required: false,
                    onTap: _pickCustomer,
                  ),
                ),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Bill To'),
                AppCard(
                  child: Column(
                    children: [
                      _field(
                        _billName,
                        'Customer name',
                        Icons.business_rounded,
                        onChanged: (_) => _syncBillToShip(),
                      ),
                      const SizedBox(height: 14),
                      _field(
                        _billAddress,
                        'Address',
                        Icons.map_rounded,
                        maxLines: 2,
                        onChanged: (_) => _syncBillToShip(),
                      ),
                      const SizedBox(height: 14),
                      _field(
                        _billPhone,
                        'Contact number',
                        Icons.phone_rounded,
                        keyboard: TextInputType.phone,
                        onChanged: (_) => _syncBillToShip(),
                      ),
                      const SizedBox(height: 14),
                      _field(
                        _billGstin,
                        'GSTIN',
                        Icons.receipt_long_rounded,
                        onChanged: (_) => _syncBillToShip(),
                      ),
                      const SizedBox(height: 14),
                      _field(
                        _billContact,
                        'Contact person',
                        Icons.badge_rounded,
                        onChanged: (_) => _syncBillToShip(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Ship To'),
                AppCard(
                  child: Column(
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _sameAsBillTo,
                        onChanged: (v) => setState(() {
                          _sameAsBillTo = v ?? false;
                          _syncBillToShip();
                        }),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Same as Bill To'),
                        subtitle: const Text(
                          'Ship-To details copied from Bill To',
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      _field(
                        _shipName,
                        'Customer name',
                        Icons.business_rounded,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        _shipSite,
                        'Site / project',
                        Icons.location_on_rounded,
                        required: false,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        _shipAddress,
                        'Address',
                        Icons.map_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        _shipPhone,
                        'Contact number',
                        Icons.phone_rounded,
                        keyboard: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      _field(_shipGstin, 'GSTIN', Icons.receipt_long_rounded),
                      const SizedBox(height: 14),
                      _field(
                        _shipContact,
                        'Contact person',
                        Icons.badge_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Transport'),
                AppCard(
                  child: Column(
                    children: [
                      _field(
                        _vehicle,
                        'Vehicle number',
                        Icons.local_shipping_rounded,
                        required: false,
                      ),
                      const SizedBox(height: 14),
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
                        'Choose the PDF layout — the challan is generated in this format.',
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
                      message:
                          'Add items — stock is deducted when you confirm.',
                      actionLabel: 'Add first item',
                      onAction: _addItem,
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
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
                            onRemove: () => setState(() => _lines.removeAt(i)),
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
                            label: 'Items',
                            value: '${_lines.length}',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.border,
                          ),
                          _SummaryCell(label: 'Units', value: '$totalUnits'),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCell(
                              label: 'Taxable value',
                              value: Fmt.price(taxable),
                            ),
                          ),
                          Expanded(
                            child: _SummaryCell(
                              label: 'GST',
                              value: Fmt.price(gst),
                            ),
                          ),
                        ],
                      ),
                      if (roundOff != 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCell(
                                label: 'Round off',
                                value:
                                    '${roundOff >= 0 ? '+' : '−'}${Fmt.price(roundOff.abs())}',
                              ),
                            ),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCell(
                              label: 'Grand total (incl. GST)',
                              value: Fmt.price(grand),
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
                          _isEdit
                              ? 'Saving adjusts stock to match the new lines.'
                              : 'Confirming creates the challan and deducts stock.',
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
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: AppButton(
          label: _isEdit ? 'Save changes' : 'Confirm & issue challan',
          variant: AppButtonVariant.primary,
          icon: Icons.check_circle_outline_rounded,
          loading: _saving,
          onTap: _confirm,
        ),
      ),
    );
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

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboard,
    bool required = true,
    ValueChanged<String>? onChanged,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: label,
      prefixIcon: icon,
      maxLines: maxLines,
      keyboardType: keyboard,
      onChanged: onChanged,
      required: required,
      validator: required
          ? (v) => (v ?? '').trim().isEmpty ? '$label is required' : null
          : null,
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
                        : '${line.quantity} ${line.unit} × ${Fmt.price(line.rate)}'
                              '${line.gstRate > 0 ? ' + GST ${line.gstRate.toStringAsFixed(0)}%' : ''}',
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
              Fmt.price(line.totalAmount),
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
    final initialRate = widget.existing != null
        ? (_pricedPerWp && widget.item.wattPeak > 0
              ? widget.existing!.rate / widget.item.wattPeak
              : widget.existing!.rate)
        : widget.item.sellingPrice;
    _rate = TextEditingController(text: Fmt.decimal(initialRate));
  }

  @override
  void dispose() {
    _qty.dispose();
    _rate.dispose();
    super.dispose();
  }

  int get _quantity => int.tryParse(_qty.text.trim()) ?? 0;

  double get _rateValue => double.tryParse(_rate.text.trim()) ?? 0;

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
        () => _error = 'Only ${widget.available} ${widget.item.unit} available',
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
              onTap: () => setState(() {
                _qty.text = '${(_quantity - 1).clamp(0, 999999)}';
                _error = null;
              }),
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
              size: 48,
              onTap: () => setState(() {
                _qty.text = '${_quantity + 1}';
                _error = null;
              }),
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
              'Taxable  ${Fmt.price(_taxable)}',
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
            '${widget.item.wattPeak} Wp × ${Fmt.price(_rateValue)} = '
            '${Fmt.price(_unitPrice)} / pc (excl. GST)',
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
                      Fmt.price(_gstAmount),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total incl. GST',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      Fmt.price(_taxable + _gstAmount),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.primaryDeep,
                      ),
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
