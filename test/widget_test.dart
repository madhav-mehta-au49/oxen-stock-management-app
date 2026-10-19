import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxen_solar_stock/core/utils/result.dart';
import 'package:oxen_solar_stock/models/challan.dart';
import 'package:oxen_solar_stock/models/company_profile.dart';
import 'package:oxen_solar_stock/models/stock_item.dart';
import 'package:oxen_solar_stock/models/stock_transaction.dart';
import 'package:oxen_solar_stock/services/auth_service.dart';
import 'package:oxen_solar_stock/services/challan_pdf_service.dart';

StockItem _item({
  String id = 'ITM-001',
  String name = 'Panel 330W',
  String categoryId = 'electrical_goods',
  String categoryName = 'Electrical Goods',
  int quantity = 10,
  int reorderLevel = 4,
  double purchasePrice = 100,
  double sellingPrice = 120,
  int wattPeak = 0,
}) =>
    StockItem(
      id: id,
      name: name,
      categoryId: categoryId,
      categoryName: categoryName,
      sku: 'OX-TEST',
      unit: 'Unit',
      quantity: quantity,
      reorderLevel: reorderLevel,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      wattPeak: wattPeak,
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

  test('Result flag', () {
    expect(Result.success('ok').ok, isTrue);
    expect(Result.failure('bad').ok, isFalse);
  });

  test('stock status helpers', () {
    expect(_item(quantity: 0, reorderLevel: 4).isOutOfStock, isTrue);
    expect(_item(quantity: 3, reorderLevel: 4).isLowStock, isTrue);
    expect(_item(quantity: 10, reorderLevel: 4).needsAttention, isFalse);
    expect(_item(quantity: 10, purchasePrice: 100).stockValue, 1000);
    expect(_item(purchasePrice: 80, sellingPrice: 100).margin, 20);
  });

  test('panels are priced per Wp', () {
    final panel = _item(
      categoryId: 'solar_pv_modules',
      categoryName: 'Solar PV Modules',
      quantity: 10,
      purchasePrice: 20,
      sellingPrice: 25,
      wattPeak: 580,
    );
    expect(panel.unitPurchasePrice, 580 * 20);
    expect(panel.unitSellingPrice, 580 * 25);
    expect(panel.stockValue, 10 * 580 * 20);
  });

  test('delivery note GST totals and breakdown', () {
    final lines = [
      const ChallanLine(
        itemId: 'A',
        itemName: 'Panel',
        sku: 'A',
        unit: 'Unit',
        quantity: 2,
        rate: 14500,
        availableBefore: 10,
        gstRate: 12,
        gstAmount: 3480,
      ),
      const ChallanLine(
        itemId: 'B',
        itemName: 'Inverter',
        sku: 'B',
        unit: 'Unit',
        quantity: 1,
        rate: 30000,
        availableBefore: 5,
        gstRate: 18,
        gstAmount: 5400,
      ),
    ];
    final c = _challan().copyWith(lines: lines);
    expect(c.taxableValue, 59000);
    expect(c.gstValue, 8880);
    expect(c.grandTotal, 67880);
    expect(c.gstBreakdown[12], 3480);
    expect(c.gstBreakdown[18], 5400);
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
    final item = _item(
      quantity: 42,
      categoryId: 'acid_batteries',
      categoryName: 'Acid Batteries',
    );
    final back = StockItem.fromMap('ITM-042', item.toMap());
    expect(back.id, 'ITM-042');
    expect(back.name, item.name);
    expect(back.categoryId, 'acid_batteries');
    expect(back.categoryName, 'Acid Batteries');
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
