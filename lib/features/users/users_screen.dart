import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/toast.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/app_user.dart';
import '../../providers/auth_providers.dart';

/// Admin: manage each user's role and per-user permissions.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  static String _roleLabel(String role) => switch (role) {
    'admin' => 'Admin',
    'store_keeper' => 'Store Keeper',
    'epc_manager' => 'EPC Manager',
    'accounts' => 'Accounts',
    _ => role,
  };

  Future<void> _edit(BuildContext context, WidgetRef ref, AppUser user) async {
    var role = user.role;
    var active = user.active;
    final perms = Map<String, bool>.from(user.permissions);

    final saved = await AppSheet.show<bool>(
      context,
      title: user.displayName,
      subtitle: user.username.isNotEmpty ? '@${user.username}' : user.email,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in kRoleDefs)
                  ChoiceChip(
                    label: Text(_roleLabel(r)),
                    selected: role == r,
                    onSelected: (_) => setSheet(() => role = r),
                    selectedColor: AppColors.primarySoft,
                    labelStyle: TextStyle(
                      color: role == r
                          ? AppColors.primaryDeep
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    side: BorderSide(
                      color: role == r ? AppColors.primary : AppColors.border,
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: active,
              onChanged: (v) => setSheet(() => active = v),
              title: const Text('Active'),
            ),
            if (role == 'admin') ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 18,
                      color: AppColors.primaryDeep,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Administrators automatically have every permission — '
                        'no permissions to set.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Divider(),
              Text(
                'Permissions',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              for (final (key, label) in kPermissionDefs)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: perms[key] ?? false,
                  onChanged: (v) => setSheet(() => perms[key] = v),
                  title: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
            const SizedBox(height: 14),
            AppButton(
              label: 'Save permissions',
              icon: Icons.check_rounded,
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    if (!context.mounted) return;

    // Save only what actually changed (field paths), so a screen that was left
    // open while the data changed elsewhere can never overwrite other values.
    final fields = <String, dynamic>{};
    if (role != user.role) fields['role'] = role;
    if (active != user.active) fields['active'] = active;
    for (final (key, _) in kPermissionDefs) {
      final now = perms[key] ?? false;
      final was = user.permissions[key] ?? false;
      if (now != was) fields['permissions.$key'] = now;
    }

    if (fields.isEmpty) {
      AppToast.info(context, 'No changes to save');
      return;
    }

    final res = await const UserRepository().updateFields(user.uid, fields);
    if (!context.mounted) return;
    if (res.ok) {
      AppToast.success(context, 'Permissions updated');
      ref.invalidate(allUsersProvider);
    } else {
      AppToast.error(context, res.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(allUsersProvider).valueOrNull ?? const <AppUser>[];
    final admins = all.where((u) => u.isAdmin).toList();
    final others = all.where((u) => !u.isAdmin).toList();

    Widget avatar(IconData icon) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primaryDeep, size: 20),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Users & permissions'),
        actions: [
          IconButton(
            tooltip: 'Refresh from server',
            onPressed: () {
              ref.invalidate(allUsersProvider);
              AppToast.info(context, 'Refreshing…');
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allUsersProvider);
            await Future<void>.delayed(const Duration(milliseconds: 600));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                'Set each user’s role and permissions. Administrators always have '
                'full access and cannot be restricted.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (all.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No users yet',
                    message: 'Users appear here after their first sign-in.',
                  ),
                )
              else ...[
                if (admins.isNotEmpty) ...[
                  const SectionHeader(title: 'Administrators'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < admins.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: avatar(Icons.shield_rounded),
                            title: Text(admins[i].displayName),
                            subtitle: Text(
                              '${admins[i].username.isNotEmpty ? '@${admins[i].username} • ' : ''}'
                              'Full access'
                              '${admins[i].active ? '' : ' • inactive'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const SectionHeader(title: 'Users'),
                if (others.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.person_add_alt_rounded,
                      title: 'No staff accounts',
                      message:
                          'Staff accounts appear here after their first sign-in.',
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < others.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: avatar(Icons.person_rounded),
                            title: Text(others[i].displayName),
                            subtitle: Text(
                              '${others[i].username.isNotEmpty ? '@${others[i].username} • ' : ''}'
                              '${others[i].roleLabel}'
                              '${others[i].active ? '' : ' • inactive'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textMuted,
                            ),
                            onTap: () => _edit(context, ref, others[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
