import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../models/proforma.dart';
import '../../providers/auth_providers.dart';
import '../../providers/stock_providers.dart';
import '../challan/challan_form_screen.dart';
import 'proforma_preview_screen.dart';

/// List of proforma invoices (quotations).
class ProformaListScreen extends ConsumerStatefulWidget {
  const ProformaListScreen({super.key});

  @override
  ConsumerState<ProformaListScreen> createState() => _ProformaListScreenState();
}

enum _ProformaSort { newest, oldest, customerAz, valueDesc }

class _ProformaListScreenState extends ConsumerState<ProformaListScreen> {
  final _search = TextEditingController();
  String _query = '';
  ProformaStatus? _status;
  _ProformaSort _sort = _ProformaSort.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _sortLabel => switch (_sort) {
    _ProformaSort.newest => 'Newest first',
    _ProformaSort.oldest => 'Oldest first',
    _ProformaSort.customerAz => 'Customer A → Z',
    _ProformaSort.valueDesc => 'Value: high first',
  };

  List<Proforma> _apply(List<Proforma> source) {
    final q = _query.trim().toLowerCase();
    final list = source.where((p) {
      final matchesQuery =
          q.isEmpty ||
          p.billTo.name.toLowerCase().contains(q) ||
          p.number.toLowerCase().contains(q) ||
          p.shipTo.siteProject.toLowerCase().contains(q) ||
          p.billTo.address.toLowerCase().contains(q) ||
          p.billTo.phone.toLowerCase().contains(q) ||
          p.vehicleNo.toLowerCase().contains(q) ||
          p.notes.toLowerCase().contains(q) ||
          p.lines.any(
            (l) =>
                l.itemName.toLowerCase().contains(q) ||
                l.sku.toLowerCase().contains(q),
          );
      final matchesStatus = _status == null || p.status == _status;
      return matchesQuery && matchesStatus;
    }).toList();

    list.sort(
      (a, b) => switch (_sort) {
        _ProformaSort.newest => b.date.compareTo(a.date),
        _ProformaSort.oldest => a.date.compareTo(b.date),
        _ProformaSort.customerAz => a.billTo.name.toLowerCase().compareTo(
          b.billTo.name.toLowerCase(),
        ),
        _ProformaSort.valueDesc => b.totalValue.compareTo(a.totalValue),
      },
    );
    return list;
  }

  Future<void> _pickSort() async {
    final picked = await AppSheet.show<_ProformaSort>(
      context,
      title: 'Sort proformas',
      subtitle: 'Choose how documents are ordered',
      builder: (context) => Column(
        children: [
          for (final s in _ProformaSort.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SheetOptionTile(
                title: switch (s) {
                  _ProformaSort.newest => 'Newest first',
                  _ProformaSort.oldest => 'Oldest first',
                  _ProformaSort.customerAz => 'Customer A → Z',
                  _ProformaSort.valueDesc => 'Value: high to low',
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

  void _openNew() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ChallanFormScreen(proformaMode: true),
      ),
    );
  }

  Color _statusColor(ProformaStatus s) => switch (s) {
    ProformaStatus.issued => AppColors.info,
    ProformaStatus.converted => AppColors.success,
    ProformaStatus.cancelled => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(proformasProvider);
    final canCreate = can(ref, 'piCreate');
    final list = _apply(all);

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
                              'Proforma invoices',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${list.length} of ${all.length} • $_sortLabel',
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search customer, item or number…',
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
                        _StatusChip(
                          label: 'All',
                          selected: _status == null,
                          onTap: () => setState(() => _status = null),
                        ),
                        for (final s in ProformaStatus.values)
                          if (all.any((p) => p.status == s))
                            _StatusChip(
                              label: s.label,
                              selected: _status == s,
                              count: all.where((p) => p.status == s).length,
                              onTap: () => setState(
                                () => _status = _status == s ? null : s,
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.only(top: 40),
                      children: [
                        EmptyState(
                          icon: Icons.request_quote_rounded,
                          title: 'No proforma invoices here',
                          message:
                              'Create a proforma invoice to quote a customer.',
                          actionLabel: canCreate ? 'New proforma' : null,
                          onAction: canCreate ? _openNew : null,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final p = list[i];
                        return AppCard(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProformaPreviewScreen(number: p.number),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.request_quote_rounded,
                                      color: AppColors.primaryDeep,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.number,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(letterSpacing: 0.3),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          p.billTo.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusPill(
                                    label: p.status.label.toUpperCase(),
                                    color: _statusColor(p.status),
                                    dense: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: _Meta(
                                        icon: Icons.calendar_today_rounded,
                                        label: Fmt.date(p.date),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Flexible(
                                      child: _Meta(
                                        icon: Icons.inventory_2_rounded,
                                        label: '${p.lines.length} items',
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      Fmt.currency(p.totalValue),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: AppColors.primaryDeep,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (p.isConverted &&
                                  p.challanNumber.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 15,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Converted to challan ${p.challanNumber}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (p.isCancelled &&
                                  p.cancelRemarks.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Reason: ${p.cancelRemarks}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openNew,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New proforma',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontSize: 10.5),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

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
            count == null ? label : '$label ($count)',
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
