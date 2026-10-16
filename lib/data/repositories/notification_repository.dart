import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_notification.dart';
import 'db.dart';

/// Reads/writes the shared `notifications` feed and the per-user read state
/// (stored on `settings/{uid}`).
class NotificationRepository {
  const NotificationRepository();

  CollectionReference<Map<String, dynamic>> get _col =>
      Db.instance.collection('notifications');

  Stream<List<AppNotification>> watchRecent({int limit = 60}) => _col
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => AppNotification.fromMap(d.id, d.data())).toList());

  Future<void> add(AppNotification notification) async {
    final ref = _col.doc();
    await ref.set(notification.toMap());
  }

  Stream<DateTime?> watchSeenAt(String uid) =>
      Db.settingsDoc(uid).snapshots().map((d) {
        final ts = d.data()?['notificationsSeenAt'] as Timestamp?;
        return ts?.toDate();
      });

  Future<void> markSeen(String uid, DateTime at) => Db.settingsDoc(uid).set(
        {'notificationsSeenAt': Timestamp.fromDate(at)},
        SetOptions(merge: true),
      );

  Future<String?> lastSummaryDate(String uid) async {
    final snap = await Db.settingsDoc(uid).get();
    return snap.data()?['lastSummaryDate'] as String?;
  }

  Future<void> setLastSummaryDate(String uid, String dateKey) =>
      Db.settingsDoc(uid).set(
        {'lastSummaryDate': dateKey},
        SetOptions(merge: true),
      );
}
