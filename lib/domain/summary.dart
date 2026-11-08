import '../data/database.dart';
import 'budget.dart';

/// 한 달(또는 하루) 내역의 합계.
class EntryTotals {
  EntryTotals(Iterable<Entry> entries) {
    for (final e in entries) {
      if (e.kind == EntryKind.expense) {
        expense += e.amount;
        byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
      } else {
        income += e.amount;
      }
    }
  }

  int expense = 0;
  int income = 0;

  /// 지출 카테고리 id → 지출 합계.
  final Map<int, int> byCategory = {};

  int get difference => income - expense;

  int spentIn(int categoryId) => byCategory[categoryId] ?? 0;
}

/// 날짜별로 묶은 내역. 날짜 최신순, 같은 날 안에서는 시간 최신순.
class DayGroup {
  DayGroup(this.date, this.entries);

  /// 'YYYY-MM-DD'
  final String date;
  final List<Entry> entries;

  /// 그날의 수입 − 지출.
  int get net => entries.fold(
    0,
    (s, e) => s + (e.kind == EntryKind.income ? e.amount : -e.amount),
  );
}

List<DayGroup> groupByDate(Iterable<Entry> entries) {
  final map = <String, List<Entry>>{};
  for (final e in entries) {
    (map[e.date] ??= []).add(e);
  }
  final dates = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in dates)
      DayGroup(d, map[d]!..sort((a, b) => b.time.compareTo(a.time))),
  ];
}

/// 전체 기간 검색. 지출은 내역·구매처·메모·카테고리명, 수입은 내역·메모·카테고리명.
/// 영문 대소문자는 무시한다.
List<Entry> searchEntries(
  Iterable<Entry> entries,
  Map<int, Category> categories,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  bool has(String text) => text.toLowerCase().contains(q);
  return [
    for (final e in entries)
      if (has(e.description) ||
          has(e.memo) ||
          (e.kind == EntryKind.expense && has(e.place)) ||
          has(categories[e.categoryId]?.name ?? ''))
        e,
  ];
}
