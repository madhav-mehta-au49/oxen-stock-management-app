import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/toast.dart';
import '../../models/app_settings.dart';
import '../../models/challan.dart';
import '../../models/company_profile.dart';
import '../../providers/app_info_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/stock_providers.dart';
import '../../services/auth_service.dart';
import '../../services/daily_summary_service.dart';

/// Preferences + account info. Toggles and the company profile persist in
/// Firestore (`settings/{uid}`, `meta/company`).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _logout() => AuthService.signOut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final email = ref.watch(authStateProvider).value?.email ?? 'Signed in';
    final profile = ref.watch(userProfileProvider).value;
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final company =
        ref.watch(companyProfileProvider).value ?? CompanyProfile.fallback;
    final isAdmin = profile?.isAdmin ?? false;
    final controller = ref.read(settingsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Settings', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Workspace preferences and account',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_roleLabel(profile?.role)} • Oxen Energies',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Alerts'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _toggle(
                    context,
                    'Low stock alerts',
                    'Notify and play a sound when an item reaches its reorder level',
                    Icons.notifications_active_rounded,
                    settings.lowStockAlerts,
                    controller.toggleLowStock,
                  ),
                  const Divider(height: 1),
                  _toggle(
                    context,
                    'Daily stock summary',
                    'One notification each morning summarising the previous day’s stock movement',
                    Icons.summarize_rounded,
                    settings.dailySummary,
                    controller.toggleDailySummary,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded,
                        color: AppColors.primaryDeep),
                    title: Text('Daily summary time',
                        style: theme.textTheme.titleSmall),
                    subtitle: Text(
                      'Delivered on the first app open after this time',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Text(
                      settings.summaryTime,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: AppColors.primaryDeep),
                    ),
                    onTap: () => _pickSummaryTime(context, ref, settings),
                  ),
                  const Divider(height: 1),
                  _toggle(
                    context,
                    'Auto-refresh dashboard',
                    'Refresh the summary cards every time the app opens',
                    Icons.sync_rounded,
                    settings.autoRefresh,
                    controller.toggleAutoRefresh,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Company profile',
              actionLabel: isAdmin ? 'Edit' : null,
              onAction: isAdmin
                  ? () => _editCompany(context, ref, company)
                  : null,
            ),
            AppCard(
              child: Column(
                children: [
                  _companyRow(context, Icons.business_rounded, 'Business name',
                      company.name),
                  _companyRow(
                      context, Icons.receipt_long_rounded, 'GSTIN', company.gstin),
                  _companyRow(
                      context, Icons.phone_rounded, 'Phone', company.phone),
                  _companyRow(context, Icons.location_on_rounded, 'Address',
                      company.address, last: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'App'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_rounded),
                    title: const Text('Default challan format'),
                    subtitle: Text(
                      '${settings.defaultChallanFormat.label} • used for new challans',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => _pickFormat(context, ref, settings),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.send_rounded),
                    title: const Text('Preview daily summary'),
                    subtitle:
                        const Text('Send it to the notification centre now'),
                    onTap: () => _previewSummary(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('About Oxen Energies'),
                    subtitle: Text(
                      'Stock Manager • v${ref.watch(appVersionProvider).value ?? '—'}',
                    ),
                    onTap: () => AppToast.info(
                      context,
                      'Oxen Energies Stock Manager '
                      'v${ref.read(appVersionProvider).value ?? ''}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Sign out',
              variant: AppButtonVariant.danger,
              icon: Icons.logout_rounded,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(String? role) => switch (role) {
        'admin' => 'Administrator',
        'viewer' => 'View only',
        _ => 'Store staff',
      };

  Widget _toggle(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Future<void> Function(bool) onChanged,
  ) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: (v) => onChanged(v),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      secondary: Icon(icon, color: AppColors.primaryDeep),
    );
  }

  Widget _companyRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool last = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.primaryDeep),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelSmall),
                    const SizedBox(height: 3),
                    Text(value, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }

  Future<void> _pickFormat(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final picked = await AppSheet.show<ChallanFormat>(
      context,
      title: 'Default challan format',
      subtitle: 'Used for every new delivery challan',
      builder: (context) => Column(
        children: [
          for (final f in ChallanFormat.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SheetOptionTile(
                title: f.label,
                subtitle: f.description,
                selected: settings.defaultChallanFormat == f,
                onTap: () => Navigator.of(context).pop(f),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await ref.read(settingsControllerProvider).setDefaultFormat(picked);
    if (!context.mounted) return;
    AppToast.success(context, 'Default format: ${picked.label}');
  }

  Future<void> _pickSummaryTime(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final (hour, minute) = settings.summaryTimeParts;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked == null) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    await ref
        .read(settingsControllerProvider)
        .update(settings.copyWith(summaryTime: value));
    if (!context.mounted) return;
    AppToast.success(context, 'Daily summary time: $value');
  }

  Future<void> _previewSummary(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final state = ref.read(stockProvider);
    final summary = DailySummaryService.build(
      transactions: state.transactions,
      challans: state.challans,
      items: state.items,
    );
    await DailySummaryService.send(
      uid: uid,
      title: summary.title,
      body: summary.body,
      notify: true,
      markDate: false,
    );
    if (!context.mounted) return;
    AppToast.success(context, 'Daily summary sent');
  }

  Future<void> _editCompany(
    BuildContext context,
    WidgetRef ref,
    CompanyProfile current,
  ) async {
    final name = TextEditingController(text: current.name);
    final tagline = TextEditingController(text: current.tagline);
    final address = TextEditingController(text: current.address);
    final phone = TextEditingController(text: current.phone);
    final gstin = TextEditingController(text: current.gstin);

    final saved = await AppSheet.show<bool>(
      context,
      title: 'Edit company profile',
      subtitle: 'Shown on the challan letter pad and app',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(controller: name, label: 'Business name', required: true),
          const SizedBox(height: 14),
          AppTextField(controller: tagline, label: 'Tagline'),
          const SizedBox(height: 14),
          AppTextField(controller: address, label: 'Address', maxLines: 2),
          const SizedBox(height: 14),
          AppTextField(
            controller: phone,
            label: 'Phone',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          AppTextField(controller: gstin, label: 'GSTIN'),
          const SizedBox(height: 18),
          AppButton(
            label: 'Save company profile',
            icon: Icons.save_rounded,
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
        ],
      ),
    );

    if (saved != true) return;
    await ref.read(companySaveProvider)(
      CompanyProfile(
        name: name.text.trim().isEmpty ? current.name : name.text.trim(),
        tagline: tagline.text.trim(),
        address: address.text.trim(),
        phone: phone.text.trim(),
        gstin: gstin.text.trim(),
      ),
    );
    if (!context.mounted) return;
    AppToast.success(context, 'Company profile saved');
  }
}
