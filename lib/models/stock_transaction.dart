import 'package:cloud_firestore/cloud_firestore.dart';

enum TxnType {
  stockIn('Stock In'),
  stockOut('Stock Out'),
  challanOut('Challan Out'),
  adjustment('Adjustment');

  const TxnType(this.label);
  final String label;

  bool get isIn => this == TxnType.stockIn;
  bool get isOut => this == TxnType.stockOut || this == TxnType.challanOut;
}

class StockTransaction {
  const StockTransaction({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemSku,
    required this.type,
    required this.quantity,
    required this.balanceAfter,
    required this.date,
    required this.party,
    required this.reference,
    required this.notes,
    required this.user,
  });

  final String id;
  final String itemId;
  final String itemName;
  final String itemSku;
  final TxnType type;
  final int quantity;
  final int balanceAfter;
  final DateTime date;
  final String party;
  final String reference;
  final String notes;
  final String user;

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'itemName': itemName,
        'itemSku': itemSku,
        'type': type.name,
        'quantity': quantity,
        'balanceAfter': balanceAfter,
        'date': Timestamp.fromDate(date),
        'party': party,
        'reference': reference,
        'notes': notes,
        'user': user,
      };

  factory StockTransaction.fromMap(String id, Map<String, dynamic> data) =>
      StockTransaction(
        id: id,
        itemId: data['itemId'] as String? ?? '',
        itemName: data['itemName'] as String? ?? '',
        itemSku: data['itemSku'] as String? ?? '',
        type: TxnType.values.firstWhere(
          (t) => t.name == data['type'],
          orElse: () => TxnType.adjustment,
        ),
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
        balanceAfter: (data['balanceAfter'] as num?)?.toInt() ?? 0,
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        party: data['party'] as String? ?? '',
        reference: data['reference'] as String? ?? '',
        notes: data['notes'] as String? ?? '',
        user: data['user'] as String? ?? '',
      );

  /// Adjustments store a signed quantity, every other type stores a magnitude.
  bool get isIn =>
      type == TxnType.stockIn || (type == TxnType.adjustment && quantity > 0);

  bool get isOut => type == TxnType.stockOut || type == TxnType.challanOut;

  int get signedQuantity =>
      type == TxnType.adjustment ? quantity : (isIn ? quantity : -quantity);

  /// "+5" / "-3" label used by the ledger rows.
  String get signedLabel {
    final value = signedQuantity;
    return value >= 0 ? '+$value' : '−${value.abs()}';
  }

  StockTransaction copyWith({
    int? balanceAfter,
    DateTime? date,
    String? itemName,
    String? itemSku,
  }) {
    return StockTransaction(
      id: id,
      itemId: itemId,
      itemName: itemName ?? this.itemName,
      itemSku: itemSku ?? this.itemSku,
      type: type,
      quantity: quantity,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      date: date ?? this.date,
      party: party,
      reference: reference,
      notes: notes,
      user: user,
    );
  }
}
