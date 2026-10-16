import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_settings.dart';
import 'db.dart';

/// Firestore access for per-user preferences (`settings/{uid}`).
class SettingsRepository {
  const SettingsRepository();

  Stream<AppSettings> watch(String uid) => Db.settingsDoc(uid)
      .snapshots()
      .map((d) => d.data() == null
          ? AppSettings.defaults
          : AppSettings.fromMap(d.data()!));

  Future<AppSettings> get(String uid) async {
    final snap = await Db.settingsDoc(uid).get();
    final data = snap.data();
    return data == null ? AppSettings.defaults : AppSettings.fromMap(data);
  }

  Future<void> save(String uid, AppSettings settings) =>
      Db.settingsDoc(uid).set(settings.toMap(), SetOptions(merge: true));
}
