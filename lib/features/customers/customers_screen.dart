import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/toast.dart';
import '../../data/repositories/customer_repository.dart';
import '../../models/customer.dart';
import '../../providers/customer_providers.dart';

/// Saved customers (Bill-To details). Ship-To is entered per challan.
class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  Future<void> _addOrEdit(
    BuildContext context,
    WidgetRef ref, {
    Customer? existing,
  }) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final gstin = TextEditingController(text: existing?.gstin ?? '');
    final address = TextEditingController(text: existing?.billToAddress ?? '');
    final contact = TextEditingController(text: existing?.contactPerson ?? '');

    final saved = await AppSheet.show<bool>(
      context,
      title: existing == null ? 'Add customer' : 'Edit customer',
      subtitle: 'Bill-To details reused on challans',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: name,
            label: 'Customer name',
            hint: 'e.g. Greenfield Estates',
            prefixIcon: Icons.business_rounded,
            required: true,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: phone,
            label: 'Contact number',
            hint: '+91 …',
            prefixIcon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            required: true,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: gstin,
            label: 'GSTIN',
            hint: '08AAAAA0000A1Z5',
            prefixIcon: Icons.receipt_long_rounded,
            required: true,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: address,
            label: 'Bill To address',
            hint: 'Street, area, city, pincode',
            prefixIcon: Icons.map_rounded,
            maxLines: 2,
            required: true,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: contact,
            label: 'Contact person',
            hint: 'Name',
            prefixIcon: Icons.badge_rounded,
            required: true,
          ),
          const SizedBox(height: 18),
          AppButton(
            label: existing == null ? 'Add customer' : 'Save changes',
            icon: existing == null ? Icons.add_rounded : Icons.check_rounded,
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) return;
    final cleanName = name.text.trim();
    if (cleanName.isEmpty ||
        phone.text.trim().isEmpty ||
        address.text.trim().isEmpty) {
      AppToast.error(context, 'Name, phone and address are required');
      return;
    }
    final repo = const CustomerRepository();

    if (existing == null) {
      final id = await repo.create(
        Customer(
          id: '',
          name: cleanName,
          phone: phone.text.trim(),
          gstin: gstin.text.trim(),
          billToAddress: address.text.trim(),
          contactPerson: contact.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      if (!context.mounted) return;
      if (id == null) {
        AppToast.error(context, 'A customer with that name already exists');
      } else {
        AppToast.success(context, '$cleanName added');
      }
    } else {
      final res = await repo.update(
        existing.copyWith(
          name: cleanName,
          phone: phone.text.trim(),
          gstin: gstin.text.trim(),
          billToAddress: address.text.trim(),
          contactPerson: contact.text.trim(),
        ),
      );
      if (!context.mounted) return;
      if (res.ok) {
        AppToast.success(context, res.message);
      } else {
        AppToast.error(context, res.message);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete customer?'),
        content: Text(
          'Remove "${customer.name}"? Existing challans keep their saved '
          'Bill-To details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await const CustomerRepository()
        .delete(customer.id, customer.name);
    if (!context.mounted) return;
    if (res.ok) {
      AppToast.success(context, res.message);
    } else {
      AppToast.error(context, res.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customers = ref.watch(customersProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Customers')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Saved customer Bill-To details. Ship-To is always entered on '
              'the challan.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (customers.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No customers yet',
                  message: 'Add a customer to reuse their Bill-To details.',
                  actionLabel: 'Add customer',
                  onAction: () => _addOrEdit(context, ref),
                ),
              )
            else
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < customers.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: AppColors.primaryDeep, size: 20),
                        ),
                        title: Text(customers[i].name),
                        subtitle: Text(
                          '${customers[i].phone}'
                          '${customers[i].gstin.isNotEmpty ? ' • ${customers[i].gstin}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () =>
                              _delete(context, ref, customers[i]),
                        ),
                        onTap: () =>
                            _addOrEdit(context, ref, existing: customers[i]),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Add customer',
              icon: Icons.add_rounded,
              onTap: () => _addOrEdit(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
