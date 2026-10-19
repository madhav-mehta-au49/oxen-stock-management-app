import '../../core/utils/result.dart';
import '../../models/category.dart';
import 'db.dart';

/// Global stock categories (`categories` collection). GST lives on each category.
class CategoryRepository {
  const CategoryRepository();

  Stream<List<Category>> watchAll() => Db.categories
      .orderBy('sortOrder')
      .snapshots()
      .map((s) => s.docs.map((d) => Category.fromMap(d.id, d.data())).toList());

  Future<List<Category>> getAll() async {
    final snap = await Db.categories.orderBy('sortOrder').get();
    return snap.docs.map((d) => Category.fromMap(d.id, d.data())).toList();
  }

  Future<void> seedIfEmpty() async {
    final snap = await Db.categories.limit(1).get();
    if (snap.docs.isNotEmpty) return;
    final batch = Db.instance.batch();
    for (final c in Category.defaults) {
      batch.set(Db.categories.doc(c.id), c.toMap());
    }
    await batch.commit();
  }

  /// One-time migration: copy the GST rates from the legacy `meta/tax` doc onto
  /// matching categories that still have 0%. Idempotent (safe to run every
  /// launch); requires category-edit permission to actually write.
  Future<void> migrateGstFromLegacyTax() async {
    try {
      final taxSnap = await Db.tax.get();
      final raw = taxSnap.data()?['rates'];
      if (raw is! Map) return;
      final rates = <String, double>{
        for (final e in raw.entries)
          e.key.toString(): (e.value as num?)?.toDouble() ?? 0,
      };
      if (rates.isEmpty) return;

      final cats = await getAll();
      final batch = Db.instance.batch();
      var changed = 0;
      for (final c in cats) {
        if (c.gstRate > 0) continue;
        final rate = rates[c.name];
        if (rate == null || rate <= 0) continue;
        batch.update(Db.categories.doc(c.id), {'gstRate': rate});
        changed++;
      }
      if (changed > 0) await batch.commit();
    } catch (_) {
      // Best effort — the admin can always set rates in Manage categories.
    }
  }

  Future<bool> nameExists(String name, {String? exceptId}) async {
    final clean = name.trim().toLowerCase();
    final all = await getAll();
    return all.any(
      (c) => c.name.trim().toLowerCase() == clean && c.id != exceptId,
    );
  }

  Future<Result> create(Category category) async {
    try {
      if (await nameExists(category.name)) {
        return Result.failure(
          'A category named "${category.name}" already exists',
        );
      }
      await Db.categories.doc().set(category.toMap());
      return Result.success('${category.name} added');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }

  Future<Result> update(Category category) async {
    try {
      if (await nameExists(category.name, exceptId: category.id)) {
        return Result.failure(
          'A category named "${category.name}" already exists',
        );
      }
      await Db.categories.doc(category.id).set(category.toMap());
      return Result.success('${category.name} updated');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }

  Future<Result> delete(String id) async {
    try {
      await Db.categories.doc(id).delete();
      return Result.success('Category deleted');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }

  /// Keeps the denormalised category name on items in sync after a rename.
  Future<void> renameItems(String categoryId, String newName) async {
    final snap = await Db.items
        .where('categoryId', isEqualTo: categoryId)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = Db.instance.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'categoryName': newName});
    }
    await batch.commit();
  }
}
