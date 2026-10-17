import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/result.dart';
import '../../models/stock_item.dart';
import 'db.dart';

/// Global per-category GST rates stored at `meta/tax`.
class TaxRepository {
  const TaxRepository();

  /// All categories at 0% until the client sets real rates in Settings.
  static Map<String, double> defaults() => {
        for (final c in ItemCategory.values) c.label: 0.0,
      };

  Map<String, double> _parse(Map<String, dynamic>? data) {
    final raw = (data?['rates'] as Map?) ?? const {};
    return {
      for (final c in ItemCategory.values)
        c.label: (raw[c.label] as num?)?.toDouble() ?? 0,
    };
  }

  Stream<Map<String, double>> watchRates() =>
      Db.tax.snapshots().map((d) => _parse(d.data()));

  Future<Map<String, double>> getRates() async {
    final d = await Db.tax.get();
    return _parse(d.data());
  }

  Future<Result> saveRates(Map<String, double> rates) async {
    try {
      await Db.tax.set({'rates': rates}, SetOptions(merge: true));
      return Result.success('GST rates saved');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }

  Future<void> seedIfEmpty() async {
    final d = await Db.tax.get();
    if (!d.exists) await Db.tax.set({'rates': defaults()});
  }
}
