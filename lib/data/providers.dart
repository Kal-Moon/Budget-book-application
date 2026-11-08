import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/budget.dart';
import 'database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final categoriesProvider = StreamProvider.family<List<Category>, EntryKind>(
  (ref, kind) => ref.watch(databaseProvider).watchCategories(kind),
);

final monthEntriesProvider = StreamProvider.family<List<Entry>, String>(
  (ref, monthKey) => ref.watch(databaseProvider).watchMonthEntries(monthKey),
);

final monthBudgetProvider = StreamProvider.family<MonthBudget, String>(
  (ref, monthKey) => ref.watch(databaseProvider).watchMonthBudget(monthKey),
);
