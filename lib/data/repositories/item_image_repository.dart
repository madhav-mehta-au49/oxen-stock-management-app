import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'db.dart';

/// Stores the full-size product photo as base64 in Firestore (`itemImages/{id}`).
/// The small list thumbnail lives in the `items` document itself.
class ItemImageRepository {
  const ItemImageRepository();

  CollectionReference<Map<String, dynamic>> get _col =>
      Db.instance.collection('itemImages');

  Future<void> saveFull(String itemId, Uint8List bytes) async {
    await _col.doc(itemId).set({
      'data': base64Encode(bytes),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Uint8List?> loadFull(String itemId) async {
    if (itemId.isEmpty) return null;
    final snap = await _col.doc(itemId).get();
    final data = snap.data()?['data'] as String?;
    if (data == null || data.isEmpty) return null;
    return base64Decode(data);
  }

  Future<void> delete(String itemId) => _col.doc(itemId).delete();
}
