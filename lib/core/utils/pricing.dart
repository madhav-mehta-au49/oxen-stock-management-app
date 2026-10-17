/// Line pricing with a single GST rate.
class LinePricing {
  const LinePricing({
    required this.taxable,
    required this.gstRate,
    required this.gstAmount,
    required this.total,
  });

  /// Value excl. GST (qty × unit price).
  final double taxable;
  final double gstRate;
  final double gstAmount;

  /// Taxable + GST.
  final double total;
}

/// Computes taxable value, GST and total for one line.
LinePricing priceLine({
  required double unitPrice,
  required int quantity,
  required double gstRate,
}) {
  final taxable = unitPrice * quantity;
  final gst = taxable * gstRate / 100;
  return LinePricing(
    taxable: taxable,
    gstRate: gstRate,
    gstAmount: gst,
    total: taxable + gst,
  );
}
