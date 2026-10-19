import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/result.dart';
import '../../models/company_profile.dart';
import 'db.dart';

/// Firestore access for `meta/company` (drives the challan PDF).
class MetaRepository {
  const MetaRepository();

  Stream<CompanyProfile> watchCompany() => Db.company.snapshots().map(
    (d) => d.data() == null
        ? CompanyProfile.fallback
        : CompanyProfile.fromMap(d.data()!),
  );

  Future<CompanyProfile> getCompany() async {
    final snap = await Db.company.get();
    final data = snap.data();
    return data == null
        ? CompanyProfile.fallback
        : CompanyProfile.fromMap(data);
  }

  Future<Result> saveCompany(CompanyProfile profile) async {
    try {
      await Db.company.set(profile.toMap(), SetOptions(merge: true));
      return Result.success('Company profile saved');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }

  Future<void> seedIfEmpty(CompanyProfile profile) async {
    final snap = await Db.company.get();
    if (!snap.exists) {
      await Db.company.set(profile.toMap());
    }
  }
}
