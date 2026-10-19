/// A stock category. GST is stored **on the category** (merged) and managed in
/// Settings. Items reference categories by [id].
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.gstRate,
    required this.iconKey,
    required this.pricedPerWp,
    required this.sortOrder,
  });

  final String id;
  final String name;

  /// Single GST % applied to items in this category (0 until configured).
  final double gstRate;

  /// Key into `ItemGlyph.all` (icon for the category).
  final String iconKey;

  /// Solar modules are priced per watt-peak (₹/Wp).
  final bool pricedPerWp;

  final int sortOrder;

  Map<String, dynamic> toMap() => {
    'name': name,
    'gstRate': gstRate,
    'iconKey': iconKey,
    'pricedPerWp': pricedPerWp,
    'sortOrder': sortOrder,
  };

  factory Category.fromMap(String id, Map<String, dynamic> data) => Category(
    id: id,
    name: data['name'] as String? ?? '',
    gstRate: (data['gstRate'] as num?)?.toDouble() ?? 0,
    iconKey: data['iconKey'] as String? ?? 'box',
    pricedPerWp: data['pricedPerWp'] as bool? ?? false,
    sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
  );

  Category copyWith({
    String? name,
    double? gstRate,
    String? iconKey,
    bool? pricedPerWp,
    int? sortOrder,
  }) => Category(
    id: id,
    name: name ?? this.name,
    gstRate: gstRate ?? this.gstRate,
    iconKey: iconKey ?? this.iconKey,
    pricedPerWp: pricedPerWp ?? this.pricedPerWp,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  /// Humanises a legacy enum value such as `solarPvModules` -> "Solar Pv
  /// Modules". Used only as a display fallback until the repair maps it to a
  /// real category from Firestore.
  static String humanize(String raw) {
    if (raw.trim().isEmpty) return '';
    final spaced = raw.replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])([A-Z])'),
      (m) => ' ${m[1]}',
    );
    final words = spaced.replaceAll('_', ' ').split(RegExp(r'\s+'));
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ')
        .trim();
  }

  /// Normalised form used to match a legacy value to a category name.
  static String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// The ten client categories, seeded on first run (GST per client's rates).
  static const List<Category> defaults = [
    Category(
      id: 'solar_pv_modules',
      name: 'Solar PV Modules',
      gstRate: 5,
      iconKey: 'panel',
      pricedPerWp: true,
      sortOrder: 0,
    ),
    Category(
      id: 'solar_on_grid_inverters',
      name: 'Solar ON Grid Inverters',
      gstRate: 5,
      iconKey: 'inverter',
      pricedPerWp: false,
      sortOrder: 1,
    ),
    Category(
      id: 'solar_hybrid_inverters',
      name: 'Solar Hybrid Inverters',
      gstRate: 5,
      iconKey: 'inverter',
      pricedPerWp: false,
      sortOrder: 2,
    ),
    Category(
      id: 'home_ups',
      name: 'Home UPS',
      gstRate: 18,
      iconKey: 'ups',
      pricedPerWp: false,
      sortOrder: 3,
    ),
    Category(
      id: 'acid_batteries',
      name: 'Acid Batteries',
      gstRate: 18,
      iconKey: 'battery',
      pricedPerWp: false,
      sortOrder: 4,
    ),
    Category(
      id: 'lithium_batteries',
      name: 'Lithium Batteries',
      gstRate: 18,
      iconKey: 'battery',
      pricedPerWp: false,
      sortOrder: 5,
    ),
    Category(
      id: 'online_ups',
      name: 'Online UPS',
      gstRate: 18,
      iconKey: 'ups',
      pricedPerWp: false,
      sortOrder: 6,
    ),
    Category(
      id: 'pvc_conduit_pipes',
      name: 'PVC Conduit Pipes',
      gstRate: 18,
      iconKey: 'pipe',
      pricedPerWp: false,
      sortOrder: 7,
    ),
    Category(
      id: 'hdgi_pipes',
      name: 'HDGI Pipes',
      gstRate: 18,
      iconKey: 'pipe',
      pricedPerWp: false,
      sortOrder: 8,
    ),
    Category(
      id: 'electrical_goods',
      name: 'Electrical Goods',
      gstRate: 18,
      iconKey: 'tool',
      pricedPerWp: false,
      sortOrder: 9,
    ),
  ];
}
