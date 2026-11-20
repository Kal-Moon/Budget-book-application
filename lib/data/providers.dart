import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/today.dart';
import '../domain/budget.dart';
import '../domain/period.dart';
import 'database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final categoriesProvider = StreamProvider.family<List<Category>, EntryKind>(
  (ref, kind) => ref.watch(databaseProvider).watchCategories(kind),
);

/// 날짜 범위(양 끝 포함)의 내역.
final rangeEntriesProvider = StreamProvider.family<List<Entry>, DateRange>(
  (ref, range) =>
      ref.watch(databaseProvider).watchEntriesBetween(range.start, range.end),
);

/// 한 달(기간)의 내역. 기간은 세부 설정의 한 달 시작일을 따른다.
final monthEntriesProvider = StreamProvider.family<List<Entry>, String>((
  ref,
  monthKey,
) {
  final range = ref.watch(periodCalendarProvider).rangeOf(monthKey);
  return ref
      .watch(databaseProvider)
      .watchEntriesBetween(range.start, range.end);
});

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
