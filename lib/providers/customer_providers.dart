import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/customer_repository.dart';
import '../models/customer.dart';

/// Live list of saved customers.
final customersProvider = StreamProvider<List<Customer>>(
  (ref) => const CustomerRepository().watchAll(),
);
