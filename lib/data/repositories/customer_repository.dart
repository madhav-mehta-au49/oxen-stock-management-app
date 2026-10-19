import '../../core/utils/result.dart';
import '../../models/customer.dart';
import 'db.dart';

/// Firestore access for the `customers` collection.
class CustomerRepository {
  const CustomerRepository();

  Stream<List<Customer>> watchAll() => Db.customers
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => Customer.fromMap(d.id, d.data())).toList());

  Future<List<Customer>> getAll() async {
    final snap = await Db.customers.orderBy('name').get();
    return snap.docs.map((d) => Customer.fromMap(d.id, d.data())).toList();
  }

  Future<Customer?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await Db.customers.doc(id).get();
    final data = snap.data();
    return data == null ? null : Customer.fromMap(snap.id, data);
  }

  Future<bool> nameExists(String name, {String? exceptId}) async {
    final clean = name.trim().toLowerCase();
    final snap = await Db.customers.get();
    return snap.docs.any((d) {
      final data = d.data();
      return d.id != exceptId &&
          (data['name'] as String? ?? '').trim().toLowerCase() == clean;
    });
  }

  /// Creates a customer and returns its id (null if the name is taken).
  Future<String?> create(Customer customer) async {
    try {
      if (await nameExists(customer.name)) return null;
      final ref = Db.customers.doc();
      await ref.set(customer.toMap());
      return ref.id;
    } catch (_) {
      return null;
    }
  }

  Future<Result> update(Customer customer) async {
    try {
      if (await nameExists(customer.name, exceptId: customer.id)) {
        return Result.failure(
          'A customer named "${customer.name}" already exists',
        );
      }
      await Db.customers.doc(customer.id).set(customer.toMap());
      return Result.success('${customer.name} updated');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }

  Future<Result> delete(String id, String name) async {
    try {
      await Db.customers.doc(id).delete();
      return Result.success('$name removed');
    } catch (e) {
      return Result.failure(firestoreMessage(e));
    }
  }
}
