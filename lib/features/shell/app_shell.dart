import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/notification_repository.dart';
import '../../models/app_notification.dart';
import '../../models/stock_item.dart';
import '../../providers/auth_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/stock_providers.dart';
import '../../services/daily_summary_service.dart';
import '../../services/github_update_service.dart';
import '../../services/notification_service.dart';
import '../challan/challan_list_screen.dart';
import '../customers/customers_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../settings/settings_screen.dart';
import '../stock/stock_list_screen.dart';
import '../updates/update_dialog.dart';

/// Root shell hosting the four primary tabs.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  /// Item ids already alerted while low (reset once they recover).
  final Set<String> _alerted = {};

  /// Whether the initial (baseline) low-stock state has been recorded.
  bool _lowStockInitialised = false;

  bool _summaryRan = false;
  bool _updateCheckStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.requestPermission();
      // Non-blocking: check for an app update a few seconds after login.
      unawaited(_checkForUpdate());
    });
  }

  /// Checks GitHub Releases once per session. Never blocks or breaks the app.
  Future<void> _checkForUpdate() async {
    if (_updateCheckStarted) return;
    _updateCheckStarted = true;
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    try {
      final info = await const GitHubUpdateService().checkForUpdate();
      if (info == null || !mounted) return;
      await showUpdateAvailableDialog(context, info);
    } catch (_) {
      // Ignore — updates must never interfere with normal use.
    }
  }

  void goTo(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  /// Raises a sound notification when an item newly crosses its reorder level.
  void _handleLowStock(List<StockItem>? previous, List<StockItem> next) {
    unawaited(_maybeDailySummary());

    final current = <String>{
      for (final i in next)
        if (i.needsAttention) i.id,
    };
    _alerted.removeWhere((id) => !current.contains(id));

    // Record the baseline once the items stream has emitted, WITHOUT notifying —
    // otherwise every app open would re-alert items that are already low.
    if (!_lowStockInitialised) {
      if (!ref.read(itemsStreamProvider).hasValue) return; // wait for first load
      _lowStockInitialised = true;
      _alerted.addAll(current);
      return;
    }

    final settings = ref.read(appSettingsProvider).value;
    if (settings == null || !settings.lowStockAlerts) return;

    for (final item in next) {
      if (!item.needsAttention || _alerted.contains(item.id)) continue;
      _alerted.add(item.id);
      NotificationService.showLowStock(item);
      unawaited(
        const NotificationRepository().add(
          AppNotification(
            id: '',
            type: AppNotificationType.lowStock,
            title: 'Low stock: ${item.name}',
            body: item.isOutOfStock
                ? 'Out of stock.'
                : '${item.quantity} ${item.unit} left '
                    '(reorder level ${item.reorderLevel}).',
            createdAt: DateTime.now(),
            refId: item.id,
          ),
        ),
      );
    }
  }

  /// Delivers the daily summary once per day, on the first open after the
  /// configured time (default 08:00). No server required.
  Future<void> _maybeDailySummary() async {
    if (_summaryRan) return;
    final settings = ref.read(appSettingsProvider).value;
    if (settings == null) return; // wait until preferences load
    if (!ref.read(transactionsStreamProvider).hasValue) return;
    _summaryRan = true;
    if (!settings.dailySummary) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final (hour, minute) = settings.summaryTimeParts;
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = today.add(Duration(hours: hour, minutes: minute));
    if (now.isBefore(scheduled)) return;

    final repo = const NotificationRepository();
    // Database guard: never deliver more than one summary per day, even if the
    // local timestamp was lost or the setting was re-saved.
    if (await repo.hasSummaryOn(today)) return;
    if (await repo.lastSummaryDate(uid) == DailySummaryService.dateKey(today)) {
      return;
    }

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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensures the user profile + company profile exist after sign-in.
    ref.watch(appBootstrapProvider);
    ref.listen<List<StockItem>>(itemsProvider, _handleLowStock);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onNavigate: goTo),
          const StockListScreen(),
          const ChallanListScreen(),
          const CustomersScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        onChanged: goTo,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.dashboard_rounded, 'Dashboard'),
    (Icons.inventory_2_rounded, 'Stock'),
    (Icons.receipt_long_rounded, 'Challan'),
    (Icons.people_rounded, 'Customers'),
    (Icons.settings_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x141A2332),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: i == index
                                ? AppColors.primarySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _items[i].$1,
                            size: 21,
                            color: i == index
                                ? AppColors.primaryDeep
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _items[i].$2,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: i == index
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight:
                                i == index ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
