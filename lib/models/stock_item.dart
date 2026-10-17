import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Units of measure offered by every item form. Client wants only "Unit" —
/// Box / Panel / Nos etc. were removed on request.
const List<String> kUnits = [
  'Unit',
];

enum ItemCategory {
  solarPvModules('Solar PV Modules'),
  solarOnGridInverters('Solar ON Grid Inverters'),
  solarHybridInverters('Solar Hybrid Inverters'),
  homeUps('Home UPS'),
  acidBatteries('Acid Batteries'),
  lithiumBatteries('Lithium Batteries'),
  onlineUps('Online UPS'),
  pvcConduitPipes('PVC Conduit Pipes'),
  hdgiPipes('HDGI Pipes'),
  electricalGoods('Electrical Goods');

  const ItemCategory(this.label);
  final String label;

  static ItemCategory fromLabel(String label) => values.firstWhere(
        (c) => c.label == label,
        orElse: () => electricalGoods,
      );
}

/// Categories whose price is entered per watt-peak (₹/Wp) rather than per piece.
const Set<ItemCategory> kWpPricedCategories = {
  ItemCategory.solarPvModules,
};

extension ItemCategoryUi on ItemCategory {
  bool get pricedPerWp => kWpPricedCategories.contains(this);

  IconData get icon => switch (this) {
        ItemCategory.solarPvModules => Icons.solar_power_rounded,
        ItemCategory.solarOnGridInverters => Icons.electrical_services_rounded,
        ItemCategory.solarHybridInverters => Icons.bolt_rounded,
        ItemCategory.homeUps => Icons.power_rounded,
        ItemCategory.acidBatteries => Icons.battery_full_rounded,
        ItemCategory.lithiumBatteries => Icons.battery_charging_full_rounded,
        ItemCategory.onlineUps => Icons.settings_input_component_rounded,
        ItemCategory.pvcConduitPipes => Icons.plumbing_rounded,
        ItemCategory.hdgiPipes => Icons.straighten_rounded,
        ItemCategory.electricalGoods => Icons.handyman_rounded,
      };

  /// Default placeholder icon for a category (used by instant item add).
  String get glyphKey => switch (this) {
        ItemCategory.solarPvModules => 'panel',
        ItemCategory.solarOnGridInverters => 'inverter',
        ItemCategory.solarHybridInverters => 'inverter',
        ItemCategory.homeUps => 'ups',
        ItemCategory.acidBatteries => 'battery',
        ItemCategory.lithiumBatteries => 'battery',
        ItemCategory.onlineUps => 'ups',
        ItemCategory.pvcConduitPipes => 'pipe',
        ItemCategory.hdgiPipes => 'pipe',
        ItemCategory.electricalGoods => 'tool',
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
  final ItemCategory category;
  final String sku;
  final String unit;
  final int quantity;
  final int reorderLevel;
  final double purchasePrice;
  final double sellingPrice;

  /// Watt-peak rating for solar modules (0 for other categories). When the
  /// category is priced per Wp, purchasePrice/sellingPrice hold the rate per Wp.
  final int wattPeak;
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
        'wattPeak': wattPeak,
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
          orElse: () => ItemCategory.electricalGoods,
        ),
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

  bool get isOutOfStock => quantity <= 0;
  /// At or below the reorder level the item is flagged for replenishment.
  bool get isLowStock => !isOutOfStock && quantity <= reorderLevel;

  bool get needsAttention => quantity <= reorderLevel;

  /// Panels are priced per watt-peak; everything else per unit.
  bool get isSolarModule => category.pricedPerWp;

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
    ItemCategory? category,
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
      category: category ?? this.category,
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
