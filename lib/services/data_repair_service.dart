import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/repositories/db.dart';
import '../models/category.dart';

class RepairReport {
  const RepairReport({
    required this.items,
    required this.challans,
    required this.customers,
  });

  final int items;
  final int challans;
  final int customers;

  String get summary =>
      'Items updated: $items • Challans updated: $challans • '
      'Customers added: $customers';
}

/// One-off, idempotent repair for data saved with the previous schema:
/// - items: legacy `category` enum -> `categoryId` / `categoryName`
/// - challans: legacy `customerName`/`siteName`/`address`/`contact` ->
///   `billTo` / `shipTo`
/// - customers: created from previous challans (deduplicated by name)
///
/// Nothing is deleted.
class DataRepairService {
  const DataRepairService._();

  static Future<RepairReport> run() async {
    var items = 0;
    var challans = 0;
    var customers = 0;

    // ---- items: resolve legacy `category` against categories in Firestore ----
    final categoriesSnap = await Db.categories.get();
    final categoryByNorm = <String, (String, String)>{};
    for (final c in categoriesSnap.docs) {
      final name = (c.data()['name'] as String?) ?? '';
      if (name.trim().isEmpty) continue;
      categoryByNorm[Category.normalize(name)] = (c.id, name);
    }

    final itemSnap = await Db.items.get();
    for (final doc in itemSnap.docs) {
      final data = doc.data();
      if ((data['categoryId'] as String? ?? '').isNotEmpty) continue;
      final legacy = data['category'] as String? ?? '';
      if (legacy.trim().isEmpty) continue;
      final match = categoryByNorm[Category.normalize(legacy)];
      if (match != null) {
        await doc.reference.update({
          'categoryId': match.$1,
          'categoryName': match.$2,
        });
      } else {
        // No matching category: keep a readable label for the admin to fix.
        await doc.reference.update({
          'categoryName': Category.humanize(legacy),
        });
      }
      items++;
    }

    // ---- challans: legacy fields -> billTo/shipTo ----
    final challanSnap = await Db.challans.get();
    final toEnsure = <String, Map<String, String>>{};
    for (final doc in challanSnap.docs) {
      final data = doc.data();
      if (data['billTo'] != null) continue;
      final name = (data['customerName'] as String? ?? '').trim();
      final site = data['siteName'] as String? ?? '';
      final address = data['address'] as String? ?? '';
      final contact = data['contact'] as String? ?? '';
      await doc.reference.update({
        'billTo': {
          'name': name,
          'siteProject': '',
          'address': address,
          'phone': contact,
          'gstin': '',
          'contactPerson': '',
        },
        'shipTo': {
          'name': name,
          'siteProject': site,
          'address': address,
          'phone': contact,
          'gstin': '',
          'contactPerson': '',
        },
        'customerId': data['customerId'] ?? '',
        'sameAsBillTo': false,
      });
      challans++;
      if (name.isNotEmpty) {
        toEnsure.putIfAbsent(
          name.toLowerCase(),
          () => {'name': name, 'phone': contact, 'address': address},
        );
      }
    }

    // ---- customers: create missing (deduplicated by name) ----
    final custSnap = await Db.customers.get();
    final byName = <String, String>{};
    for (final d in custSnap.docs) {
      final n = ((d.data()['name'] as String?) ?? '').trim().toLowerCase();
      if (n.isNotEmpty) byName[n] = d.id;
    }
    for (final entry in toEnsure.entries) {
      if (byName.containsKey(entry.key)) continue;
      final c = entry.value;
      final ref = await Db.customers.add({
        'name': c['name'],
        'phone': c['phone'] ?? '',
        'gstin': '',
        'billToAddress': c['address'] ?? '',
        'contactPerson': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      byName[entry.key] = ref.id;
      customers++;
    }

    // ---- link old challans to their customer (only where missing) ----
    for (final doc in challanSnap.docs) {
      final data = doc.data();
      final existingId = (data['customerId'] as String? ?? '').trim();
      final name = (data['customerName'] as String? ??
              (data['billTo'] as Map?)?['name'] as String? ??
              '')
          .trim()
          .toLowerCase();
      if (existingId.isNotEmpty || name.isEmpty) continue;
      final id = byName[name];
      if (id != null) {
        await doc.reference.update({'customerId': id});
      }
    }

    return RepairReport(
      items: items,
      challans: challans,
      customers: customers,
    );
  }
}
