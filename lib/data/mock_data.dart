/// Static option lists used by stock movement entry.
class MockData {
  const MockData._();

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
