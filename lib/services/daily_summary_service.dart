import '../data/repositories/notification_repository.dart';
import '../models/app_notification.dart';
import '../models/challan.dart';
import '../models/stock_item.dart';
import '../models/stock_transaction.dart';
import 'notification_service.dart';

/// Builds and delivers the once-a-day stock summary.
class DailySummaryService {
  const DailySummaryService._();

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Summary of the previous day's movement.
  static ({String title, String body}) build({
    required List<StockTransaction> transactions,
    required List<Challan> challans,
    required List<StockItem> items,
    DateTime? forDay,
  }) {
    final now = DateTime.now();
    final day = forDay ?? now.subtract(const Duration(days: 1));
    bool sameDay(DateTime d) =>
        d.year == day.year && d.month == day.month && d.day == day.day;

    var inUnits = 0;
    var outUnits = 0;
    for (final t in transactions) {
      if (!sameDay(t.date)) continue;
      final s = t.signedQuantity;
      if (s >= 0) {
        inUnits += s;
      } else {
        outUnits += -s;
      }
    }

    final issued = challans.where((c) => sameDay(c.date)).length;
    final low = items.where((i) => i.needsAttention).length;

    final body =
        'Yesterday: +$inUnits in, −$outUnits out • '
        '$issued challan${issued == 1 ? '' : 's'} issued • '
        '$low low-stock item${low == 1 ? '' : 's'}';

    return (title: 'Daily stock summary', body: body);
  }

  /// Writes the summary to the notification centre and (optionally) the phone.
  static Future<void> send({
    required String uid,
    required String title,
    required String body,
    required bool notify,
    bool markDate = true,
  }) async {
    final repo = const NotificationRepository();
    final now = DateTime.now();
    // Reserve the date first, so a later failure cannot cause a re-send loop.
    if (markDate) {
      await repo.setLastSummaryDate(uid, dateKey(now));
    }
    await repo.add(
      AppNotification(
        id: '',
        type: AppNotificationType.summary,
        title: title,
        body: body,
        createdAt: now,
      ),
    );
    if (notify) {
      await NotificationService.showSummary(title, body);
    }
  }
}
