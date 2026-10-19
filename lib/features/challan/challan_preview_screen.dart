import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/toast.dart';
import '../../models/challan.dart';
import '../../models/company_profile.dart';
import '../../providers/auth_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/stock_providers.dart';
import '../../services/challan_pdf_service.dart';
import 'challan_form_screen.dart';
import 'challan_format_picker.dart';

/// Success + document view for a just-issued (or historical) challan.
class ChallanPreviewScreen extends ConsumerStatefulWidget {
  const ChallanPreviewScreen({super.key, required this.number});

  final String number;

  @override
  ConsumerState<ChallanPreviewScreen> createState() =>
      _ChallanPreviewScreenState();
}

class _ChallanPreviewScreenState extends ConsumerState<ChallanPreviewScreen> {
  bool _working = false;

  CompanyProfile get _company =>
      ref.read(companyProfileProvider).valueOrNull ?? CompanyProfile.fallback;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not generate the PDF. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _goHome() => Navigator.of(context).popUntil((r) => r.isFirst);

  Future<void> _cancel(Challan challan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel challan?'),
        content: Text(
          '${challan.number} will be marked Cancelled and its stock will be '
          'restored. The record is kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancel challan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref.read(stockProvider.notifier).cancelChallan(challan);
    if (!mounted) return;
    if (result.ok) {
      AppToast.success(context, result.message);
    } else {
      AppToast.error(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Challan? maybe;
    for (final c in ref.watch(stockProvider).challans) {
      if (c.number == widget.number) {
        maybe = c;
        break;
      }
    }
    final isAdmin = ref.watch(userProfileProvider).value?.isAdmin ?? false;

    if (maybe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Challan')),
        body: const EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Challan not found',
        ),
      );
    }
    final challan = maybe;

    final cancelled = challan.isCancelled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Delivery challan'),
        actions: [
          if (!cancelled)
            IconButton(
              tooltip: 'Preview PDF',
              onPressed: _working
                  ? null
                  : () => _run(() => ChallanPdfService.preview(challan, _company)),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: cancelled
                    ? const LinearGradient(colors: [
                        AppColors.danger,
                        Color(0xFF8E1D1D),
                      ])
                    : AppColors.successGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x332E7D32),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cancelled ? Icons.cancel_rounded : Icons.check_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cancelled ? 'Challan cancelled' : 'Challan issued',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          challan.number,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cancelled
                              ? 'Stock has been restored.'
                              : 'Stock deducted for ${challan.lines.length} item'
                                  '${challan.lines.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _partyCard(theme, 'Bill To', challan.billTo, showSite: false),
            const SizedBox(height: 12),
            _partyCard(theme, 'Ship To', challan.shipTo, showSite: true),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Challan details',
                            style: theme.textTheme.titleSmall),
                      ),
                      StatusPill(
                        label: challan.status.label.toUpperCase(),
                        color: switch (challan.status) {
                          ChallanStatus.issued => AppColors.info,
                          ChallanStatus.cancelled => AppColors.danger,
                          ChallanStatus.draft => AppColors.textSecondary,
                        },
                        dense: true,
                      ),
                    ],
                  ),
                  const Divider(height: 22),
                  _kv('Date', Fmt.date(challan.date)),
                  _kv('Vehicle',
                      challan.vehicleNo.isEmpty ? '—' : challan.vehicleNo),
                  _kv('Prepared by', challan.preparedBy),
                  _kv('Format', '${challan.format.label} template'),
                  if (challan.notes.isNotEmpty) _kv('Remarks', challan.notes),
                ],
              ),
            ),
            if (!cancelled) ...[
              const SizedBox(height: 14),
              const SectionHeader(title: 'PDF format'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Switch the layout used the next time this PDF is generated.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ChallanFormatPicker(
                      dense: true,
                      value: challan.format,
                      onChanged: (format) async {
                        if (format == challan.format) return;
                        final result = await ref
                            .read(stockProvider.notifier)
                            .setChallanFormat(challan.number, format);
                        if (!context.mounted) return;
                        if (result.ok) {
                          AppToast.success(
                            context,
                            'PDF will be generated in ${format.label} format',
                          );
                        } else {
                          AppToast.error(context, result.message);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SectionHeader(
              title: 'Items',
              trailing: StatusPill(
                label: '${challan.totalUnits} UNITS',
                color: AppColors.textSecondary,
                dense: true,
              ),
            ),
            AppCard(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 36),
                      Expanded(
                        child: Text(
                          'DESCRIPTION',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(letterSpacing: 0.8),
                        ),
                      ),
                      SizedBox(
                        width: 54,
                        child: Text('QTY',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(letterSpacing: 0.8)),
                      ),
                      SizedBox(
                        width: 84,
                        child: Text('AMOUNT',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(letterSpacing: 0.8)),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  for (var i = 0; i < challan.lines.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDeep,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  challan.lines[i].itemName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${challan.lines[i].sku} • ${Fmt.price(challan.lines[i].rate)}'
                                  '${challan.lines[i].gstRate > 0 ? ' • GST ${challan.lines[i].gstRate.toStringAsFixed(0)}%' : ''}',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 54,
                            child: Text(
                              '${challan.lines[i].quantity}',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontSize: 13),
                            ),
                          ),
                          SizedBox(
                            width: 84,
                            child: Text(
                              Fmt.price(challan.lines[i].totalAmount),
                              textAlign: TextAlign.right,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 13,
                                color: AppColors.primaryDeep,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                    child: Column(
                      children: [
                        _totalRow(theme, 'Taxable value',
                            Fmt.price(challan.taxableValue)),
                        for (final entry in challan.gstBreakdown.entries)
                          _totalRow(
                            theme,
                            'GST @ ${entry.key.toStringAsFixed(entry.key == entry.key.roundToDouble() ? 0 : 2)}%',
                            Fmt.price(entry.value),
                          ),
                        if (challan.gstBreakdown.isEmpty)
                          _totalRow(theme, 'GST', Fmt.price(0)),
                        if (challan.roundOff != 0)
                          _totalRow(
                            theme,
                            'Round off',
                            '${challan.roundOff >= 0 ? '+' : '−'}${Fmt.price(challan.roundOff.abs())}',
                          ),
                        const Divider(height: 18),
                        _totalRow(
                          theme,
                          'Grand total',
                          Fmt.price(challan.grandTotal),
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (isAdmin && challan.isIssued) ...[
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Edit',
                      dense: true,
                      height: 48,
                      variant: AppButtonVariant.outline,
                      icon: Icons.edit_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChallanFormScreen(existing: challan),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'Cancel challan',
                      dense: true,
                      height: 48,
                      variant: AppButtonVariant.danger,
                      icon: Icons.cancel_rounded,
                      onTap: () => _cancel(challan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (!cancelled)
              AppButton(
                label: 'Preview & print PDF',
                icon: Icons.picture_as_pdf_outlined,
                loading: _working,
                onTap: () =>
                    _run(() => ChallanPdfService.preview(challan, _company)),
              ),
            if (!cancelled) const SizedBox(height: 10),
            if (!cancelled)
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Share',
                      dense: true,
                      height: 48,
                      variant: AppButtonVariant.outline,
                      icon: Icons.share_rounded,
                      loading: _working,
                      onTap: () =>
                          _run(() => ChallanPdfService.share(challan, _company)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'New challan',
                      dense: true,
                      height: 48,
                      variant: AppButtonVariant.outline,
                      icon: Icons.add_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChallanFormScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Back to dashboard',
              variant: AppButtonVariant.ghost,
              onTap: _goHome,
            ),
          ],
        ),
      ),
    );
  }

  Widget _partyCard(
    ThemeData theme,
    String title,
    ChallanParty party, {
    required bool showSite,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                showSite ? Icons.local_shipping_rounded : Icons.business_rounded,
                size: 18,
                color: AppColors.primaryDeep,
              ),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(party.name.isEmpty ? '—' : party.name,
              style: theme.textTheme.titleMedium),
          if (showSite && party.siteProject.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(party.siteProject, style: theme.textTheme.bodyMedium),
          ],
          if (party.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(party.address, style: theme.textTheme.bodySmall),
          ],
          const Divider(height: 20),
          if (party.phone.isNotEmpty) _kv('Contact', party.phone),
          if (party.gstin.isNotEmpty) _kv('GSTIN', party.gstin),
          if (party.contactPerson.isNotEmpty)
            _kv('Contact person', party.contactPerson),
        ],
      ),
    );
  }

  Widget _totalRow(
    ThemeData theme,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: highlight
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodySmall,
            ),
          ),
          Text(
            value,
            style: highlight
                ? theme.textTheme.titleMedium
                    ?.copyWith(color: AppColors.primaryDeep)
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
