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
/// - 영문 대소문자와 띄어쓰기는 무시한다("삼각 김밥"으로 "삼각김밥"을 찾는다).
/// - 검색어를 띄어 쓰면 낱말마다 나눠서, 모든 낱말이 들어 있는 내역을 찾는다(순서 무관).
/// - 구매처와 내역은 이어서 한 글로 본다. 두 칸에 나눠 쓴 "스타벅스" + "아메리카노"도
///   한 칸에 쓴 "스타벅스 아메리카노"처럼 "스타벅스아메리카노"로 찾을 수 있게.
List<Entry> searchEntries(
  Iterable<Entry> entries,
  Map<int, Category> categories,
  String query,
) {
  final words = [
    for (final w in query.split(_spaces))
      if (w.isNotEmpty) w.toLowerCase(),
  ];
  if (words.isEmpty) return const [];
  return [
    for (final e in entries)
      if (_matchesAll(words, [
        _squash(
          e.kind == EntryKind.expense ? e.place + e.description : e.description,
        ),
        _squash(e.memo),
        _squash(categories[e.categoryId]?.name ?? ''),
      ]))
        e,
  ];
}

final _spaces = RegExp(r'\s+');

/// 띄어쓰기를 빼고 소문자로.
String _squash(String text) => text.replaceAll(_spaces, '').toLowerCase();

/// 낱말마다 어느 한 칸에라도 들어 있으면 참.
bool _matchesAll(List<String> words, List<String> texts) =>
    words.every((w) => texts.any((t) => t.contains(w)));

/// 구매처 칸 자동완성의 한 줄: 예전에 함께 쓴 구매처와 내역(내역은 빌 수 있다).
typedef PlacePair = ({String place, String description});

/// 구매처 칸 자동완성: 예전 지출의 "구매처 · 내역" 짝 중 [query]가 구매처나 내역에
/// 들어 있는 것(최대 [limit]개). 고르면 두 칸을 한 번에 채운다.
/// 순서는 [suggestTexts]와 같다(고른 카테고리 먼저, 그 안에서 최근 것 먼저).
/// 구매처가 빈 기록은 빼고, 입력한 글자와 구매처가 같으면서 내역이 없는 짝은
/// 채울 것이 없으니 뺀다.
List<PlacePair> suggestPlacePairs(
  Iterable<Entry> entries,
  String query, {
  int? categoryId,
  int limit = 5,
}) {
  final q = query.trim().toLowerCase();
  final seen = <String>{};
  final out = <PlacePair>[];
  for (final e in _byCategoryThenRecent(entries, categoryId)) {
    final place = e.place.trim();
    final description = e.description.trim();
    if (place.isEmpty) continue;
    final lowerPlace = place.toLowerCase();
    if (!lowerPlace.contains(q) && !description.toLowerCase().contains(q)) {
      continue;
    }
    if (description.isEmpty && lowerPlace == q) continue;
    if (seen.add('$place\u0000$description')) {
      out.add((place: place, description: description));
    }
    if (out.length == limit) break;
  }
  return out;
}

/// 고른 카테고리의 내역을 먼저, 그 안에서는 최근 것(날짜·시간) 먼저.
List<Entry> _byCategoryThenRecent(Iterable<Entry> entries, int? categoryId) {
  int rank(Entry e) => e.categoryId == categoryId ? 0 : 1;
  return entries.toList()..sort((a, b) {
    final byCategory = rank(a).compareTo(rank(b));
    if (byCategory != 0) return byCategory;
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.time.compareTo(a.time);
  });
}

/// 입력 칸 자동완성: 이미 쓴 문구([field]) 중 [query]를 포함하는 것(최대 [limit]개).
/// [categoryId]가 있으면 그 카테고리에서 쓴 문구를 먼저, 그 안에서는 최근 것 먼저.
/// 칸이 비어 있으면 최근 문구를 그대로 보여준다. 입력한 글자와 똑같은 것은 뺀다.
List<String> suggestTexts(
  Iterable<Entry> entries,
  String Function(Entry e) field,
  String query, {
  int? categoryId,
  int limit = 5,
}) {
  final q = query.trim().toLowerCase();
  final seen = <String>{};
  final out = <String>[];
  for (final e in _byCategoryThenRecent(entries, categoryId)) {
    final text = field(e).trim();
    final lower = text.toLowerCase();
    if (text.isEmpty || lower == q || !lower.contains(q)) continue;
    if (seen.add(text)) out.add(text);
    if (out.length == limit) break;
  }
  return out;
}
