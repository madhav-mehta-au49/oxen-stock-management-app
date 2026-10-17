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
import '../../providers/settings_providers.dart';
import '../../providers/stock_providers.dart';
import '../../services/challan_pdf_service.dart';
import 'challan_format_picker.dart';
import 'challan_form_screen.dart';

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
      ref.read(companyProfileProvider).value ?? CompanyProfile.fallback;

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

  void _goHome() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = ref
        .watch(stockProvider)
        .challans
        .where((c) => c.number == widget.number);
    final challan = matches.isEmpty ? null : matches.first;

    if (challan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Challan')),
        body: const EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Challan not found',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Delivery challan'),
        actions: [
          IconButton(
            tooltip: 'Preview PDF',
            onPressed: _working
                ? null
                : () =>
                    _run(() => ChallanPdfService.preview(challan, _company)),
            icon: const Icon(Icons.picture_as_pdf_rounded),
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
                gradient: AppColors.successGradient,
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
                    child: const Icon(
                      Icons.check_rounded,
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
                          'Challan issued',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
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
                          'Stock auto-deducted for ${challan.lines.length} item'
                          '${challan.lines.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Ship to', style: theme.textTheme.titleSmall),
                      ),
                      StatusPill(
                        label: challan.status.label.toUpperCase(),
                        color: switch (challan.status) {
                          ChallanStatus.draft => AppColors.textSecondary,
                          ChallanStatus.issued => AppColors.info,
                        },
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(challan.customerName, style: theme.textTheme.titleMedium),
                  if (challan.siteName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(challan.siteName, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 6),
                  Text(challan.address, style: theme.textTheme.bodySmall),
                  const Divider(height: 22),
                  _kv('Contact', challan.contact.isEmpty ? '—' : challan.contact),
                  _kv('Date', Fmt.date(challan.date)),
                  _kv(
                    'Vehicle',
                    challan.vehicleNo.isEmpty ? '—' : challan.vehicleNo,
                  ),
                  _kv('Prepared by', challan.preparedBy),
                  _kv('Format', '${challan.format.label} template'),
                  if (challan.notes.isNotEmpty) _kv('Remarks', challan.notes),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionHeader(title: 'PDF format'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Switch the layout used the next time this PDF is generated.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          'QTY',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 78,
                        child: Text(
                          'AMOUNT',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.8,
                          ),
                        ),
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
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${challan.lines[i].sku} • ${Fmt.currency(challan.lines[i].rate)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              '${challan.lines[i].quantity}',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 78,
                            child: Text(
                              Fmt.currency(challan.lines[i].amount),
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
                            Fmt.currency(challan.taxableValue)),
                        for (final entry in challan.gstBreakdown.entries)
                          _totalRow(
                            theme,
                            'GST @ ${entry.key.toStringAsFixed(entry.key == entry.key.roundToDouble() ? 0 : 2)}%',
                            Fmt.currency(entry.value),
                          ),
                        if (challan.gstBreakdown.isEmpty)
                          _totalRow(theme, 'GST', Fmt.currency(0)),
                        const Divider(height: 18),
                        _totalRow(
                          theme,
                          'Grand total',
                          Fmt.currency(challan.grandTotal),
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Stock deductions'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < challan.lines.length; i++) ...[
                    if (i > 0) const Divider(indent: 44),
                    Builder(builder: (context) {
                      final line = challan.lines[i];
                      final current =
                          ref.watch(stockProvider).itemById(line.itemId);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.dangerSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: AppColors.danger,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                line.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '−${line.quantity}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.danger,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 62,
                              child: Text(
                                'bal ${current?.quantity ?? 0}',
                                textAlign: TextAlign.right,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Preview & print PDF',
              icon: Icons.picture_as_pdf_rounded,
              loading: _working,
              onTap: () =>
                  _run(() => ChallanPdfService.preview(challan, _company)),
            ),
            const SizedBox(height: 10),
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
