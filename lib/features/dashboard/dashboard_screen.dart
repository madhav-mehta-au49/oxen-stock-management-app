import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/toast.dart';
import '../../models/stock_item.dart';
import '../../models/stock_transaction.dart';
import '../../providers/stock_providers.dart';
import '../../providers/notification_providers.dart';
import '../challan/challan_form_screen.dart';
import '../notifications/notifications_sheet.dart';
import '../stock/item_detail_screen.dart';
import '../stock/movement_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  /// Jump to a tab of the parent shell (0 = dashboard, 1 = stock, 2 = challan).
  final ValueChanged<int> onNavigate;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _syncing = false);
    AppToast.success(context, 'Dashboard is up to date');
  }

  void _open(WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = ref.watch(itemsProvider);
    final lowStock = ref.watch(lowStockItemsProvider);
    final value = ref.watch(totalStockValueProvider);
    final today = ref.watch(todayMovementProvider);
    final unread = ref.watch(unreadNotificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            _Header(syncing: _syncing, onSync: _sync, unread: unread),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroValue(value: value, itemCount: items.length),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.inventory_2_rounded,
                          color: AppColors.info,
                          label: 'Total items',
                          value: '${items.length}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.warning_amber_rounded,
                          color: lowStock.isEmpty
                              ? AppColors.success
                              : AppColors.danger,
                          label: 'Low stock',
                          value: '${lowStock.length}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.swap_horiz_rounded,
                          color: AppColors.primaryDeep,
                          label: 'Today in/out',
                          value: '${today.inCount}/${today.outCount}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Quick actions', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Stock In',
                          color: AppColors.success,
                          bg: AppColors.successSoft,
                          onTap: () => _open(
                            (_) => const MovementScreen(isIn: true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.remove_circle_outline_rounded,
                          label: 'Stock Out',
                          color: AppColors.danger,
                          bg: AppColors.dangerSoft,
                          onTap: () => _open(
                            (_) => const MovementScreen(isIn: false),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.receipt_long_rounded,
                          label: 'New Challan',
                          color: AppColors.primaryDeep,
                          bg: AppColors.primarySoft,
                          onTap: () => _open(
                            (_) => const ChallanFormScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (lowStock.isNotEmpty) ...[
                    _LowStockBanner(
                      items: lowStock,
                      onViewAll: () => widget.onNavigate(1),
                    ),
                    const SizedBox(height: 22),
                  ],
                  const _MovementChartCard(),
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: 'Recent activity',
                    actionLabel: 'Full ledger',
                    onAction: () => widget.onNavigate(1),
                  ),
                  _ActivityCard(
                    transactions: ref.watch(recentActivityProvider(7)),
                    onOpenItem: (t) => _open(
                      (_) => ItemDetailScreen(itemId: t.itemId),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ header

class _Header extends StatelessWidget {
  const _Header({
    required this.syncing,
    required this.onSync,
    required this.unread,
  });

  final bool syncing;
  final VoidCallback onSync;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.navyGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(onDark: true, scale: 0.92),
              const Spacer(),
              _RoundButton(
                icon: Icons.sync_rounded,
                tooltip: 'Refresh dashboard',
                spinning: syncing,
                onTap: onSync,
              ),
              const SizedBox(width: 10),
              _NotifyButton(
                unread: unread,
                onTap: () => showNotificationsSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            '$greeting, Store Team',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                Fmt.date(now),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.spinning = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: spinning
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentBright,
                ),
              )
            : Icon(icon, size: 21, color: Colors.white),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _NotifyButton extends StatelessWidget {
  const _NotifyButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notifications',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 21,
                color: Colors.white,
              ),
              if (unread > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 17),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
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

// ------------------------------------------------------------------- cards

class _HeroValue extends StatelessWidget {
  const _HeroValue({required this.value, required this.itemCount});

  final double value;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330A2A66),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL STOCK VALUE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Fmt.price(value),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const StatusPill(
                      label: 'LIVE',
                      color: Colors.white,
                      bg: Color(0x33FFFFFF),
                      icon: Icons.circle,
                      dense: true,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'across $itemCount SKUs',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({required this.items, required this.onViewAll});

  final List<StockItem> items;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outOfStock = items.where((i) => i.isOutOfStock).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${items.length} item${items.length == 1 ? '' : 's'} need restocking',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    if (outOfStock > 0)
                      Text(
                        '$outOfStock out of stock right now',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.danger.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.quantity}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- chart

class _MovementChartCard extends ConsumerStatefulWidget {
  const _MovementChartCard();

  @override
  ConsumerState<_MovementChartCard> createState() =>
      _MovementChartCardState();
}

class _MovementChartCardState extends ConsumerState<_MovementChartCard> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = ref.watch(stockTrendProvider(_days));
    final maxIn = data.fold<int>(0, (m, d) => d.inQty > m ? d.inQty : m);
    final maxOut = data.fold<int>(0, (m, d) => d.outQty > m ? d.outQty : m);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stock movement',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _RangeChip(
                      label: '7D',
                      selected: _days == 7,
                      onTap: () => setState(() => _days = 7),
                    ),
                    _RangeChip(
                      label: '30D',
                      selected: _days == 30,
                      onTap: () => setState(() => _days = 30),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: const [
              _Legend(color: AppColors.success, label: 'Stock in'),
              SizedBox(width: 16),
              _Legend(color: AppColors.primaryDeep, label: 'Stock out'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 184,
            child: _days == 7
                ? _BarChart(
                    data: data,
                    maxY: (maxIn > maxOut ? maxIn : maxOut).toDouble(),
                  )
                : _LineChart(data: data),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

FlGridData _grid() => FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (v) => FlLine(
        color: AppColors.divider,
        strokeWidth: 1,
        dashArray: [4, 4],
      ),
    );

AxisTitles _noTitles() =>
    const AxisTitles(sideTitles: SideTitles(showTitles: false));

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data, required this.maxY});

  final List<DayMovement> data;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 10 : maxY * 1.3,
        minY: 0,
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: data[i].inQty.toDouble(),
                  color: AppColors.success,
                  width: 7,
                  borderRadius: BorderRadius.circular(4),
                ),
                BarChartRodData(
                  toY: data[i].outQty.toDouble(),
                  color: AppColors.primaryDeep,
                  width: 7,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        gridData: _grid(),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? 'In' : 'Out';
              return BarTooltipItem(
                '$label  ${rod.toY.round()}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: _noTitles(),
          rightTitles: _noTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _niceInterval(maxY),
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    Fmt.shortDate(data[i].day),
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      duration: const Duration(milliseconds: 350),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.data});

  final List<DayMovement> data;

  LineChartBarData _bar(List<double> values, Color color) => LineChartBarData(
        isCurved: true,
        preventCurveOverShooting: true,
        barWidth: 2.6,
        color: color,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.10),
        ),
        spots: [
          for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<int>(
      0,
      (m, d) => (d.inQty > d.outQty ? d.inQty : d.outQty) > m
          ? (d.inQty > d.outQty ? d.inQty : d.outQty)
          : m,
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxVal <= 0 ? 10 : maxVal * 1.3,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => [
              for (final s in touchedSpots)
                LineTooltipItem(
                  '${s.barIndex == 0 ? 'In' : 'Out'}  ${s.y.round()}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        gridData: _grid(),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          _bar(
            [for (final d in data) d.inQty.toDouble()],
            AppColors.success,
          ),
          _bar(
            [for (final d in data) d.outQty.toDouble()],
            AppColors.primaryDeep,
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: _noTitles(),
          rightTitles: _noTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _niceInterval(maxVal.toDouble()),
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 5,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length || i % 5 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    Fmt.shortDate(data[i].day),
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      duration: const Duration(milliseconds: 350),
    );
  }
}

double _niceInterval(double maxValue) {
  if (maxValue <= 20) return 5;
  if (maxValue <= 60) return 10;
  if (maxValue <= 200) return 40;
  if (maxValue <= 500) return 100;
  return 200;
}

// --------------------------------------------------------------- activity

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.transactions,
    required this.onOpenItem,
  });

  final List<StockTransaction> transactions;
  final ValueChanged<StockTransaction> onOpenItem;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.history_rounded,
          title: 'No activity yet',
          message: 'Stock movements will appear here.',
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            if (i > 0) const Divider(indent: 62),
            _ActivityTile(
              txn: transactions[i],
              onTap: () => onOpenItem(transactions[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.txn, required this.onTap});

  final StockTransaction txn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = txn.isIn;
    final color = isIn ? AppColors.success : AppColors.danger;
    final bg = isIn ? AppColors.successSoft : AppColors.dangerSoft;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${txn.reference} • ${Fmt.relativeDay(txn.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  txn.signedLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'bal ${txn.balanceAfter}',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
