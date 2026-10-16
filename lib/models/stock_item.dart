import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Units of measure offered by every item form. Client wants only "Unit" —
/// Box / Panel / Nos etc. were removed on request.
const List<String> kUnits = [
  'Unit',
];

enum ItemCategory {
  panels('Solar Panels'),
  inverters('Inverters'),
  batteries('Batteries'),
  cables('Cables & Wires'),
  mounts('Mounting'),
  lighting('Lighting'),
  accessories('Accessories');

  const ItemCategory(this.label);
  final String label;

  static ItemCategory fromLabel(String label) => values.firstWhere(
        (c) => c.label == label,
        orElse: () => accessories,
      );
}

extension ItemCategoryUi on ItemCategory {
  IconData get icon => switch (this) {
        ItemCategory.panels => Icons.solar_power_rounded,
        ItemCategory.inverters => Icons.bolt_rounded,
        ItemCategory.batteries => Icons.battery_charging_full_rounded,
        ItemCategory.cables => Icons.cable_rounded,
        ItemCategory.mounts => Icons.hardware_rounded,
        ItemCategory.lighting => Icons.lightbulb_outline_rounded,
        ItemCategory.accessories => Icons.handyman_rounded,
      };

  /// Default placeholder icon for a category (used by instant item add).
  String get glyphKey => switch (this) {
        ItemCategory.panels => 'panel',
        ItemCategory.inverters => 'inverter',
        ItemCategory.batteries => 'battery',
        ItemCategory.cables => 'cable',
        ItemCategory.mounts => 'structure',
        ItemCategory.lighting => 'light',
        ItemCategory.accessories => 'tool',
      };
}

class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.sku,
    required this.unit,
    required this.quantity,
    required this.reorderLevel,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.supplier,
    required this.glyphKey,
    this.rack = '',
    this.unitNos = '',
    this.imageThumb = '',
    required this.createdAt,
  });

  final String id;
  final String name;
  final ItemCategory category;
  final String sku;
  final String unit;
  final int quantity;
  final int reorderLevel;
  final double purchasePrice;
  final double sellingPrice;
  final String supplier;
  final String glyphKey;
  final String rack;

  /// Unit / serial numbers held for this item (free text, e.g. "UN-001 – UN-025").
  final String unitNos;

  /// Small base64 JPEG thumbnail shown in lists (empty = use the category icon).
  /// The full-size photo lives in the `itemImages/{id}` document.
  final String imageThumb;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category.name,
        'sku': sku,
        'unit': unit,
        'quantity': quantity,
        'reorderLevel': reorderLevel,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'supplier': supplier,
        'glyphKey': glyphKey,
        'rack': rack,
        'unitNos': unitNos,
        'imageThumb': imageThumb,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory StockItem.fromMap(String id, Map<String, dynamic> data) => StockItem(
        id: id,
        name: data['name'] as String? ?? '',
        category: ItemCategory.values.firstWhere(
          (c) => c.name == data['category'],
          orElse: () => ItemCategory.accessories,
        ),
        sku: data['sku'] as String? ?? '',
        unit: data['unit'] as String? ?? 'Unit',
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
        reorderLevel: (data['reorderLevel'] as num?)?.toInt() ?? 0,
        purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0,
        sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
        supplier: data['supplier'] as String? ?? '',
        glyphKey: data['glyphKey'] as String? ?? 'box',
        rack: data['rack'] as String? ?? '',
        unitNos: data['unitNos'] as String? ?? '',
        imageThumb: data['imageThumb'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  bool get isOutOfStock => quantity <= 0;
  /// At or below the reorder level the item is flagged for replenishment.
  bool get isLowStock => !isOutOfStock && quantity <= reorderLevel;

  bool get needsAttention => quantity <= reorderLevel;

  double get stockValue => quantity * purchasePrice;

  double get margin =>
      sellingPrice <= 0 ? 0 : ((sellingPrice - purchasePrice) / sellingPrice) * 100;

  StockItem copyWith({
    String? id,
    String? name,
    ItemCategory? category,
    String? sku,
    String? unit,
    int? quantity,
    int? reorderLevel,
    double? purchasePrice,
    double? sellingPrice,
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
      category: category ?? this.category,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      supplier: supplier ?? this.supplier,
      glyphKey: glyphKey ?? this.glyphKey,
      rack: rack ?? this.rack,
      unitNos: unitNos ?? this.unitNos,
      imageThumb: imageThumb ?? this.imageThumb,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
