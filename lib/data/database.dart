import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/budget.dart';
import '../domain/categories.dart';
import '../domain/fixed_expense.dart';
import '../domain/import.dart';
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

/// 고정 지출: 매달 정한 날에 지출 내역을 자동으로 넣는다(설정 > 고정 지출).
class FixedExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 내역 칸에 들어갈 이름(예: 월세).
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amount => integer()();

  /// 매달 며칠(1~31). 그 달에 없는 날이면 말일.
  IntColumn get day => integer()();
  TextColumn get place => text().withDefault(const Constant(''))();
  TextColumn get memo => text().withDefault(const Constant(''))();

  /// 다음에 입력할 날짜 'YYYY-MM-DD'. 입력할 때마다 다음 달로 넘어간다.
  TextColumn get nextDate => text().withLength(min: 10, max: 10)();

  /// 끄면 입력하지 않는다(다시 켜면 지난 달은 채우지 않는다).
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// 고정 지출이 내역을 넣을 때의 시간.
const fixedExpenseTime = '00:00';

@DriftDatabase(
  tables: [
    Categories,
    Entries,
    MonthBudgets,
    MonthCategoryBudgets,
    FixedExpenses,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'gagyebu'));

  @override
  /// 1: 처음 버전. 2: 영수증 기억 표 추가. 3: 영수증 입력을 빼면서 그 표를 지움.
  /// 4: 고정 지출 표 추가.
  /// (테스트 빌드를 쓰던 폰의 데이터를 지키려고 출시 전이지만 마이그레이션을 둔다.)
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _insertDefaultCategories();
    },
    onUpgrade: (m, from, to) async {
      // 영수증 입력을 뺐다(빌드 30). 2에서 만든 영수증 기억 표가 남아 있으면 지운다.
      if (from < 3) {
        await customStatement('DROP TABLE IF EXISTS receipt_memories');
      }
      if (from < 4) await m.createTable(fixedExpenses);
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

  /// 백업용: 모든 테이블의 모든 행을 테이블 이름 → 행 목록으로 돌려준다.
  /// 테이블을 나열하지 않아서, 테이블이 추가돼도 자동으로 포함된다.
  Future<Map<String, List<Map<String, Object?>>>> exportAllTables() =>
      transaction(() async {
        return {
          for (final table in allTables)
            table.actualTableName: [
              for (final row in await customSelect(
                'SELECT * FROM "${table.actualTableName}"',
                readsFrom: {table},
              ).get())
                row.data,
            ],
        };
      });

  /// 백업에서 복원: 지금 기록을 모두 지우고 [tables]의 행으로 바꾼다.
  /// 하나라도 잘못되면(형식 오류, 없는 카테고리를 가리키는 내역, 종류별 카테고리 0개)
  /// 전체를 되돌리고 [FormatException]을 던진다. 지금 데이터는 그대로 남는다.
  Future<void> replaceAllTables(
    Map<String, List<Map<String, Object?>>> tables,
  ) => transaction(() async {
    // 외래 키 검사는 커밋할 때 한 번에 한다(행을 넣는 순서와 무관하게).
    await customStatement('PRAGMA defer_foreign_keys = ON');
    for (final table in allTables.toList().reversed) {
      await delete(table).go();
    }
    for (final table in allTables) {
      for (final row in tables[table.actualTableName] ?? const []) {
        final Insertable<Object?> data;
        try {
          data = table.map(row) as Insertable<Object?>;
        } catch (_) {
          throw const FormatException('행을 읽을 수 없어요');
        }
        await into(table).insert(data);
      }
    }
    final broken = await customSelect('PRAGMA foreign_key_check').get();
    if (broken.isNotEmpty) {
      throw const FormatException('없는 카테고리를 가리키는 내역이 있어요');
    }
    for (final kind in EntryKind.values) {
      final any = await (select(
        categories,
      )..where((c) => c.kind.equalsValue(kind))).get();
      if (any.isEmpty) throw const FormatException('카테고리가 비어 있어요');
    }
  });

  Stream<List<Category>> watchCategories(EntryKind kind) =>
      (select(categories)
            ..where((c) => c.kind.equalsValue(kind))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();

  /// 지출·수입 카테고리 전부(id로 찾을 때).
  Stream<List<Category>> watchAllCategories() => (select(
    categories,
  )..orderBy([(c) => OrderingTerm(expression: c.sortOrder)])).watch();

  /// 모든 내역(전체 기간 검색용).
  Stream<List<Entry>> watchAllEntries() => select(entries).watch();

  /// 날짜 범위(양 끝 포함)의 내역. 날짜·시간 최신순.
  /// 한 달(기간)의 내역은 `PeriodCalendar.rangeOf`로 범위를 구해 읽는다.
  Stream<List<Entry>> watchEntriesBetween(String start, String end) =>
      (select(entries)
            ..where((e) => e.date.isBetweenValues(start, end))
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

  /// 예산을 정한 모든 달(월별 추이의 예산 선). 'YYYY-MM' → 예산.
  /// 달마다 따로 읽지 않고 두 테이블을 한 번씩만 읽는다.
  Stream<Map<String, MonthBudget>> watchAllBudgets() =>
      customSelect(
        'SELECT 1',
        readsFrom: {monthBudgets, monthCategoryBudgets},
      ).watch().asyncMap((_) async {
        final heads = await select(monthBudgets).get();
        final amounts = <String, Map<int, int>>{};
        for (final c in await select(monthCategoryBudgets).get()) {
          (amounts[c.monthKey] ??= {})[c.categoryId] = c.amount;
        }
        return {
          for (final h in heads)
            h.monthKey: MonthBudget(
              monthKey: h.monthKey,
              mode: h.mode,
              total: h.total,
              categoryAmounts: amounts[h.monthKey] ?? const {},
            ),
        };
      });

  /// [monthKey]보다 앞선 달 중 예산을 정한 가장 최근 달의 예산. 없으면 null.
  Future<MonthBudget?> latestBudgetBefore(String monthKey) async {
    final row =
        await (select(monthBudgets)
              ..where((b) => b.monthKey.isSmallerThanValue(monthKey))
              ..orderBy([(b) => OrderingTerm.desc(b.monthKey)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : getMonthBudget(row.monthKey);
  }

  /// 내역 저장. [id]가 있으면 수정, 없으면 새로 추가한다.
  Future<void> saveEntry(EntriesCompanion entry, {int? id}) async {
    if (id == null) {
      await into(entries).insert(entry);
    } else {
      await (update(entries)..where((e) => e.id.equals(id))).write(entry);
    }
  }

  /// 내역 하나만 다른 카테고리로 옮긴다(카테고리 내역 화면에서).
  Future<void> setEntryCategory(int entryId, int categoryId) =>
      (update(entries)..where((e) => e.id.equals(entryId))).write(
        EntriesCompanion(categoryId: Value(categoryId)),
      );

  Future<void> deleteEntry(int id) =>
      (delete(entries)..where((e) => e.id.equals(id))).go();

  /// 카테고리를 맨 뒤에 추가하고 id를 돌려준다. 이름 검사는 화면에서 먼저 한다.
  Future<int> addCategory({
    required EntryKind kind,
    required String name,
    required String icon,
    required int color,
  }) async {
    final last =
        await (select(categories)
              ..orderBy([(c) => OrderingTerm.desc(c.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    return into(categories).insert(
      CategoriesCompanion.insert(
        kind: kind,
        name: name.trim(),
        icon: icon,
        color: color,
        sortOrder: Value((last?.sortOrder ?? -1) + 1),
      ),
    );
  }

  /// 같은 종류의 카테고리 순서를 [ids] 순서대로 바꾼다.
  Future<void> reorderCategories(List<int> ids) => transaction(() async {
    for (final (i, id) in ids.indexed) {
      await (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(sortOrder: Value(i)),
      );
    }
  });

  Future<void> updateCategory(
    int id, {
    required String name,
    required String icon,
    required int color,
  }) => (update(categories)..where((c) => c.id.equals(id))).write(
    CategoriesCompanion(
      name: Value(name.trim()),
      icon: Value(icon),
      color: Value(color),
    ),
  );

  /// 카테고리에 속한 내역 수(삭제 전에 옮길지 물어볼 때).
  Future<int> countEntriesIn(int categoryId) async {
    final count = entries.id.count();
    final query = selectOnly(entries)
      ..addColumns([count])
      ..where(entries.categoryId.equals(categoryId));
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// 항목별 방식인 달의 카테고리 예산 하나를 바꾼다.
  Future<void> setCategoryBudget(String monthKey, int categoryId, int amount) =>
      into(monthCategoryBudgets).insertOnConflictUpdate(
        MonthCategoryBudgetsCompanion.insert(
          monthKey: monthKey,
          categoryId: categoryId,
          amount: amount,
        ),
      );

  /// 카테고리 삭제.
  /// [moveTo]가 있으면 내역과 **모든 달의 예산**을 그 카테고리로 옮긴다
  /// (예산을 그냥 지우면 예산을 지켰던 과거 달이 "초과"로 바뀐다).
  /// [moveTo]가 없으면 내역과 예산을 함께 지운다.
  Future<void> deleteCategory(int id, {int? moveTo}) => transaction(() async {
    final budgets = await (select(
      monthCategoryBudgets,
    )..where((b) => b.categoryId.equals(id))).get();
    if (moveTo != null) {
      await (update(entries)..where((e) => e.categoryId.equals(id))).write(
        EntriesCompanion(categoryId: Value(moveTo)),
      );
      await (update(fixedExpenses)..where((f) => f.categoryId.equals(id)))
          .write(FixedExpensesCompanion(categoryId: Value(moveTo)));
      for (final b in budgets) {
        final target =
            await (select(monthCategoryBudgets)..where(
                  (t) =>
                      t.monthKey.equals(b.monthKey) &
                      t.categoryId.equals(moveTo),
                ))
                .getSingleOrNull();
        await setCategoryBudget(
          b.monthKey,
          moveTo,
          (target?.amount ?? 0) + b.amount,
        );
      }
    } else {
      await (delete(entries)..where((e) => e.categoryId.equals(id))).go();
    }
    // 옮기지 않으면 그 카테고리의 고정 지출도 함께 지운다(이미 넣은 내역과 같은 처리).
    await (delete(fixedExpenses)..where((f) => f.categoryId.equals(id))).go();
    await (delete(
      monthCategoryBudgets,
    )..where((b) => b.categoryId.equals(id))).go();
    await (delete(categories)..where((c) => c.id.equals(id))).go();
  });

  Stream<List<FixedExpense>> watchFixedExpenses() =>
      (select(fixedExpenses)..orderBy([
            (f) => OrderingTerm(expression: f.day),
            (f) => OrderingTerm(expression: f.id),
          ]))
          .watch();

  /// 고정 지출을 추가하거나([id]가 null) 고친다. 다음 입력일은 [today] 기준으로 정한다:
  /// 새로 만들면 오늘 이후 처음 오는 그날, 고치거나 다시 켜면 이미 입력한 달은 건너뛴다.
  Future<void> saveFixedExpense({
    int? id,
    required String name,
    required int categoryId,
    required int amount,
    required int day,
    String place = '',
    String memo = '',
    bool active = true,
    required String today,
  }) => transaction(() async {
    final old = id == null
        ? null
        : await (select(
            fixedExpenses,
          )..where((f) => f.id.equals(id))).getSingleOrNull();
    final next = old == null
        ? firstFixedDateFrom(today, day)
        : resumeFixedDate(storedNext: old.nextDate, day: day, today: today);
    final row = FixedExpensesCompanion(
      name: Value(name.trim()),
      categoryId: Value(categoryId),
      amount: Value(amount),
      day: Value(day),
      place: Value(place.trim()),
      memo: Value(memo.trim()),
      active: Value(active),
      nextDate: Value(next),
    );
    if (old == null) {
      await into(fixedExpenses).insert(row);
    } else {
      await (update(fixedExpenses)..where((f) => f.id.equals(id!))).write(row);
    }
  });

  /// 켜고 끈다. 다시 켜면 지난 달은 채우지 않는다.
  Future<void> setFixedExpenseActive(
    int id,
    bool active, {
    required String today,
  }) => transaction(() async {
    final f = await (select(
      fixedExpenses,
    )..where((f) => f.id.equals(id))).getSingle();
    await (update(fixedExpenses)..where((f) => f.id.equals(id))).write(
      FixedExpensesCompanion(
        active: Value(active),
        nextDate: active
            ? Value(
                resumeFixedDate(
                  storedNext: f.nextDate,
                  day: f.day,
                  today: today,
                ),
              )
            : const Value.absent(),
      ),
    );
  });

  /// 고정 지출을 지운다. 이미 넣은 내역은 남는다.
  Future<void> deleteFixedExpense(int id) =>
      (delete(fixedExpenses)..where((f) => f.id.equals(id))).go();

  /// 입력할 날이 된(오늘까지) 고정 지출을 내역으로 넣고 넣은 건수를 돌려준다.
  /// 앱을 열 때와 날짜가 바뀔 때 부른다. 오래 안 열었으면 빠진 달도 넣는다.
  Future<int> applyFixedExpenses(String today) => transaction(() async {
    var count = 0;
    final due =
        await (select(fixedExpenses)..where(
              (f) =>
                  f.active.equals(true) &
                  f.nextDate.isSmallerOrEqualValue(today),
            ))
            .get();
    for (final f in due) {
      final r = dueFixedDates(next: f.nextDate, day: f.day, today: today);
      for (final date in r.dates) {
        await into(entries).insert(
          EntriesCompanion.insert(
            kind: EntryKind.expense,
            date: date,
            time: fixedExpenseTime,
            categoryId: f.categoryId,
            amount: f.amount,
            place: Value(f.place),
            description: Value(f.name),
            memo: Value(f.memo),
          ),
        );
        count++;
      }
      await (update(fixedExpenses)..where((x) => x.id.equals(f.id))).write(
        FixedExpensesCompanion(nextDate: Value(r.next)),
      );
    }
    return count;
  });

  /// 가져온 내역을 한 번에 저장하고 (지출 건수, 수입 건수)를 돌려준다.
  /// [choices]: 종류 → 파일의 분류 이름 → 연결할 카테고리 id(null이면 새로 만들기).
  /// 분류가 빈 내역은 같은 종류의 "미분류"로 들어간다.
  ///
  /// 카테고리는 **이 호출 안에서 매번 DB를 보고** 찾거나 만든다. id를 호출 밖에
  /// 기억해 두지 않는다(초기화·삭제 뒤 없는 카테고리를 가리키던 버그가 있었다).
  Future<(int, int)> importEntries(
    List<ImportRow> rows,
    Map<EntryKind, Map<String, int?>> choices,
  ) => transaction(() async {
    final existing = await select(categories).get();
    final ids = {for (final c in existing) c.id};
    final byName = {for (final c in existing) (c.kind, c.name): c.id};
    var created = existing.length;

    Future<int> findOrCreate(EntryKind kind, String name, String? icon) async {
      final found = byName[(kind, name)];
      if (found != null) return found;
      final id = await addCategory(
        kind: kind,
        name: name,
        icon: icon ?? newCategoryEmojis[created % newCategoryEmojis.length],
        color: newCategoryColor,
      );
      created++;
      ids.add(id);
      return byName[(kind, name)] = id;
    }

    // 카테고리를 먼저 정하고(필요하면 만들고), 내역은 마지막에 한 번에 넣는다.
    final inserts = <EntriesCompanion>[];
    var expense = 0;
    var income = 0;
    for (final r in rows) {
      final int categoryId;
      final chosen = choices[r.kind]?[r.categoryRaw];
      if (r.categoryRaw.isEmpty) {
        categoryId = await findOrCreate(r.kind, uncategorizedName, '📦');
      } else if (chosen != null && ids.contains(chosen)) {
        categoryId = chosen;
      } else {
        categoryId = await findOrCreate(
          r.kind,
          importCategoryName(r.categoryRaw),
          null,
        );
      }
      inserts.add(
        EntriesCompanion.insert(
          kind: r.kind,
          date: r.date,
          time: r.time,
          categoryId: categoryId,
          amount: r.amount,
          place: Value(r.place),
          description: Value(r.description),
          memo: Value(r.memo),
        ),
      );
      r.kind == EntryKind.expense ? expense++ : income++;
    }
    await batch((b) => b.insertAll(entries, inserts));
    return (expense, income);
  });

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
