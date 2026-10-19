import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../models/challan.dart';
import '../../providers/auth_providers.dart';
import '../../providers/stock_providers.dart';
import 'challan_form_screen.dart';
import 'challan_preview_screen.dart';

class ChallanListScreen extends ConsumerStatefulWidget {
  const ChallanListScreen({super.key});

  @override
  ConsumerState<ChallanListScreen> createState() => _ChallanListScreenState();
}

enum _ChallanSort { newest, oldest, customerAz, valueDesc }

class _ChallanListScreenState extends ConsumerState<ChallanListScreen> {
  final _search = TextEditingController();
  String _query = '';
  ChallanStatus? _status;
  _ChallanSort _sort = _ChallanSort.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _sortLabel => switch (_sort) {
    _ChallanSort.newest => 'Newest first',
    _ChallanSort.oldest => 'Oldest first',
    _ChallanSort.customerAz => 'Customer A → Z',
    _ChallanSort.valueDesc => 'Value: high first',
  };

  List<Challan> _apply(List<Challan> source) {
    final q = _query.trim().toLowerCase();
    final list = source.where((c) {
      final matchesQuery =
          q.isEmpty ||
          c.billTo.name.toLowerCase().contains(q) ||
          c.number.toLowerCase().contains(q) ||
          c.shipTo.siteProject.toLowerCase().contains(q) ||
          c.billTo.address.toLowerCase().contains(q) ||
          c.shipTo.address.toLowerCase().contains(q) ||
          c.billTo.phone.toLowerCase().contains(q) ||
          c.shipTo.phone.toLowerCase().contains(q) ||
          c.vehicleNo.toLowerCase().contains(q) ||
          c.notes.toLowerCase().contains(q) ||
          c.lines.any(
            (l) =>
                l.itemName.toLowerCase().contains(q) ||
                l.sku.toLowerCase().contains(q),
          );
      final matchesStatus = _status == null || c.status == _status;
      return matchesQuery && matchesStatus;
    }).toList();

    list.sort(
      (a, b) => switch (_sort) {
        _ChallanSort.newest => b.date.compareTo(a.date),
        _ChallanSort.oldest => a.date.compareTo(b.date),
        _ChallanSort.customerAz => a.billTo.name.toLowerCase().compareTo(
          b.billTo.name.toLowerCase(),
        ),
        _ChallanSort.valueDesc => b.totalValue.compareTo(a.totalValue),
      },
    );
    return list;
  }

  Future<void> _pickSort() async {
    final picked = await AppSheet.show<_ChallanSort>(
      context,
      title: 'Sort challans',
      subtitle: 'Choose how documents are ordered',
      builder: (context) => Column(
        children: [
          for (final s in _ChallanSort.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SheetOptionTile(
                title: switch (s) {
                  _ChallanSort.newest => 'Newest first',
                  _ChallanSort.oldest => 'Oldest first',
                  _ChallanSort.customerAz => 'Customer A → Z',
                  _ChallanSort.valueDesc => 'Value: high to low',
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ChallanFormScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(stockProvider).challans;
    final canCreate = can(ref, 'challanCreate');
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
                              'Delivery challans',
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
                      hintText: 'Search customer, site or number…',
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
                        for (final s in ChallanStatus.values)
                          if (all.any((c) => c.status == s))
                            _StatusChip(
                              label: s.label,
                              selected: _status == s,
                              count: all.where((c) => c.status == s).length,
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
                          icon: Icons.receipt_long_rounded,
                          title: 'No challans here',
                          message: 'Create a delivery challan to get started.',
                          actionLabel: 'New challan',
                          onAction: _openNew,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return AppCard(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ChallanPreviewScreen(number: c.number),
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
                                      Icons.receipt_long_rounded,
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
                                          c.number,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(letterSpacing: 0.3),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          c.billTo.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusPill(
                                    label: c.status.label.toUpperCase(),
                                    color: switch (c.status) {
                                      ChallanStatus.draft =>
                                        AppColors.textSecondary,
                                      ChallanStatus.issued => AppColors.info,
                                      ChallanStatus.cancelled =>
                                        AppColors.danger,
                                    },
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
                                        label: Fmt.date(c.date),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Flexible(
                                      child: _Meta(
                                        icon: Icons.inventory_2_rounded,
                                        label: '${c.lines.length} items',
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      Fmt.currency(c.totalValue),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: AppColors.primaryDeep,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (c.status == ChallanStatus.cancelled) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerSoft,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _CancelledRow(
                                        icon: Icons.person_rounded,
                                        label: 'Cancelled by',
                                        value: c.cancelledByName.isEmpty
                                            ? '—'
                                            : c.cancelledByName,
                                      ),
                                      if (c.cancelledAt != null) ...[
                                        const SizedBox(height: 6),
                                        _CancelledRow(
                                          icon: Icons.schedule_rounded,
                                          label: 'On',
                                          value: Fmt.dayTime(c.cancelledAt!),
                                        ),
                                      ],
                                      if (c.cancelRemarks.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        _CancelledRow(
                                          icon: Icons.notes_rounded,
                                          label: 'Reason',
                                          value: c.cancelRemarks,
                                        ),
                                      ],
                                    ],
                                  ),
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
                'New challan',
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

class _CancelledRow extends StatelessWidget {
  const _CancelledRow({
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
