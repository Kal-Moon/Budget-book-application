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

/// id → 카테고리(지출·수입 모두).
final categoryMapProvider = StreamProvider<Map<int, Category>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchAllCategories()
      .map((list) => {for (final c in list) c.id: c}),
);

final allEntriesProvider = StreamProvider<List<Entry>>(
  (ref) => ref.watch(databaseProvider).watchAllEntries(),
);

final allBudgetsProvider = StreamProvider<Map<String, MonthBudget>>(
  (ref) => ref.watch(databaseProvider).watchAllBudgets(),
);
