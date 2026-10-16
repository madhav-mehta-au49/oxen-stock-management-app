import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/result.dart';
import '../../models/stock_item.dart';
import '../../models/stock_transaction.dart';
import 'db.dart';

/// Firestore access for the append-only `transactions` ledger.
class TransactionRepository {
  const TransactionRepository();

  Stream<List<StockTransaction>> watchAll() => Db.transactions
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => StockTransaction.fromMap(d.id, d.data()))
          .toList());

  Future<Result> stockIn({
    required String itemId,
    required int quantity,
    required String source,
    required String reference,
    required DateTime date,
    String notes = '',
    required String byUser,
  }) async {
    return _movement(
      itemId: itemId,
      quantity: quantity,
      isIn: true,
      party: source,
      reference: reference,
      date: date,
      notes: notes.isEmpty ? 'Stock received' : notes,
      byUser: byUser,
    );
  }

  Future<Result> stockOut({
    required String itemId,
    required int quantity,
    required String party,
    required String reference,
    required DateTime date,
    String notes = '',
    bool adminOverride = false,
    required String byUser,
  }) async {
    return _movement(
      itemId: itemId,
      quantity: quantity,
      isIn: false,
      party: party,
      reference: reference.isEmpty ? party : reference,
      date: date,
      notes: notes.isEmpty ? 'Stock issued' : notes,
      adminOverride: adminOverride,
      byUser: byUser,
    );
  }

  Future<Result> _movement({
    required String itemId,
    required int quantity,
    required bool isIn,
    required String party,
    required String reference,
    required DateTime date,
    required String notes,
    required String byUser,
    bool adminOverride = false,
  }) async {
    if (quantity <= 0) {
      return Result.failure('Quantity must be greater than 0');
    }
    try {
      final ref = Db.items.doc(itemId);
      return await Db.instance.runTransaction<Result>((tx) async {
        // ---- reads ----
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) return Result.failure('Item not found');
        final item = StockItem.fromMap(snap.id, data);

        if (!isIn && quantity > item.quantity && !adminOverride) {
          return Result.failure(
            'Only ${item.quantity} ${item.unit} available in stock',
          );
        }

        final balance = isIn ? item.quantity + quantity : item.quantity - quantity;

        // ---- writes ----
        tx.update(ref, {
          'quantity': balance,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final txnRef = Db.transactions.doc();
        tx.set(
          txnRef,
          StockTransaction(
            id: txnRef.id,
            itemId: itemId,
            itemName: item.name,
            itemSku: item.sku,
            type: isIn ? TxnType.stockIn : TxnType.stockOut,
            quantity: quantity,
            balanceAfter: balance,
            date: date,
            party: party,
            reference: reference,
            notes: notes,
            user: byUser,
          ).toMap(),
        );

        return Result.success(
          isIn
              ? 'Added $quantity ${item.unit} of ${item.name}'
              : 'Removed $quantity ${item.unit} of ${item.name}',
        );
      });
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }
}
