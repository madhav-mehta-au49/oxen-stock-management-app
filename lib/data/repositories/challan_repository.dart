import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/result.dart';
import '../../models/challan.dart';
import '../../models/stock_transaction.dart';
import 'audit_repository.dart';
import 'db.dart';

/// Result of issuing a challan: the outcome plus the assigned number.
typedef IssueResult = ({Result result, String number});

/// Firestore access for the `challans` collection (+ atomic stock deduction and
/// numbering via `meta/counters`, edit and cancel with stock restoration).
class ChallanRepository {
  const ChallanRepository();

  Stream<List<Challan>> watchAll() => Db.challans
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Challan.fromMap(d.id, d.data())).toList());

  Future<Challan?> getByNumber(String number) async {
    final q = await Db.challans
        .where('number', isEqualTo: number)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    return Challan.fromMap(d.id, d.data());
  }

  /// Next challan number for display (not reserved). Format `OX/CH/<year>/NNNN`.
  Future<String> peekNextNumber(DateTime date) async {
    final snap = await Db.counters.get();
    final data = snap.data();
    final year = date.year;
    var seq = 0;
    if (data != null) {
      final storedYear = (data['challanYear'] as num?)?.toInt() ?? year;
      if (storedYear == year) {
        seq = (data['challanSeq'] as num?)?.toInt() ?? 0;
      }
    }
    return _number(year, seq + 1);
  }

  static String _number(int year, int seq) =>
      'OX/CH/$year/${seq.toString().padLeft(4, '0')}';

  static String _docId(int year, int seq) =>
      'OX-CH-$year-${seq.toString().padLeft(4, '0')}';

  /// Validates stock, deducts each line, appends `challanOut` transactions,
  /// reserves the number and stores the challan — all atomically.
  Future<IssueResult> issue(
    Challan challan, {
    required String byUser,
    String byName = '',
  }) async {
    if (challan.lines.isEmpty) {
      return (
        result: Result.failure('Add at least one item to the challan'),
        number: '',
      );
    }
    try {
      return await Db.instance.runTransaction<IssueResult>((tx) async {
        // ---- reads ----
        final countersSnap = await tx.get(Db.counters);
        final year = challan.date.year;
        var seq = 0;
        if (countersSnap.exists) {
          final d = countersSnap.data()!;
          final storedYear = (d['challanYear'] as num?)?.toInt() ?? year;
          if (storedYear == year) {
            seq = (d['challanSeq'] as num?)?.toInt() ?? 0;
          }
        }

        final itemSnaps = <String, Map<String, dynamic>>{};
        for (final line in challan.lines) {
          final snap = await tx.get(Db.items.doc(line.itemId));
          final data = snap.data();
          if (data == null) {
            return (
              result: Result.failure('${line.itemName} no longer exists'),
              number: '',
            );
          }
          itemSnaps[line.itemId] = data;
        }

        // ---- validate ----
        for (final line in challan.lines) {
          final avail =
              (itemSnaps[line.itemId]!['quantity'] as num?)?.toInt() ?? 0;
          if (line.quantity > avail) {
            return (
              result: Result.failure(
                'Insufficient stock: ${line.itemName} (only $avail left)',
              ),
              number: '',
            );
          }
        }

        // ---- writes ----
        seq += 1;
        final number = _number(year, seq);
        final docId = _docId(year, seq);

        tx.set(Db.counters, {
          'challanYear': year,
          'challanSeq': seq,
        }, SetOptions(merge: true));

        for (final line in challan.lines) {
          final avail =
              (itemSnaps[line.itemId]!['quantity'] as num?)?.toInt() ?? 0;
          final after = avail - line.quantity;
          tx.update(Db.items.doc(line.itemId), {
            'quantity': after,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final txnRef = Db.transactions.doc();
          tx.set(
            txnRef,
            StockTransaction(
              id: txnRef.id,
              itemId: line.itemId,
              itemName: line.itemName,
              itemSku: line.sku,
              type: TxnType.challanOut,
              quantity: line.quantity,
              balanceAfter: after,
              date: challan.date,
              party: challan.billTo.name,
              reference: number,
              notes: 'Auto stock-out on challan issue',
              user: byUser,
            ).toMap(),
          );
        }

        final issued = Challan(
          id: docId,
          number: number,
          customerId: challan.customerId,
          billTo: challan.billTo,
          shipTo: challan.shipTo,
          sameAsBillTo: challan.sameAsBillTo,
          date: challan.date,
          lines: challan.lines,
          status: ChallanStatus.issued,
          vehicleNo: challan.vehicleNo,
          notes: challan.notes,
          preparedBy: byUser,
          format: challan.format,
          createdBy: byUser,
          createdByName: byName,
          updatedBy: byUser,
          updatedByName: byName,
        );
        tx.set(Db.challans.doc(docId), issued.toMap());
        tx.set(
          Db.auditLog.doc(),
          AuditRepository.data(
            action: 'created',
            entity: 'challan',
            entityId: docId,
            entityLabel: '$number • ${challan.billTo.name}',
            userId: byUser,
            userName: byName,
          ),
        );

        return (
          result: Result.success('Challan $number issued'),
          number: number,
        );
      });
    } catch (e) {
      return (result: Result.failure(firestoreMessage(e)), number: '');
    }
  }

  /// Edits an issued challan: reverses the old stock movement and applies the
  /// new lines in one transaction (net delta per item), then saves the challan.
  Future<Result> edit({
    required Challan oldChallan,
    required Challan updated,
    required String byUser,
    String byName = '',
  }) async {
    if (updated.lines.isEmpty) {
      return Result.failure('Add at least one item to the challan');
    }
    if (oldChallan.isCancelled) {
      return Result.failure('A cancelled challan cannot be edited');
    }
    try {
      return await Db.instance.runTransaction<Result>((tx) async {
        // Net delta per item: restore old, deduct new. Positive = stock back.
        final delta = <String, int>{};
        final names = <String, String>{};
        void add(String id, String name, int qty) {
          delta[id] = (delta[id] ?? 0) + qty;
          names[id] = name;
        }

        for (final l in oldChallan.lines) {
          add(l.itemId, l.itemName, l.quantity);
        }
        for (final l in updated.lines) {
          add(l.itemId, l.itemName, -l.quantity);
        }

        // ---- reads ----
        final current = <String, int>{};
        for (final id in delta.keys) {
          final snap = await tx.get(Db.items.doc(id));
          if (!snap.exists) {
            return Result.failure('${names[id] ?? id} no longer exists');
          }
          current[id] = (snap.data()?['quantity'] as num?)?.toInt() ?? 0;
        }

        // ---- validate ----
        for (final id in delta.keys) {
          final after = current[id]! + delta[id]!;
          if (after < 0) {
            return Result.failure(
              'Insufficient stock for ${names[id]} '
              '(only ${current[id]} available)',
            );
          }
        }

        // ---- writes ----
        for (final id in delta.keys) {
          final after = current[id]! + delta[id]!;
          tx.update(Db.items.doc(id), {
            'quantity': after,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (delta[id] == 0) continue;

          final txnRef = Db.transactions.doc();
          tx.set(
            txnRef,
            StockTransaction(
              id: txnRef.id,
              itemId: id,
              itemName: names[id] ?? '',
              itemSku: '',
              type: TxnType.adjustment,
              quantity: delta[id]!,
              balanceAfter: after,
              date: DateTime.now(),
              party: updated.billTo.name,
              reference: updated.number,
              notes: 'Challan edited',
              user: byUser,
            ).toMap(),
          );
        }

        tx.set(
          Db.challans.doc(updated.id),
          updated
              .copyWith(
                status: ChallanStatus.issued,
                updatedBy: byUser,
                updatedByName: byName,
              )
              .toMap(),
        );
        tx.set(
          Db.auditLog.doc(),
          AuditRepository.data(
            action: 'updated',
            entity: 'challan',
            entityId: updated.id,
            entityLabel: '${updated.number} • ${updated.billTo.name}',
            userId: byUser,
            userName: byName,
          ),
        );
        return Result.success('Challan ${updated.number} updated');
      });
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }

  /// Cancels an issued challan: restores every line's stock and keeps the
  /// record with status `Cancelled`.
  Future<Result> cancel(
    Challan challan, {
    required String byUser,
    String byName = '',
    String remarks = '',
  }) async {
    if (challan.isCancelled) {
      return Result.failure('Challan is already cancelled');
    }
    try {
      return await Db.instance.runTransaction<Result>((tx) async {
        // ---- reads ----
        final current = <String, int>{};
        for (final line in challan.lines) {
          final snap = await tx.get(Db.items.doc(line.itemId));
          current[line.itemId] =
              (snap.data()?['quantity'] as num?)?.toInt() ?? 0;
        }

        // ---- writes ----
        for (final line in challan.lines) {
          final after = current[line.itemId]! + line.quantity;
          tx.update(Db.items.doc(line.itemId), {
            'quantity': after,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final txnRef = Db.transactions.doc();
          tx.set(
            txnRef,
            StockTransaction(
              id: txnRef.id,
              itemId: line.itemId,
              itemName: line.itemName,
              itemSku: line.sku,
              type: TxnType.stockIn,
              quantity: line.quantity,
              balanceAfter: after,
              date: DateTime.now(),
              party: challan.billTo.name,
              reference: challan.number,
              notes: 'Challan cancelled — stock restored',
              user: byUser,
            ).toMap(),
          );
        }

        tx.update(Db.challans.doc(challan.id), {
          'status': ChallanStatus.cancelled.name,
          'cancelledBy': byUser,
          'cancelledByName': byName.isEmpty ? byUser : byName,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelRemarks': remarks,
        });
        tx.set(
          Db.auditLog.doc(),
          AuditRepository.data(
            action: 'cancelled',
            entity: 'challan',
            entityId: challan.id,
            entityLabel: '${challan.number} • ${challan.billTo.name}',
            userId: byUser,
            userName: byName,
            remarks: remarks,
          ),
        );
        return Result.success('Challan ${challan.number} cancelled');
      });
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }

  Future<Result> setFormat(String number, ChallanFormat format) async {
    try {
      final q = await Db.challans
          .where('number', isEqualTo: number)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return Result.failure('Challan not found');
      await q.docs.first.reference.update({'format': format.name});
      return Result.success('Format set to ${format.label}');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }
}
