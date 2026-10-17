import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/tax_repository.dart';
import '../models/stock_item.dart';

/// Global GST rates keyed by category label (default 0 until configured).
final taxRatesProvider = StreamProvider<Map<String, double>>(
  (ref) => const TaxRepository().watchRates(),
);

double gstRateFor(Map<String, double> rates, ItemCategory category) =>
    rates[category.label] ?? 0;

class TaxController {
  const TaxController();

  Future<bool> save(Map<String, double> rates) async {
    final result = await const TaxRepository().saveRates(rates);
    return result.ok;
  }
}

final taxControllerProvider =
    Provider<TaxController>((ref) => const TaxController());
