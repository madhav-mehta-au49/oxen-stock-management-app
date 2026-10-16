import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType { lowStock, challan, summary, info }

/// An entry in the in-app notification centre (`notifications` collection).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.refId = '',
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Item id (low stock) or challan number (challan) used for tap-through.
  final String refId;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'body': body,
        'refId': refId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) =>
      AppNotification(
        id: id,
        type: AppNotificationType.values.firstWhere(
          (t) => t.name == data['type'],
          orElse: () => AppNotificationType.info,
        ),
        title: data['title'] as String? ?? '',
        body: data['body'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        refId: data['refId'] as String? ?? '',
      );
}
