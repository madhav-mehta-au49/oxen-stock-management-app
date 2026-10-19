import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/category_repository.dart';
import '../models/category.dart';

/// Live category list (ordered).
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => const CategoryRepository().watchAll(),
);

Category? categoryById(List<Category> categories, String id) {
  for (final c in categories) {
    if (c.id == id) return c;
  }
  return null;
}
