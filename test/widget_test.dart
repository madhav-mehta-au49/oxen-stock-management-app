import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxen_solar_stock/core/utils/result.dart';
import 'package:oxen_solar_stock/data/mock_data.dart';
import 'package:oxen_solar_stock/models/challan.dart';
import 'package:oxen_solar_stock/models/company_profile.dart';
import 'package:oxen_solar_stock/models/stock_item.dart';
import 'package:oxen_solar_stock/models/stock_transaction.dart';
import 'package:oxen_solar_stock/services/auth_service.dart';
import 'package:oxen_solar_stock/services/challan_pdf_service.dart';

StockItem _item({
  String id = 'ITM-001',
  String name = 'Panel 330W',
  ItemCategory category = ItemCategory.panels,
  int quantity = 10,
  int reorderLevel = 4,
  double purchasePrice = 100,
  double sellingPrice = 120,
}) =>
    StockItem(
      id: id,
      name: name,
      category: category,
      sku: 'OX-TEST',
      unit: 'Unit',
      quantity: quantity,
      reorderLevel: reorderLevel,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      supplier: 'Sup',
      glyphKey: 'panel',
      createdAt: DateTime.now(),
    );

Challan _challan({ChallanFormat format = ChallanFormat.letterhead}) => Challan(
      id: 'OX-CH-2026-0001',
      number: 'OX/CH/2026/0001',
      customerName: 'Greenfield Estates',
      siteName: 'Block C',
      address: 'Sector 21',
      contact: '9001122334',
      date: DateTime(2026, 10, 1),
      status: ChallanStatus.issued,
      format: format,
      lines: const [
        ChallanLine(
          itemId: 'ITM-001',
          itemName: 'Panel 330W',
          sku: 'OX-PAN-330M',
          unit: 'Unit',
          quantity: 12,
          rate: 9750,
          availableBefore: 148,
        ),
        ChallanLine(
          itemId: 'ITM-012',
          itemName: 'GI Mounting Structure',
          sku: 'OX-MNT-GI1',
          unit: 'Set',
          quantity: 4,
          rate: 4200,
          availableBefore: 41,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mock dataset seeds items, ledger and challans', () {
    final items = MockData.items();
    expect(items.length, greaterThan(10));
    expect(items.any((i) => i.needsAttention), isTrue);

    final txns = MockData.transactions(items);
    expect(txns, isNotEmpty);

    for (final item in items) {
      final own = txns.where((t) => t.itemId == item.id).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (own.isEmpty) continue;
      expect(own.first.balanceAfter, item.quantity, reason: item.name);
    }
  });

  test('Result flag and category mapping', () {
    expect(Result.success('ok').ok, isTrue);
    expect(Result.failure('bad').ok, isFalse);
    expect(ItemCategory.fromLabel('Batteries'), ItemCategory.batteries);
  });

  test('stock status helpers', () {
    expect(_item(quantity: 0, reorderLevel: 4).isOutOfStock, isTrue);
    expect(_item(quantity: 3, reorderLevel: 4).isLowStock, isTrue);
    expect(_item(quantity: 10, reorderLevel: 4).needsAttention, isFalse);
    expect(_item(quantity: 10, purchasePrice: 100).stockValue, 1000);
    expect(_item(purchasePrice: 80, sellingPrice: 100).margin, 20);
  });

  test('transaction signed labels', () {
    StockTransaction make(TxnType type, int qty) => StockTransaction(
          id: 'T',
          itemId: 'I',
          itemName: 'N',
          itemSku: 'S',
          type: type,
          quantity: qty,
          balanceAfter: 5,
          date: DateTime.now(),
          party: 'P',
          reference: 'R',
          notes: '',
          user: 'U',
        );
    expect(make(TxnType.stockIn, 5).signedLabel, '+5');
    expect(make(TxnType.stockOut, 3).signedLabel, '−3');
    expect(make(TxnType.adjustment, -2).signedLabel, '−2');
  });

  test('item serialization round-trips through a Firestore map', () {
    final item = _item(quantity: 42, category: ItemCategory.batteries);
    final back = StockItem.fromMap('ITM-042', item.toMap());
    expect(back.id, 'ITM-042');
    expect(back.name, item.name);
    expect(back.category, ItemCategory.batteries);
    expect(back.quantity, 42);
    expect(back.purchasePrice, item.purchasePrice);
    expect(
      back.createdAt.millisecondsSinceEpoch,
      item.createdAt.millisecondsSinceEpoch,
    );
  });

  test('challan totals and serialization round-trip', () {
    final challan = _challan();
    expect(challan.totalUnits, 16);
    expect(challan.totalValue, 12 * 9750 + 4 * 4200);

    final back = Challan.fromMap(challan.id, challan.toMap());
    expect(back.number, challan.number);
    expect(back.customerName, challan.customerName);
    expect(back.status, ChallanStatus.issued);
    expect(back.format, ChallanFormat.letterhead);
    expect(back.lines.length, 2);
    expect(back.lines.first.itemName, 'Panel 330W');
    expect(back.totalUnits, challan.totalUnits);
    expect(back.date.year, 2026);
  });

  test('PDF is generated for both formats', () async {
    expect(
      await ChallanPdfService.build(_challan(), CompanyProfile.fallback),
      isNotEmpty,
    );
    expect(
      await ChallanPdfService.build(
        _challan(format: ChallanFormat.plain),
        CompanyProfile.fallback,
      ),
      isNotEmpty,
    );
  });

  test('auth errors map to friendly, non-revealing messages', () {
    expect(
      AuthService.messageFor(FirebaseAuthException(code: 'wrong-password')),
      'Email or password is incorrect.',
    );
    expect(
      AuthService.messageFor(FirebaseAuthException(code: 'user-not-found')),
      'Email or password is incorrect.',
    );
    expect(
      AuthService.messageFor(FirebaseAuthException(code: 'invalid-email')),
      'That email address is not valid.',
    );
    expect(
      AuthService.messageFor(Exception('boom')),
      'Something went wrong. Please try again.',
    );
  });
}
