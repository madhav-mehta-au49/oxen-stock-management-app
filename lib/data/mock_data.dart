import 'dart:math';

import '../models/challan.dart';
import '../models/stock_item.dart';
import '../models/stock_transaction.dart';

/// In-memory demo dataset. Everything here lives only for the UI phase —
/// swap this out for a repository/database later without touching the UI.
class MockData {
  const MockData._();

  static const String companyName = 'Oxen Energies';
  static const String companyTagline = 'Solar Equipment & EPC Supplies';
  static const String companyAddress = 'Hirji Mistry Road, Jamnagar';
  static const String companyPhone = '+91 88666 99444';
  static const String companyGstin = '08AAFCO1234K1ZP';

  static List<StockItem> items() {
    final now = DateTime.now();
    DateTime created(int daysAgo) =>
        DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));

    const raw = <(String, ItemCategory, String, String, int, int, double, double,
        String, String, String)>[
      (
        'Monocrystalline Solar Panel 330W',
        ItemCategory.panels,
        'OX-PAN-330M',
        'Panel',
        148,
        40,
        8200,
        9750,
        'SunRay Energies',
        'panel',
        'A-01'
      ),
      (
        'Polycrystalline Solar Panel 250W',
        ItemCategory.panels,
        'OX-PAN-250P',
        'Panel',
        26,
        30,
        5900,
        7100,
        'SunRay Energies',
        'panel',
        'A-02'
      ),
      (
        'Half-Cut PERC Solar Panel 440W',
        ItemCategory.panels,
        'OX-PAN-440H',
        'Panel',
        62,
        25,
        9800,
        11400,
        'HelioTech Solar',
        'panel',
        'A-03'
      ),
      (
        'Hybrid Inverter 3kW',
        ItemCategory.inverters,
        'OX-INV-3KH',
        'Unit',
        18,
        8,
        24500,
        28900,
        'VoltEdge Systems',
        'inverter',
        'B-01'
      ),
      (
        'Off-Grid Inverter 5kW',
        ItemCategory.inverters,
        'OX-INV-5KO',
        'Unit',
        6,
        6,
        38000,
        44500,
        'VoltEdge Systems',
        'inverter',
        'B-02'
      ),
      (
        'Grid-Tied Inverter 1kW',
        ItemCategory.inverters,
        'OX-INV-1KG',
        'Unit',
        0,
        5,
        11500,
        13900,
        'VoltEdge Systems',
        'inverter',
        'B-03'
      ),
      (
        'Tubular Battery 150Ah / 12V',
        ItemCategory.batteries,
        'OX-BAT-150T',
        'Unit',
        34,
        12,
        14200,
        16800,
        'AmarPower',
        'battery',
        'C-01'
      ),
      (
        'LiFePO4 Battery 5kWh',
        ItemCategory.batteries,
        'OX-BAT-LFP5',
        'Unit',
        9,
        10,
        62000,
        71500,
        'AmarPower',
        'battery',
        'C-02'
      ),
      (
        'DC Solar Cable 4mm² (100m Roll)',
        ItemCategory.cables,
        'OX-CBL-DC4',
        'Roll',
        74,
        20,
        2450,
        3100,
        'WireNet Traders',
        'cable',
        'D-01'
      ),
      (
        'AC Cable 2.5mm² (90m Roll)',
        ItemCategory.cables,
        'OX-CBL-AC25',
        'Roll',
        12,
        15,
        1750,
        2300,
        'WireNet Traders',
        'cable',
        'D-02'
      ),
      (
        'MC4 Connector Pair',
        ItemCategory.accessories,
        'OX-CON-MC4',
        'Pair',
        540,
        150,
        90,
        150,
        'WireNet Traders',
        'tool',
        'D-03'
      ),
      (
        'GI Mounting Structure (Set)',
        ItemCategory.mounts,
        'OX-MNT-GI1',
        'Set',
        41,
        15,
        3400,
        4200,
        'SteelFab Industries',
        'structure',
        'E-01'
      ),
      (
        'Rooftop Panel Clamp',
        ItemCategory.mounts,
        'OX-MNT-CLP',
        'Piece',
        260,
        100,
        180,
        260,
        'SteelFab Industries',
        'structure',
        'E-02'
      ),
      (
        'Solar LED Street Light 30W',
        ItemCategory.lighting,
        'OX-LGT-30W',
        'Unit',
        5,
        8,
        3900,
        4800,
        'LumaSolar',
        'light',
        'F-01'
      ),
      (
        'IP65 Junction Box',
        ItemCategory.accessories,
        'OX-ACC-JB5',
        'Piece',
        120,
        50,
        320,
        450,
        'WireNet Traders',
        'box',
        'D-04'
      ),
      (
        'Earthing Kit (Chemical)',
        ItemCategory.accessories,
        'OX-ACC-ERT',
        'Kit',
        3,
        10,
        2100,
        2750,
        'SteelFab Industries',
        'tool',
        'E-03'
      ),
    ];

    var i = 0;
    return [
      for (final r in raw)
        StockItem(
          id: 'ITM-${(i + 1).toString().padLeft(3, '0')}',
          name: r.$1,
          category: r.$2,
          sku: r.$3,
          unit: r.$4,
          quantity: r.$5,
          reorderLevel: r.$6,
          purchasePrice: r.$7,
          sellingPrice: r.$8,
          supplier: r.$9,
          glyphKey: r.$10,
          rack: r.$11,
          createdAt: created(60 + (i++)),
        ),
    ];
  }

  static const List<String> _inSources = [
    'Purchase Receipt',
    'Stock Return',
    'Site Return',
    'Opening Balance',
    'Vendor Replacement',
  ];

  static const List<String> _outRefs = [
    'Sales Order',
    'Site Issue',
    'Workshop Use',
    'Damaged / Scrap',
    'Retail Counter',
  ];

  static const List<String> _parties = [
    'Greenfield Estates',
    'Apex Infra Projects',
    'Sunrise Agro Farms',
    'Oxen Workshop',
    'Retail Counter',
    'Nirvana Villas',
  ];

  static const List<String> _users = ['Store Team', 'R. Mehta', 'S. Sharma'];

  /// Builds a believable ledger for every item so the detail screen,
  /// dashboard feed and stock chart all have data to render.
  static List<StockTransaction> transactions(List<StockItem> items) {
    final rnd = Random(7331);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <StockTransaction>[];
    var seq = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final pending = <_Pending>[];
      var balance = item.quantity;

      final step = item.quantity > 200
          ? 60
          : item.quantity > 50
              ? 24
              : item.quantity > 10
                  ? 6
                  : 3;
      final count = 5 + rnd.nextInt(6);

      for (var k = 0; k < count; k++) {
        final isIn = rnd.nextBool();
        if (isIn) {
          if (balance < 1) continue;
          final cap = min(step, balance);
          final q = 1 + rnd.nextInt(cap);
          pending.add(_Pending(isIn: true, qty: q));
          balance -= q;
        } else {
          final q = 1 + rnd.nextInt(step);
          pending.add(_Pending(isIn: false, qty: q));
          balance += q;
        }
      }
      if (pending.isEmpty) continue;

      final opening = balance;
      final span = 32 + rnd.nextInt(24);
      final base = i.isEven ? 0 : 1;
      final chrono = pending.reversed.toList();

      var running = opening;
      for (var k = 0; k < chrono.length; k++) {
        final p = chrono[k];
        final progress = chrono.length == 1 ? 0 : k / (chrono.length - 1);
        // chrono[0] is the oldest event, so it sits furthest back in time.
        final offset = base + ((1 - progress) * span).round();
        final hour =
            offset == 0 ? min(max(now.hour, 8), 19) : 8 + rnd.nextInt(11);
        final date = today
            .subtract(Duration(days: offset))
            .add(Duration(hours: hour, minutes: rnd.nextInt(60)));

        running += p.isIn ? p.qty : -p.qty;

        final isIn = p.isIn;
        result.add(
          StockTransaction(
            id: 'TXN-${(++seq).toString().padLeft(4, '0')}',
            itemId: item.id,
            itemName: item.name,
            itemSku: item.sku,
            type: isIn ? TxnType.stockIn : TxnType.stockOut,
            quantity: p.qty,
            balanceAfter: running,
            date: date,
            party: isIn
                ? item.supplier
                : _parties[rnd.nextInt(_parties.length)],
            reference: isIn
                ? '${_inSources[rnd.nextInt(_inSources.length)]} • INV-${2000 + rnd.nextInt(900)}'
                : '${_outRefs[rnd.nextInt(_outRefs.length)]} • SO-${500 + rnd.nextInt(900)}',
            notes: isIn
                ? 'Received in good condition'
                : 'Issued against approved requisition',
            user: _users[rnd.nextInt(_users.length)],
          ),
        );
      }
    }

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  static List<Challan> challans(List<StockItem> items) {
    StockItem find(String sku) =>
        items.firstWhere((i) => i.sku == sku, orElse: () => items.first);
    final now = DateTime.now();

    ChallanLine line(String sku, int qty) {
      final it = find(sku);
      return ChallanLine(
        itemId: it.id,
        itemName: it.name,
        sku: it.sku,
        unit: it.unit,
        quantity: qty,
        rate: it.sellingPrice,
        availableBefore: it.quantity + qty,
      );
    }

    return [
      Challan(
        id: 'CH-0001',
        number: 'OX/CH/${now.year}/0001',
        customerName: 'Greenfield Estates',
        siteName: 'Villa Block-C Rooftop Plant',
        address: 'Sector 21, Mansarovar, Jaipur, Rajasthan 302020',
        contact: '+91 90011 22334',
        date: now.subtract(const Duration(days: 6)),
        status: ChallanStatus.issued,
        vehicleNo: 'RJ-14-GC-4471',
        notes: 'Material unloaded at site gate 2.',
        format: ChallanFormat.letterhead,
        lines: [
          line('OX-PAN-330M', 12),
          line('OX-MNT-GI1', 4),
          line('OX-CBL-DC4', 3),
        ],
      ),
      Challan(
        id: 'CH-0002',
        number: 'OX/CH/${now.year}/0002',
        customerName: 'Apex Infra Projects',
        siteName: 'Warehouse Roof – Phase 1',
        address: 'RIICO Industrial Area, Bhilwara, Rajasthan 311001',
        contact: '+91 98870 55120',
        date: now.subtract(const Duration(days: 2)),
        status: ChallanStatus.issued,
        vehicleNo: 'RJ-06-GB-9920',
        notes: 'Driver will collect signed copy.',
        lines: [
          line('OX-INV-3KH', 2),
          line('OX-BAT-150T', 6),
          line('OX-CON-MC4', 20),
        ],
      ),
    ];
  }

  static const List<String> customers = [
    'Greenfield Estates',
    'Apex Infra Projects',
    'Sunrise Agro Farms',
    'Nirvana Villas',
    'Rajputana Textiles',
    'Walk-in Customer',
  ];

  static const List<String> stockSources = [
    'Purchase Receipt',
    'Stock Return',
    'Site Return',
    'Vendor Replacement',
    'Opening Balance',
  ];

  static const List<String> stockOutParties = [
    'Sales Order',
    'Site Issue',
    'Workshop Use',
    'Retail Counter',
    'Damaged / Scrap',
  ];
}

class _Pending {
  _Pending({required this.isIn, required this.qty});

  final bool isIn;
  final int qty;
}
