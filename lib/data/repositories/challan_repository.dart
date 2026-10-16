import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/result.dart';
import '../../models/challan.dart';
import '../../models/stock_transaction.dart';
import 'db.dart';

/// Result of issuing a challan: the outcome plus the assigned number.
typedef IssueResult = ({Result result, String number});

/// Firestore access for the `challans` collection (+ atomic stock deduction and
/// numbering via `meta/counters`).
class ChallanRepository {
  const ChallanRepository();

  Stream<List<Challan>> watchAll() => Db.challans
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => Challan.fromMap(d.id, d.data())).toList());

  Future<Challan?> getByNumber(String number) async {
    final q =
        await Db.challans.where('number', isEqualTo: number).limit(1).get();
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
  Future<IssueResult> issue(Challan challan, {required String byUser}) async {
    if (challan.lines.isEmpty) {
      return (result: Result.failure('Add at least one item to the challan'), number: '');
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
          final avail = (itemSnaps[line.itemId]!['quantity'] as num?)?.toInt() ?? 0;
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

        tx.set(
          Db.counters,
          {'challanYear': year, 'challanSeq': seq},
          SetOptions(merge: true),
        );

        for (final line in challan.lines) {
          final avail = (itemSnaps[line.itemId]!['quantity'] as num?)?.toInt() ?? 0;
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
              party: challan.customerName,
              reference: number,
              notes: 'Auto stock-out on challan issue',
              user: byUser,
            ).toMap(),
          );
        }

        final issued = Challan(
          id: docId,
          number: number,
          customerName: challan.customerName,
          siteName: challan.siteName,
          address: challan.address,
          contact: challan.contact,
          date: challan.date,
          lines: challan.lines,
          status: ChallanStatus.issued,
          vehicleNo: challan.vehicleNo,
          notes: challan.notes,
          preparedBy: byUser,
          format: challan.format,
        );
        tx.set(Db.challans.doc(docId), issued.toMap());

        return (result: Result.success('Challan $number issued'), number: number);
      });
    } catch (e) {
      return (result: Result.failure(firestoreMessage(e)), number: '');
    }
  }

  Future<Result> setFormat(String number, ChallanFormat format) async {
    try {
      final q =
          await Db.challans.where('number', isEqualTo: number).limit(1).get();
      if (q.docs.isEmpty) return Result.failure('Challan not found');
      await q.docs.first.reference.update({'format': format.name});
      return Result.success('Format set to ${format.label}');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }
}
