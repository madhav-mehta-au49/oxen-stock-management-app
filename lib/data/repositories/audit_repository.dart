import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/audit_entry.dart';
import 'db.dart';

/// Append-only audit trail (`auditLog`). Entries are written from within the
/// same Firestore transaction/batch as the change they describe.
class AuditRepository {
  const AuditRepository();

  /// Builds the field map for an audit entry (used inside transactions).
  static Map<String, dynamic> data({
    required String action,
    required String entity,
    required String entityId,
    required String entityLabel,
    required String userId,
    required String userName,
    String remarks = '',
  }) => {
    'action': action,
    'entity': entity,
    'entityId': entityId,
    'entityLabel': entityLabel,
    'userId': userId,
    'userName': userName.isEmpty ? userId : userName,
    'remarks': remarks,
    'at': FieldValue.serverTimestamp(),
  };

  Future<void> log({
    required String action,
    required String entity,
    required String entityId,
    required String entityLabel,
    required String userId,
    required String userName,
    String remarks = '',
  }) => Db.auditLog.add(
    data(
      action: action,
      entity: entity,
      entityId: entityId,
      entityLabel: entityLabel,
      userId: userId,
      userName: userName,
      remarks: remarks,
    ),
  );

  Stream<List<AuditEntry>> watchAll({int limit = 300}) => Db.auditLog
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => AuditEntry.fromMap(d.id, d.data())).toList(),
      );
}
