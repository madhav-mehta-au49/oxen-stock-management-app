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

  /// True when a daily-summary notification already exists on [day] (local).
  /// Guards against duplicate summaries across app opens / devices.
  Future<bool> hasSummaryOn(DateTime day) async {
    try {
      final start = Timestamp.fromDate(DateTime(day.year, day.month, day.day));
      final q = await _col
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .limit(30)
          .get();
      return q.docs.any((d) => d.data()['type'] == 'summary');
    } catch (_) {
      return false;
    }
  }

  Future<void> setLastSummaryDate(String uid, String dateKey) =>
      Db.settingsDoc(uid).set(
        {'lastSummaryDate': dateKey},
        SetOptions(merge: true),
      );
}
