import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/budget.dart';
import '../domain/categories.dart';
import 'default_categories.dart';

part 'database.g.dart';

/// 지출·수입 카테고리.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get kind => intEnum<EntryKind>()();
  TextColumn get name => text().withLength(min: 1, max: 8)();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// 지출·수입 내역.
@DataClassName('Entry')
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get kind => intEnum<EntryKind>()();

  /// 'YYYY-MM-DD'
  TextColumn get date => text().withLength(min: 10, max: 10)();

  /// 'HH:mm'
  TextColumn get time => text().withLength(min: 5, max: 5)();
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// 원 단위 양수 정수.
  IntColumn get amount => integer()();

  /// 구매처(지출만 사용).
  TextColumn get place => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get memo => text().withDefault(const Constant(''))();
}

/// 달별 예산의 방식과 총액. 예산이 없는 달은 행이 없다.
@DataClassName('MonthBudgetRow')
class MonthBudgets extends Table {
  /// 'YYYY-MM'
  TextColumn get monthKey => text().withLength(min: 7, max: 7)();
  IntColumn get mode => intEnum<BudgetMode>()();
  IntColumn get total => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {monthKey};
}

/// 항목별 방식인 달의 카테고리 예산.
@DataClassName('MonthCategoryBudgetRow')
class MonthCategoryBudgets extends Table {
  TextColumn get monthKey => text().withLength(min: 7, max: 7)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amount => integer()();

  @override
  Set<Column> get primaryKey => {monthKey, categoryId};
}

@DriftDatabase(
  tables: [Categories, Entries, MonthBudgets, MonthCategoryBudgets],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'gagyebu'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _insertDefaultCategories();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// 기본 카테고리는 처음 설치할 때와 초기화할 때만 넣는다.
  /// 이후에는 DB에 있는 그대로 보여준다(빈 목록을 "데이터 없음"으로 착각하지 않기).
  Future<void> _insertDefaultCategories() async {
    await batch((b) {
      for (final (i, c) in defaultCategories.indexed) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            kind: c.kind,
            name: c.name,
            icon: c.icon,
            color: c.color,
            sortOrder: Value(i),
          ),
        );
      }
    });
  }

  /// 내 기록(내역·카테고리·예산)을 통째로 비우고 기본 카테고리를 다시 넣는다.
  /// 테이블을 하나씩 나열하지 않아서, 테이블이 추가돼도 자동으로 포함된다.
  Future<void> clearRecords() => transaction(() async {
    await customStatement('PRAGMA defer_foreign_keys = ON');
    for (final table in allTables.toList().reversed) {
      await delete(table).go();
    }
    await _insertDefaultCategories();
  });

  Stream<List<Category>> watchCategories(EntryKind kind) =>
      (select(categories)
            ..where((c) => c.kind.equalsValue(kind))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();

  /// 한 달의 내역. 날짜·시간 최신순.
  Stream<List<Entry>> watchMonthEntries(String monthKey) =>
      (select(entries)
            ..where((e) => e.date.like('$monthKey-%'))
            ..orderBy([
              (e) => OrderingTerm.desc(e.date),
              (e) => OrderingTerm.desc(e.time),
            ]))
          .watch();

  /// 한 달의 예산. 정한 적이 없으면 0원 예산.
  /// 두 예산 테이블 중 어느 쪽이 바뀌어도 다시 읽는다.
  Stream<MonthBudget> watchMonthBudget(String monthKey) => customSelect(
    'SELECT 1',
    readsFrom: {monthBudgets, monthCategoryBudgets},
  ).watch().asyncMap((_) => getMonthBudget(monthKey));

  Future<MonthBudget> getMonthBudget(String monthKey) async {
    final row = await (select(
      monthBudgets,
    )..where((b) => b.monthKey.equals(monthKey))).getSingleOrNull();
    if (row == null) return MonthBudget.empty(monthKey);
    final cats = await (select(
      monthCategoryBudgets,
    )..where((b) => b.monthKey.equals(monthKey))).get();
    return MonthBudget(
      monthKey: monthKey,
      mode: row.mode,
      total: row.total,
      categoryAmounts: {for (final c in cats) c.categoryId: c.amount},
    );
  }

  /// 온보딩 결과 저장: 지출 카테고리를 편집한 목록대로 맞추고 이번 달 예산을 저장한다.
  /// [drafts]에 없는 기존 지출 카테고리는 지우고, id가 없는 것은 새로 만든다.
  /// [categoryAmounts]는 drafts의 순서(index) → 금액. [mode]가 null이면 예산은 저장하지 않는다(0원).
  Future<void> saveOnboarding({
    required List<CategoryDraft> drafts,
    required String monthKey,
    BudgetMode? mode,
    int total = 0,
    Map<int, int> categoryAmounts = const {},
  }) => transaction(() async {
    final keep = drafts.map((d) => d.id).whereType<int>().toSet();
    await (delete(categories)..where(
          (c) => c.kind.equalsValue(EntryKind.expense) & c.id.isNotIn(keep),
        ))
        .go();
    final ids = <int>[];
    for (final (i, d) in drafts.indexed) {
      final row = CategoriesCompanion(
        kind: const Value(EntryKind.expense),
        name: Value(d.name.trim()),
        icon: Value(d.icon),
        color: Value(d.color),
        sortOrder: Value(i),
      );
      if (d.id case final id?) {
        await (update(categories)..where((c) => c.id.equals(id))).write(row);
        ids.add(id);
      } else {
        ids.add(await into(categories).insert(row));
      }
    }
    if (mode != null) {
      await saveMonthBudget(
        MonthBudget(
          monthKey: monthKey,
          mode: mode,
          total: total,
          categoryAmounts: {
            for (final MapEntry(key: i, value: amount)
                in categoryAmounts.entries)
              if (i < ids.length) ids[i]: amount,
          },
        ),
      );
    }
  });

  /// 한 달의 예산을 통째로 저장한다(설정에서 이번 달 예산을 바꿀 때).
  Future<void> saveMonthBudget(MonthBudget budget) => transaction(() async {
    await into(monthBudgets).insertOnConflictUpdate(
      MonthBudgetsCompanion.insert(
        monthKey: budget.monthKey,
        mode: budget.mode,
        total: Value(budget.total),
      ),
    );
    await (delete(
      monthCategoryBudgets,
    )..where((b) => b.monthKey.equals(budget.monthKey))).go();
    if (budget.mode == BudgetMode.category) {
      await batch((b) {
        for (final MapEntry(key: id, value: amount)
            in budget.categoryAmounts.entries) {
          b.insert(
            monthCategoryBudgets,
            MonthCategoryBudgetsCompanion.insert(
              monthKey: budget.monthKey,
              categoryId: id,
              amount: amount,
            ),
          );
        }
      });
    }
  });
}
