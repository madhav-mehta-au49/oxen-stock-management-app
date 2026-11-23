import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/result.dart';
import '../../models/challan.dart';
import '../../models/proforma.dart';
import 'audit_repository.dart';
import 'db.dart';

/// Result of issuing a proforma: outcome + assigned number.
typedef ProformaIssueResult = ({Result result, String number});

/// Firestore access for the `proformas` collection. A PI is a quotation built
/// from current stock — it never changes item quantities. Numbering is
/// `OX/PI/<year>/NNNN` via `meta/counters` (independent of the challan counter).
class ProformaRepository {
  const ProformaRepository();

  Stream<List<Proforma>> watchAll() => Db.proformas
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Proforma.fromMap(d.id, d.data())).toList());

  Future<Proforma?> getByNumber(String number) async {
    final q = await Db.proformas
        .where('number', isEqualTo: number)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    return Proforma.fromMap(d.id, d.data());
  }

  /// Next PI number for display (not reserved). `OX/PI/<year>/NNNN`.
  Future<String> peekNextNumber(DateTime date) async {
    final snap = await Db.counters.get();
    final data = snap.data();
    final year = date.year;
    var seq = 0;
    if (data != null) {
      final storedYear = (data['piYear'] as num?)?.toInt() ?? year;
      if (storedYear == year) {
        seq = (data['piSeq'] as num?)?.toInt() ?? 0;
      }
    }
    return _number(year, seq + 1);
  }

  static String _number(int year, int seq) =>
      'OX/PI/$year/${seq.toString().padLeft(4, '0')}';

  static String _docId(int year, int seq) =>
      'OX-PI-$year-${seq.toString().padLeft(4, '0')}';

  /// Creates (or, when [existing] is provided, updates) a PI. No stock changes.
  Future<ProformaIssueResult> save(
    Proforma proforma, {
    required String byUser,
    String byName = '',
    Proforma? existing,
  }) async {
    if (proforma.lines.isEmpty) {
      return (
        result: Result.failure('Add at least one item to the proforma'),
        number: '',
      );
    }
    final isNew = existing == null;
    try {
      return await Db.instance.runTransaction<ProformaIssueResult>((tx) async {
        final year = proforma.date.year;
        var seq = 0;
        var docId = existing?.id ?? '';
        var number = existing?.number ?? '';

        if (isNew) {
          final countersSnap = await tx.get(Db.counters);
          if (countersSnap.exists) {
            final d = countersSnap.data()!;
            final storedYear = (d['piYear'] as num?)?.toInt() ?? year;
            if (storedYear == year) {
              seq = (d['piSeq'] as num?)?.toInt() ?? 0;
            }
          }
          seq += 1;
          number = _number(year, seq);
          docId = _docId(year, seq);
          tx.set(Db.counters, {
            'piYear': year,
            'piSeq': seq,
          }, SetOptions(merge: true));
        }

        final saved = Proforma(
          id: docId,
          number: number,
          customerId: proforma.customerId,
          billTo: proforma.billTo,
          shipTo: proforma.shipTo,
          sameAsBillTo: proforma.sameAsBillTo,
          date: proforma.date,
          lines: proforma.lines,
          status: existing?.status ?? ProformaStatus.issued,
          vehicleNo: proforma.vehicleNo,
          notes: proforma.notes,
          preparedBy: byUser,
          format: proforma.format,
          validityDays: proforma.validityDays,
          createdBy: existing?.createdBy ?? byUser,
          createdByName: existing?.createdByName ?? byName,
          updatedBy: byUser,
          updatedByName: byName,
          cancelledBy: existing?.cancelledBy ?? '',
          cancelledByName: existing?.cancelledByName ?? '',
          cancelledAt: existing?.cancelledAt,
          cancelRemarks: existing?.cancelRemarks ?? '',
          convertedAt: existing?.convertedAt,
          challanNumber: existing?.challanNumber ?? '',
        );
        tx.set(Db.proformas.doc(docId), saved.toMap());
        tx.set(
          Db.auditLog.doc(),
          AuditRepository.data(
            action: isNew ? 'created' : 'updated',
            entity: 'proforma',
            entityId: docId,
            entityLabel: '$number • ${proforma.billTo.name}',
            userId: byUser,
            userName: byName,
          ),
        );

        return (
          result: Result.success(
            isNew ? 'Proforma $number created' : 'Proforma $number updated',
          ),
          number: number,
        );
      });
    } catch (e) {
      return (result: Result.failure(firestoreMessage(e)), number: '');
    }
  }

  /// Cancels a PI (keeps the record). No stock to restore.
  Future<Result> cancel(
    Proforma proforma, {
    required String byUser,
    String byName = '',
    String remarks = '',
  }) async {
    if (proforma.isCancelled) {
      return Result.failure('Proforma is already cancelled');
    }
    if (proforma.isConverted) {
      return Result.failure('A converted proforma cannot be cancelled');
    }
    try {
      await Db.proformas.doc(proforma.id).update({
        'status': ProformaStatus.cancelled.name,
        'cancelledBy': byUser,
        'cancelledByName': byName.isEmpty ? byUser : byName,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelRemarks': remarks,
      });
      await const AuditRepository().log(
        action: 'cancelled',
        entity: 'proforma',
        entityId: proforma.id,
        entityLabel: '${proforma.number} • ${proforma.billTo.name}',
        userId: byUser,
        userName: byName,
        remarks: remarks,
      );
      return Result.success('Proforma ${proforma.number} cancelled');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }

  /// Links the PI to the challan it was converted into and marks it converted.
  Future<void> markConverted({
    required String proformaId,
    required String challanNumber,
    required String byUser,
    String byName = '',
    required String entityLabel,
  }) async {
    try {
      await Db.proformas.doc(proformaId).update({
        'status': ProformaStatus.converted.name,
        'convertedAt': FieldValue.serverTimestamp(),
        'challanNumber': challanNumber,
        'updatedBy': byUser,
        'updatedByName': byName,
      });
      await const AuditRepository().log(
        action: 'converted',
        entity: 'proforma',
        entityId: proformaId,
        entityLabel: entityLabel,
        userId: byUser,
        userName: byName,
        remarks: 'Converted to challan $challanNumber',
      );
    } catch (_) {
      // Linking is best-effort; the challan itself is already issued.
    }
  }

  Future<Result> setFormat(String number, ChallanFormat format) async {
    try {
      final q = await Db.proformas
          .where('number', isEqualTo: number)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return Result.failure('Proforma not found');
      await q.docs.first.reference.update({'format': format.name});
      return Result.success('Format set to ${format.label}');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }
}
