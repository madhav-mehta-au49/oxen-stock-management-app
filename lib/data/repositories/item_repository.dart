import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/result.dart';
import '../../models/stock_item.dart';
import '../../models/stock_transaction.dart';
import 'db.dart';

/// Firestore access for the `items` collection (+ ledger adjustments).
///
/// SKU uniqueness is enforced atomically through the `skuIndex` collection so
/// two users creating the same SKU at the same time can never both succeed.
class ItemRepository {
  const ItemRepository();

  Stream<List<StockItem>> watchItems() => Db.items
      .orderBy('name')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => StockItem.fromMap(d.id, d.data())).toList());

  Future<StockItem?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await Db.items.doc(id).get();
    final data = snap.data();
    return data == null ? null : StockItem.fromMap(snap.id, data);
  }

  /// Non-authoritative pre-check (used for inline hints); the real guard runs
  /// inside the transaction in [upsert] / [quickCreate].
  Future<bool> skuExists(String sku, {String? exceptId}) async {
    final clean = sku.trim().toUpperCase();
    if (clean.isEmpty) return false;
    final snap = await Db.skuIndex.doc(clean).get();
    if (!snap.exists) return false;
    final owner = snap.data()?['itemId'];
    return owner != exceptId;
  }

  /// Create or update an item. New items get a sequential code (`ITM-001`,
  /// `ITM-002`, …) so numbering always starts from 1. A quantity change writes
  /// an `adjustment` ledger entry in the same transaction.
  Future<({Result result, String id})> upsert(
    StockItem item, {
    required String byUser,
  }) async {
    final isNew = item.id.isEmpty;
    final cleanSku = item.sku.trim().toUpperCase();
    var assignedId = item.id;

    try {
      final result = await Db.instance.runTransaction<Result>((tx) async {
        // ---- reads ----
        Map<String, dynamic>? existing;
        if (!isNew) {
          final snap = await tx.get(Db.items.doc(item.id));
          if (!snap.exists) return Result.failure('Item no longer exists');
          existing = snap.data();
        }
        DocumentSnapshot<Map<String, dynamic>>? skuSnap;
        if (cleanSku.isNotEmpty) {
          skuSnap = await tx.get(Db.skuIndex.doc(cleanSku));
        }
        var nextSeq = 0;
        if (isNew) {
          final countersSnap = await tx.get(Db.counters);
          nextSeq =
              ((countersSnap.data()?['itemSeq'] as num?)?.toInt() ?? 0) + 1;
          assignedId = 'ITM-${nextSeq.toString().padLeft(3, '0')}';
        }
        final ref = Db.items.doc(isNew ? assignedId : item.id);
        final oldSku = (existing?['sku'] as String?)?.trim().toUpperCase();

        // ---- validate ----
        if (cleanSku.isNotEmpty && skuSnap != null && skuSnap.exists) {
          final owner = (skuSnap.data()?['itemId'] as String?) ?? '';
          if (owner != ref.id) {
            return Result.failure('SKU $cleanSku is already used by another item');
          }
        }

        final effectiveSku =
            cleanSku.isEmpty ? (isNew ? assignedId : '') : cleanSku;

        // ---- writes ----
        final data = item.toMap();
        data['sku'] = effectiveSku;
        data['updatedAt'] = FieldValue.serverTimestamp();
        tx.set(ref, data, SetOptions(merge: !isNew));

        if (isNew) {
          tx.set(Db.counters, {'itemSeq': nextSeq}, SetOptions(merge: true));
        }
        if (effectiveSku.isNotEmpty) {
          tx.set(
            Db.skuIndex.doc(effectiveSku),
            {'itemId': ref.id, 'sku': effectiveSku},
          );
        }
        if (!isNew &&
            oldSku != null &&
            oldSku.isNotEmpty &&
            oldSku != effectiveSku) {
          tx.delete(Db.skuIndex.doc(oldSku));
        }

        if (!isNew && existing != null) {
          final oldQty = (existing['quantity'] as num?)?.toInt() ?? 0;
          final delta = item.quantity - oldQty;
          if (delta != 0) {
            final txnRef = Db.transactions.doc();
            tx.set(
              txnRef,
              StockTransaction(
                id: txnRef.id,
                itemId: ref.id,
                itemName: item.name,
                itemSku: effectiveSku,
                type: TxnType.adjustment,
                quantity: delta,
                balanceAfter: item.quantity,
                date: DateTime.now(),
                party: 'Manual edit',
                reference: 'Quantity adjusted',
                notes: 'Updated from $oldQty to ${item.quantity} ${item.unit}',
                user: byUser,
              ).toMap(),
            );
          }
        }

        return Result.success(
          isNew ? '${item.name} added to stock' : '${item.name} updated',
        );
      });
      return (result: result, id: assignedId);
    } catch (e) {
      return (result: Result.failure(firestoreMessage(e)), id: assignedId);
    }
  }

  /// Creates an item instantly (quick-add) with the next sequential code.
  /// Returns null for an invalid name or a duplicate SKU.
  Future<StockItem?> quickCreate({
    required String name,
    required String sku,
    required ItemCategory category,
    required String unit,
    double purchasePrice = 0,
    double sellingPrice = 0,
    String supplier = '',
    String unitNos = '',
  }) async {
    final cleanName = name.trim();
    final cleanSku = sku.trim().toUpperCase();
    final cleanUnit = unit.trim().isEmpty ? 'Unit' : unit.trim();
    if (cleanName.length < 3) return null;

    try {
      late StockItem created;
      final ok = await Db.instance.runTransaction<bool>((tx) async {
        // ---- reads ----
        final countersSnap = await tx.get(Db.counters);
        final seq =
            ((countersSnap.data()?['itemSeq'] as num?)?.toInt() ?? 0) + 1;
        final id = 'ITM-${seq.toString().padLeft(3, '0')}';
        final effectiveSku = cleanSku.isEmpty ? id : cleanSku;
        final skuSnap = await tx.get(Db.skuIndex.doc(effectiveSku));
        if (skuSnap.exists) return false;

        // ---- writes ----
        final item = StockItem(
          id: id,
          name: cleanName,
          category: category,
          sku: effectiveSku,
          unit: cleanUnit,
          quantity: 0,
          reorderLevel: 0,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          supplier: supplier.trim(),
          glyphKey: category.glyphKey,
          unitNos: unitNos.trim(),
          createdAt: DateTime.now(),
        );
        final data = item.toMap();
        data['updatedAt'] = FieldValue.serverTimestamp();
        tx.set(Db.items.doc(id), data);
        tx.set(Db.counters, {'itemSeq': seq}, SetOptions(merge: true));
        tx.set(
          Db.skuIndex.doc(effectiveSku),
          {'itemId': id, 'sku': effectiveSku},
        );
        created = item;
        return true;
      });

      return ok ? created : null;
    } catch (_) {
      return null;
    }
  }

  /// Removes an item, its SKU index, its ledger entries, and strips it from any
  /// challan lines.
  Future<Result> delete(String itemId, String name) async {
    try {
      final itemSnap = await Db.items.doc(itemId).get();
      final sku =
          (itemSnap.data()?['sku'] as String?)?.trim().toUpperCase() ?? '';

      final batch = Db.instance.batch();
      if (sku.isNotEmpty) batch.delete(Db.skuIndex.doc(sku));
      batch.delete(Db.instance.collection('itemImages').doc(itemId));

      final txns =
          await Db.transactions.where('itemId', isEqualTo: itemId).get();
      for (final d in txns.docs) {
        batch.delete(d.reference);
      }

      final linked =
          await Db.challans.where('lines.itemId', arrayContains: itemId).get();
      for (final d in linked.docs) {
        final lines = ((d.data()['lines'] as List?) ?? const [])
            .whereType<Map>()
            .where((l) => l['itemId'] != itemId)
            .map((l) => Map<String, dynamic>.from(l))
            .toList();
        batch.update(d.reference, {'lines': lines});
      }

      batch.delete(Db.items.doc(itemId));
      await batch.commit();

      return Result.success('$name removed');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }
}
