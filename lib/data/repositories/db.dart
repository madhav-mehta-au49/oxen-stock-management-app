import 'package:cloud_firestore/cloud_firestore.dart';

/// Central Firestore collection/document references.
class Db {
  const Db._();

  static FirebaseFirestore get instance => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get items =>
      instance.collection('items');

  static CollectionReference<Map<String, dynamic>> get transactions =>
      instance.collection('transactions');

  static CollectionReference<Map<String, dynamic>> get challans =>
      instance.collection('challans');

  static CollectionReference<Map<String, dynamic>> get users =>
      instance.collection('users');

  static CollectionReference<Map<String, dynamic>> get categories =>
      instance.collection('categories');

  /// Unique-SKU guard: `skuIndex/{SKU} -> { itemId }`. Created/deleted inside the
  /// same transaction as the item, so duplicate SKUs can never be saved.
  static CollectionReference<Map<String, dynamic>> get skuIndex =>
      instance.collection('skuIndex');

  static DocumentReference<Map<String, dynamic>> settingsDoc(String uid) =>
      instance.collection('settings').doc(uid);

  static DocumentReference<Map<String, dynamic>> get counters =>
      instance.collection('meta').doc('counters');

  static DocumentReference<Map<String, dynamic>> get company =>
      instance.collection('meta').doc('company');

  /// Global per-category GST rates: `{ rates: { "<Category>": 12.0, ... } }`.
  static DocumentReference<Map<String, dynamic>> get tax =>
      instance.collection('meta').doc('tax');
}

/// Maps a Firestore error to a friendly, non-revealing message.
String firestoreMessage(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return "You don't have permission for this action.";
      case 'unavailable':
        return 'Network unavailable. Check your connection and try again.';
      case 'not-found':
        return 'That record no longer exists.';
      case 'already-exists':
        return 'That record already exists.';
      case 'failed-precondition':
        return 'This action needs an index or a valid state. Try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
