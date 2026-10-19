import 'package:cloud_firestore/cloud_firestore.dart';

/// One immutable row in the `auditLog` collection describing who did what.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.entityLabel,
    required this.userId,
    required this.userName,
    this.remarks = '',
    required this.at,
  });

  /// created | updated | deleted | cancelled
  final String action;

  /// item | challan | customer | category | user
  final String entity;
  final String id;
  final String entityId;
  final String entityLabel;
  final String userId;
  final String userName;
  final String remarks;
  final DateTime at;

  String get actionLabel => switch (action) {
    'created' => 'Created',
    'updated' => 'Updated',
    'deleted' => 'Deleted',
    'cancelled' => 'Cancelled',
    _ =>
      action.isEmpty
          ? 'Changed'
          : action[0].toUpperCase() + action.substring(1),
  };

  String get entityTypeLabel => switch (entity) {
    'item' => 'Item',
    'challan' => 'Challan',
    'customer' => 'Customer',
    'category' => 'Category',
    'user' => 'User',
    _ =>
      entity.isEmpty ? 'Record' : entity[0].toUpperCase() + entity.substring(1),
  };

  Map<String, dynamic> toMap() => {
    'action': action,
    'entity': entity,
    'entityId': entityId,
    'entityLabel': entityLabel,
    'userId': userId,
    'userName': userName,
    'remarks': remarks,
    'at': Timestamp.fromDate(at),
  };

  factory AuditEntry.fromMap(String id, Map<String, dynamic> data) =>
      AuditEntry(
        id: id,
        action: data['action'] as String? ?? '',
        entity: data['entity'] as String? ?? '',
        entityId: data['entityId'] as String? ?? '',
        entityLabel: data['entityLabel'] as String? ?? '',
        userId: data['userId'] as String? ?? '',
        userName: data['userName'] as String? ?? '',
        remarks: data['remarks'] as String? ?? '',
        at: (data['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
