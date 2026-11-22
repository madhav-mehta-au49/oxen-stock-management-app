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
import '../../models/proforma.dart';
import '../../providers/auth_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/stock_providers.dart';
import '../../services/challan_pdf_service.dart';
import '../challan/challan_form_screen.dart';
import '../challan/challan_preview_screen.dart';

/// View a proforma invoice, share its PDF, edit, cancel or convert to challan.
class ProformaPreviewScreen extends ConsumerStatefulWidget {
  const ProformaPreviewScreen({super.key, required this.number, this.initial});

  final String number;

  /// The just-saved proforma, shown immediately while the stream catches up.
  final Proforma? initial;

  @override
  ConsumerState<ProformaPreviewScreen> createState() =>
      _ProformaPreviewScreenState();
}

class _ProformaPreviewScreenState extends ConsumerState<ProformaPreviewScreen> {
  bool _working = false;

  CompanyProfile get _company =>
      ref.read(companyProfileProvider).valueOrNull ?? CompanyProfile.fallback;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          'Could not generate the PDF. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancel(Proforma proforma) async {
    final remarks = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Cancel proforma?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${proforma.number} will be marked Cancelled. The record is kept. '
                'This cannot be undone.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: remarks,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g. Customer declined',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                if (remarks.text.trim().isEmpty) {
                  setDialog(() => error = 'Please enter a reason');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Cancel proforma'),
            ),
          ],
        ),
      ),
    );
    final reason = remarks.text.trim();
    remarks.dispose();
    if (confirmed != true) return;
    final res = await ref
        .read(stockProvider.notifier)
        .cancelProforma(proforma, remarks: reason);
    if (!mounted) return;
    if (res.ok) {
      AppToast.success(context, res.message);
    } else {
      AppToast.error(context, res.message);
    }
  }

  Future<void> _convert(Proforma proforma) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Convert to challan?'),
        content: Text(
          'Proforma ${proforma.number} will be converted into a delivery challan '
          'with the same customer and items. Stock will be deducted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    // Pre-fill a challan from the proforma; the user confirms/edits and issues.
    // On issue the proforma is marked converted and linked.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChallanFormScreen(convertFrom: proforma),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Proforma? maybe = widget.initial;
    for (final p in ref.watch(proformasProvider)) {
      if (p.number == widget.number) {
        maybe = p;
        break;
      }
    }
    final canEdit = can(ref, 'piEdit');
    final canCancel = can(ref, 'piDelete');
    final canConvert = can(ref, 'piConvert');

    if (maybe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proforma')),
        body: const EmptyState(
          icon: Icons.request_quote_rounded,
          title: 'Proforma not found',
        ),
      );
    }
    final proforma = maybe;

    final converted = proforma.isConverted;
    final cancelled = proforma.isCancelled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Proforma invoice'),
        actions: [
          if (!cancelled)
            IconButton(
              tooltip: 'Preview PDF',
              onPressed: _working
                  ? null
                  : () => _run(
                      () =>
                          ChallanPdfService.previewProforma(proforma, _company),
                    ),
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
                gradient: converted
                    ? AppColors.successGradient
                    : (cancelled
                          ? const LinearGradient(
                              colors: [AppColors.danger, Color(0xFF8E1D1D)],
                            )
                          : AppColors.navyGradient),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                      converted
                          ? Icons.check_rounded
                          : (cancelled
                                ? Icons.cancel_rounded
                                : Icons.request_quote_rounded),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          converted
                              ? 'Converted to challan'
                              : (cancelled
                                    ? 'Proforma cancelled'
                                    : 'Proforma invoice'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          proforma.number,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          converted && proforma.challanNumber.isNotEmpty
                              ? 'Challan ${proforma.challanNumber}'
                              : 'Not a tax invoice — no stock movement.',
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
            _partyCard(theme, 'Bill To', proforma.billTo, showSite: false),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (var i = 0; i < proforma.lines.length; i++) ...[
                    if (i > 0) const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                proforma.lines[i].itemName,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${proforma.lines[i].quantity} × ${Fmt.price(proforma.lines[i].rate)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Fmt.price(proforma.lines[i].amount),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 22),
                  _totalRow(theme, 'Taxable value', proforma.taxableValue),
                  _totalRow(theme, 'GST', proforma.gstValue),
                  if (proforma.roundOff != 0)
                    _totalRow(theme, 'Round off', proforma.roundOff),
                  const SizedBox(height: 6),
                  _totalRow(
                    theme,
                    'Grand total',
                    proforma.grandTotal,
                    bold: true,
                  ),
                ],
              ),
            ),
            if (converted && proforma.challanNumber.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Converted to challan ${proforma.challanNumber}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChallanPreviewScreen(
                            number: proforma.challanNumber,
                          ),
                        ),
                      ),
                      child: const Text('View'),
                    ),
                  ],
                ),
              ),
            ],
            if (cancelled && proforma.cancelRemarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cancelled by', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      proforma.cancelledByName.isEmpty
                          ? '—'
                          : proforma.cancelledByName,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (proforma.cancelledAt != null)
                      Text(
                        Fmt.dayTime(proforma.cancelledAt!),
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 10),
                    Text('Reason', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      proforma.cancelRemarks,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (!cancelled && !converted && canConvert)
              AppButton(
                label: 'Convert to challan',
                icon: Icons.swap_horiz_rounded,
                loading: _working,
                onTap: () => _convert(proforma),
              ),
            if (!cancelled && !converted && (canEdit || canCancel)) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (canEdit)
                    Expanded(
                      child: AppButton(
                        label: 'Edit',
                        dense: true,
                        height: 48,
                        variant: AppButtonVariant.outline,
                        icon: Icons.edit_rounded,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ChallanFormScreen(proforma: proforma),
                          ),
                        ),
                      ),
                    ),
                  if (canEdit && canCancel) const SizedBox(width: 10),
                  if (canCancel)
                    Expanded(
                      child: AppButton(
                        label: 'Cancel proforma',
                        dense: true,
                        height: 48,
                        variant: AppButtonVariant.danger,
                        icon: Icons.cancel_rounded,
                        onTap: () => _cancel(proforma),
                      ),
                    ),
                ],
              ),
            ],
            if (!cancelled) ...[
              const SizedBox(height: 10),
              AppButton(
                label: 'Share PDF',
                icon: Icons.share_rounded,
                variant: AppButtonVariant.outline,
                loading: _working,
                onTap: () => _run(
                  () => ChallanPdfService.shareProforma(proforma, _company),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _totalRow(
    ThemeData theme,
    String label,
    double value, {
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                (bold ? theme.textTheme.titleSmall : theme.textTheme.bodySmall)
                    ?.copyWith(color: bold ? null : AppColors.textSecondary),
          ),
        ),
        Text(
          Fmt.price(value),
          style: (bold ? theme.textTheme.titleSmall : theme.textTheme.bodySmall)
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

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
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            party.name.isEmpty ? '—' : party.name,
            style: theme.textTheme.titleSmall,
          ),
          if (showSite && party.siteProject.isNotEmpty)
            Text(party.siteProject, style: theme.textTheme.bodySmall),
          if (party.address.isNotEmpty)
            Text(party.address, style: theme.textTheme.bodySmall),
          if (party.phone.isNotEmpty)
            Text(party.phone, style: theme.textTheme.bodySmall),
          if (party.gstin.isNotEmpty)
            Text('GSTIN: ${party.gstin}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
