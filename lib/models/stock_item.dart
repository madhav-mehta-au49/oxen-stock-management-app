import 'package:cloud_firestore/cloud_firestore.dart';

import 'category.dart';

/// Every item is counted in "Unit" (client request). Other units were removed.
const List<String> kUnits = ['Unit'];

/// An inventory item. Category is referenced by id (dynamic categories live in
/// the `categories` collection); [categoryName] is denormalised for display.
class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.sku,
    required this.unit,
    required this.quantity,
    required this.reorderLevel,
    required this.purchasePrice,
    required this.sellingPrice,
    this.wattPeak = 0,
    required this.supplier,
    required this.glyphKey,
    this.rack = '',
    this.unitNos = '',
    this.imageThumb = '',
    required this.createdAt,
  });

  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final String sku;
  final String unit;
  final int quantity;
  final int reorderLevel;

  /// Price per unit. When [wattPeak] > 0 this holds the rate **per Wp** (₹/Wp).
  final double purchasePrice;
  final double sellingPrice;

  /// Watt-peak rating for solar modules (0 for other categories).
  final int wattPeak;
  final String supplier;
  final String glyphKey;
  final String rack;
  final String unitNos;
  final String imageThumb;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'sku': sku,
        'unit': unit,
        'quantity': quantity,
        'reorderLevel': reorderLevel,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'wattPeak': wattPeak,
        'supplier': supplier,
        'glyphKey': glyphKey,
        'rack': rack,
        'unitNos': unitNos,
        'imageThumb': imageThumb,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory StockItem.fromMap(String id, Map<String, dynamic> data) {
    final rawId = data['categoryId'] as String? ?? '';
    final rawName = data['categoryName'] as String? ?? '';
    final legacy = data['category'] as String? ?? '';
    // Legacy items only had an enum `category`; show a humanised label until the
    // repair maps it to a real category in Firestore.
    final categoryName = rawName.isNotEmpty
        ? rawName
        : (rawId.isEmpty ? Category.humanize(legacy) : rawName);

    return StockItem(
      id: id,
      name: data['name'] as String? ?? '',
      categoryId: rawId,
      categoryName: categoryName,
      sku: data['sku'] as String? ?? '',
      unit: data['unit'] as String? ?? 'Unit',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      reorderLevel: (data['reorderLevel'] as num?)?.toInt() ?? 0,
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
      wattPeak: (data['wattPeak'] as num?)?.toInt() ?? 0,
      supplier: data['supplier'] as String? ?? '',
      glyphKey: data['glyphKey'] as String? ?? 'box',
      rack: data['rack'] as String? ?? '',
      unitNos: data['unitNos'] as String? ?? '',
      imageThumb: data['imageThumb'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isOutOfStock => quantity <= 0;

  /// At or below the reorder level the item is flagged for replenishment.
  bool get isLowStock => !isOutOfStock && quantity <= reorderLevel;

  bool get needsAttention => quantity <= reorderLevel;

  /// Items with a watt-peak are priced per Wp (₹/Wp).
  bool get isSolarModule => wattPeak > 0;

  /// Price for one piece (panels: Wp × ₹/Wp; others: the entered price).
  double get unitPurchasePrice =>
      isSolarModule ? wattPeak * purchasePrice : purchasePrice;

  double get unitSellingPrice =>
      isSolarModule ? wattPeak * sellingPrice : sellingPrice;

  double get stockValue => quantity * unitPurchasePrice;

  double get margin => unitSellingPrice <= 0
      ? 0
      : ((unitSellingPrice - unitPurchasePrice) / unitSellingPrice) * 100;

  StockItem copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? categoryName,
    String? sku,
    String? unit,
    int? quantity,
    int? reorderLevel,
    double? purchasePrice,
    double? sellingPrice,
    int? wattPeak,
    String? supplier,
    String? glyphKey,
    String? rack,
    String? unitNos,
    String? imageThumb,
    DateTime? createdAt,
  }) {
    return StockItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      wattPeak: wattPeak ?? this.wattPeak,
      supplier: supplier ?? this.supplier,
      glyphKey: glyphKey ?? this.glyphKey,
      rack: rack ?? this.rack,
      unitNos: unitNos ?? this.unitNos,
      imageThumb: imageThumb ?? this.imageThumb,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
