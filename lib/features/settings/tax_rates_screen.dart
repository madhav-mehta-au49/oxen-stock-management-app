import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/toast.dart';
import '../../models/stock_item.dart';
import '../../providers/tax_providers.dart';

/// Global per-category GST rates (single GST %, shown only on delivery notes).
class TaxRatesScreen extends ConsumerStatefulWidget {
  const TaxRatesScreen({super.key});

  @override
  ConsumerState<TaxRatesScreen> createState() => _TaxRatesScreenState();
}

class _TaxRatesScreenState extends ConsumerState<TaxRatesScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void _ensureControllers(Map<String, double> rates) {
    if (_loaded) return;
    for (final c in ItemCategory.values) {
      _controllers[c.label] = TextEditingController(text: _fmt(rates[c.label] ?? 0));
    }
    _loaded = true;
  }

  Future<void> _save() async {
    if (_saving) return;
    final rates = <String, double>{
      for (final c in ItemCategory.values)
        c.label: double.tryParse(_controllers[c.label]!.text.trim()) ?? 0,
    };
    setState(() => _saving = true);
    final ok = await ref.read(taxControllerProvider).save(rates);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      AppToast.success(context, 'GST rates saved');
      Navigator.of(context).pop();
    } else {
      AppToast.error(context, 'Could not save GST rates');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rates = ref.watch(taxRatesProvider).value ?? const <String, double>{};
    _ensureControllers(rates);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('GST rates')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Set a single GST % for each category. Prices are entered without '
              'GST; GST is applied and shown only on the delivery note.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < ItemCategory.values.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(ItemCategory.values[i].icon,
                              size: 20, color: AppColors.primaryDeep),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ItemCategory.values[i].label,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          SizedBox(
                            width: 84,
                            child: TextField(
                              controller:
                                  _controllers[ItemCategory.values[i].label],
                              textAlign: TextAlign.right,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              decoration: const InputDecoration(
                                suffixText: '%',
                                isDense: true,
                                hintText: '0',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Save GST rates',
              icon: Icons.save_rounded,
              loading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
