import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/result.dart';
import '../../models/app_user.dart';
import 'db.dart';

/// Firestore access for `users/{uid}` profiles.
class UserRepository {
  const UserRepository();

  Stream<List<AppUser>> watchUsers() => Db.users.snapshots().map(
    (s) => s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList(),
  );

  Stream<AppUser?> watchProfile(String uid) => Db.users
      .doc(uid)
      .snapshots()
      .map((d) => d.data() == null ? null : AppUser.fromMap(d.id, d.data()!));

  Future<AppUser?> getProfile(String uid) async {
    final snap = await Db.users.doc(uid).get();
    final data = snap.data();
    return data == null ? null : AppUser.fromMap(snap.id, data);
  }

  /// Creates the profile doc if it is missing (called after first sign-in).
  /// The very first user becomes an `admin`; everyone else starts as `staff`.
  Future<void> ensureProfile({
    required String uid,
    required String email,
    String name = '',
  }) async {
    final doc = Db.users.doc(uid);
    final existing = await doc.get();
    if (existing.exists) return;

    final any = await Db.users.limit(1).get();
    final role = any.docs.isEmpty ? 'admin' : 'staff';

    await doc.set({
      'email': email,
      'name': name.isEmpty ? email.split('@').first : name,
      'role': role,
      'active': true,
    });
  }

  Future<Result> upsert(AppUser user) async {
    try {
      await Db.users.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
      return Result.success('${user.name} saved');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }

  /// Updates only the given field paths (e.g. `permissions.challanCreate`), so a
  /// stale screen can never overwrite permissions it did not touch.
  Future<Result> updateFields(String uid, Map<String, dynamic> fields) async {
    if (fields.isEmpty) return Result.success('Saved');
    try {
      await Db.users.doc(uid).update(fields);
      return Result.success('Saved');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }
}
