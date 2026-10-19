import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/result.dart';
import '../data/repositories/audit_repository.dart';
import '../data/repositories/challan_repository.dart';
import '../data/repositories/item_image_repository.dart';
import '../data/repositories/item_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../models/app_notification.dart';
import '../models/audit_entry.dart';
import '../models/category.dart';
import '../models/challan.dart';
import '../models/stock_item.dart';
import '../models/stock_transaction.dart';
import '../services/auth_service.dart';
import 'auth_providers.dart';

const _items = ItemRepository();
const _txns = TransactionRepository();
const _challans = ChallanRepository();

/// Live Firestore streams.
final itemsStreamProvider = StreamProvider<List<StockItem>>((ref) {
  return _items.watchItems().handleError((Object e, StackTrace st) {
    // ignore: avoid_print
    print('FIRESTORE itemsStream ERROR: $e');
  });
});

final transactionsStreamProvider = StreamProvider<List<StockTransaction>>((
  ref,
) {
  return _txns.watchAll().handleError((Object e, StackTrace st) {
    // ignore: avoid_print
    print('FIRESTORE txnsStream ERROR: $e');
  });
});

final challansStreamProvider = StreamProvider<List<Challan>>((ref) {
  return _challans.watchAll().handleError((Object e, StackTrace st) {
    // ignore: avoid_print
    print('FIRESTORE challansStream ERROR: $e');
  });
});

/// Single source of truth for stock data, composed from the live streams.
class StockState {
  const StockState({
    required this.items,
    required this.transactions,
    required this.challans,
  });

  final List<StockItem> items;
  final List<StockTransaction> transactions;
  final List<Challan> challans;

  StockItem? itemById(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }
}

class StockNotifier extends Notifier<StockState> {
  @override
  StockState build() {
    final items = ref.watch(itemsStreamProvider).value ?? const <StockItem>[];
    final txns =
        ref.watch(transactionsStreamProvider).value ??
        const <StockTransaction>[];
    final challans =
        ref.watch(challansStreamProvider).value ?? const <Challan>[];
    return StockState(items: items, transactions: txns, challans: challans);
  }

  String get _byUser => AuthService.currentUser?.email ?? 'Unknown user';

  /// Friendly name shown in the audit trail ("Store Keeper", "Kedar", …).
  String get _byName {
    final p = ref.read(userProfileProvider).valueOrNull;
    if (p == null) return _byUser;
    return p.displayName.isNotEmpty ? p.displayName : p.username;
  }

  // ---------------------------------------------------------------- items

  Future<({Result result, String id})> upsertItem(StockItem item) async {
    final isNew = item.id.isEmpty;
    final res = await _items.upsert(item, byUser: _byUser, byName: _byName);
    if (res.result.ok) {
      await _notify(
        title: isNew ? 'Item added' : 'Item updated',
        body: '${item.name} • by $_byName',
        refId: res.id,
      );
    }
    return res;
  }

  Future<StockItem?> quickAddItem({
    required String name,
    required String sku,
    required Category category,
    required String unit,
    double purchasePrice = 0,
    double sellingPrice = 0,
    String supplier = '',
    String unitNos = '',
  }) => _items.quickCreate(
    name: name,
    sku: sku,
    category: category,
    unit: unit,
    purchasePrice: purchasePrice,
    sellingPrice: sellingPrice,
    supplier: supplier,
    unitNos: unitNos,
    byUser: _byUser,
    byName: _byName,
  );

  Future<Result> deleteItem(String itemId, {String remarks = ''}) async {
    final name = state.itemById(itemId)?.name ?? 'Item';
    final res = await _items.delete(
      itemId,
      name,
      byUser: _byUser,
      byName: _byName,
      remarks: remarks,
    );
    if (res.ok) {
      await _notify(
        title: 'Item deleted',
        body: '$name • by $_byName${remarks.isEmpty ? '' : ' • $remarks'}',
      );
    }
    return res;
  }

  /// Generic in-app notification (used for categories and other events).
  Future<void> logEvent({
    required String title,
    required String body,
    String refId = '',
  }) => _notify(title: title, body: body, refId: refId);

  Future<void> _notify({
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.info,
    String refId = '',
  }) async {
    try {
      await const NotificationRepository().add(
        AppNotification(
          id: '',
          type: type,
          title: title,
          body: body,
          createdAt: DateTime.now(),
          refId: refId,
        ),
      );
    } catch (_) {
      // Notifications are best-effort; never block the action.
    }
  }

  // ------------------------------------------------------------ movements

  Future<Result> stockIn({
    required String itemId,
    required int quantity,
    required String source,
    required String reference,
    required DateTime date,
    String notes = '',
  }) => _txns.stockIn(
    itemId: itemId,
    quantity: quantity,
    source: source,
    reference: reference,
    date: date,
    notes: notes,
    byUser: _byUser,
  );

  Future<Result> stockOut({
    required String itemId,
    required int quantity,
    required String party,
    required String reference,
    required DateTime date,
    String notes = '',
    bool adminOverride = false,
  }) => _txns.stockOut(
    itemId: itemId,
    quantity: quantity,
    party: party,
    reference: reference,
    date: date,
    notes: notes,
    adminOverride: adminOverride,
    byUser: _byUser,
  );

  // ------------------------------------------------------------ challans

  Future<String> nextChallanNumber() =>
      _challans.peekNextNumber(DateTime.now());

  Future<IssueResult> issueChallan(Challan challan) async {
    final res = await _challans.issue(
      challan,
      byUser: _byUser,
      byName: _byName,
    );
    if (res.result.ok && res.number.isNotEmpty) {
      await _notify(
        type: AppNotificationType.challan,
        title: 'Challan ${res.number} issued',
        body:
            '${challan.billTo.name} • ${challan.totalUnits} units • by $_byName',
        refId: res.number,
      );
    }
    return res;
  }

  Future<Result> setChallanFormat(String number, ChallanFormat format) =>
      _challans.setFormat(number, format);

  Future<Result> editChallan({
    required Challan oldChallan,
    required Challan updated,
  }) => _challans.edit(
    oldChallan: oldChallan,
    updated: updated,
    byUser: _byUser,
    byName: _byName,
  );

  Future<Result> cancelChallan(Challan challan, {String remarks = ''}) async {
    final res = await _challans.cancel(
      challan,
      byUser: _byUser,
      byName: _byName,
      remarks: remarks,
    );
    if (res.ok) {
      await _notify(
        type: AppNotificationType.challan,
        title: 'Challan ${challan.number} cancelled',
        body:
            '${challan.billTo.name} • by $_byName${remarks.isEmpty ? '' : ' • $remarks'}',
        refId: challan.number,
      );
    }
    return res;
  }
}

final stockProvider = NotifierProvider<StockNotifier, StockState>(
  StockNotifier.new,
);

/// Live audit trail (newest first) for the Audit log screen.
final auditLogProvider = StreamProvider<List<AuditEntry>>(
  (ref) => const AuditRepository().watchAll(),
);

/// Full-size product photo for an item (loaded lazily on the detail screen).
final itemImageProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  itemId,
) {
  if (itemId.isEmpty) return Future.value(null);
  return const ItemImageRepository().loadFull(itemId);
});

// ------------------------------------------------------------- derived

/// Every item, including soft-deleted ones (stock list uses this).
final allItemsProvider = Provider<List<StockItem>>(
  (ref) => ref.watch(stockProvider).items,
);

/// Active items only (dashboard totals, low stock, pickers).
final itemsProvider = Provider<List<StockItem>>(
  (ref) => ref.watch(allItemsProvider).where((i) => !i.isDeleted).toList(),
);

final lowStockItemsProvider = Provider<List<StockItem>>(
  (ref) => ref.watch(itemsProvider).where((i) => i.needsAttention).toList(),
);

final totalStockValueProvider = Provider<double>(
  (ref) =>
      ref.watch(itemsProvider).fold<double>(0, (sum, i) => sum + i.stockValue),
);

class DayMovement {
  const DayMovement({
    required this.day,
    required this.inQty,
    required this.outQty,
  });

  final DateTime day;
  final int inQty;
  final int outQty;

  int get net => inQty - outQty;
}

/// Aggregated in/out quantities for the last [days] days, oldest first.
final stockTrendProvider = Provider.family<List<DayMovement>, int>((ref, days) {
  final txns = ref.watch(stockProvider).transactions;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final buckets = List<int>.filled(days, 0);
  final outs = List<int>.filled(days, 0);

  for (final t in txns) {
    final d = DateTime(t.date.year, t.date.month, t.date.day);
    final ago = today.difference(d).inDays;
    if (ago < 0 || ago >= days) continue;
    final idx = days - 1 - ago;
    final signed = t.signedQuantity;
    if (signed >= 0) {
      buckets[idx] += signed;
    } else {
      outs[idx] += -signed;
    }
  }

  return [
    for (var i = 0; i < days; i++)
      DayMovement(
        day: today.subtract(Duration(days: days - 1 - i)),
        inQty: buckets[i],
        outQty: outs[i],
      ),
  ];
});

class TodayMovement {
  const TodayMovement({required this.inCount, required this.outCount});

  final int inCount;
  final int outCount;

  int get total => inCount + outCount;
}

final todayMovementProvider = Provider<TodayMovement>((ref) {
  final txns = ref.watch(stockProvider).transactions;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  var inCount = 0;
  var outCount = 0;
  for (final t in txns) {
    final d = DateTime(t.date.year, t.date.month, t.date.day);
    if (d != today) continue;
    if (t.isIn) {
      inCount++;
    } else {
      outCount++;
    }
  }
  return TodayMovement(inCount: inCount, outCount: outCount);
});

final recentActivityProvider = Provider.family<List<StockTransaction>, int>(
  (ref, limit) => ref.watch(stockProvider).transactions.take(limit).toList(),
);

final itemLedgerProvider = Provider.family<List<StockTransaction>, String>((
  ref,
  itemId,
) {
  final all = ref.watch(stockProvider).transactions;
  final list = all.where((t) => t.itemId == itemId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return list;
});

/// Category label -> total stock value, used by the dashboard breakdown.
final categoryValueProvider = Provider<List<MapEntry<String, double>>>((ref) {
  final items = ref.watch(itemsProvider);
  final map = <String, double>{};
  for (final i in items) {
    map.update(
      i.categoryName,
      (v) => v + i.stockValue,
      ifAbsent: () => i.stockValue,
    );
  }
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
});
