import '../core/dates.dart';
import '../data/database.dart';
import 'budget.dart';

/// 한 달의 지출 합계(월별 추이의 한 점).
class MonthTotal {
  const MonthTotal(this.monthKey, this.total);

  final String monthKey;
  final int total;

  /// '26.11'
  String get label {
    final d = monthStartOf(monthKey);
    return '${d.year % 100}.${d.month}';
  }
}

/// [endMonthKey]에서 끝나는 최근 [count]개월의 지출 합계(오래된 달부터).
List<MonthTotal> monthlyExpenseTotals(
  Iterable<Entry> entries,
  String endMonthKey,
  int count,
) {
  final sums = <String, int>{};
  for (final e in entries) {
    if (e.kind != EntryKind.expense) continue;
    final key = e.date.substring(0, 7);
    sums[key] = (sums[key] ?? 0) + e.amount;
  }
  return [
    for (var i = count - 1; i >= 0; i--)
      MonthTotal(
        shiftMonthKey(endMonthKey, -i),
        sums[shiftMonthKey(endMonthKey, -i)] ?? 0,
      ),
  ];
}

/// 월별 추이 요약.
class TrendStats {
  TrendStats(List<MonthTotal> months)
    : average = months.isEmpty
          ? 0
          : (months.fold(0, (s, m) => s + m.total) / months.length).round(),
      last = months.isEmpty ? 0 : months.last.total,
      previous = months.length > 1 ? months[months.length - 2].total : null,
      highest = months.isEmpty
          ? null
          : months.reduce((a, b) => b.total > a.total ? b : a);

  final int average;
  final int last;

  /// 전월 지출. 한 달만 볼 때는 없다.
  final int? previous;

  /// 지출이 가장 많았던 달.
  final MonthTotal? highest;

  /// 전월 대비 증감액.
  int get difference => last - (previous ?? last);
}

/// 증감률 표시. 기준이 0이면 계산할 수 없어 '-'.
String percentChange(int from, int to) {
  if (from == 0) return '-';
  final pct = (to - from) / from * 100;
  return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
}

/// 한 해의 지출 통계.
class YearStats {
  YearStats(Iterable<Entry> entries, this.year, DateTime today) {
    for (final e in entries) {
      if (e.kind != EntryKind.expense || !e.date.startsWith('$year-')) continue;
      total += e.amount;
      final month = int.parse(e.date.substring(5, 7));
      (byCategory[e.categoryId] ??= List.filled(12, 0))[month - 1] += e.amount;
    }
    // 올해는 지금까지 지난 달 수로, 지난 해는 12로 나눈다(아직 오지 않은 해는 0).
    final months = year < today.year
        ? 12
        : year == today.year
        ? today.month
        : 0;
    monthlyAverage = months == 0 ? 0 : (total / months).round();
  }

  final int year;
  int total = 0;
  late final int monthlyAverage;

  /// 카테고리 id → 1~12월 지출.
  final Map<int, List<int>> byCategory = {};

  int categoryTotal(int id) =>
      (byCategory[id] ?? const <int>[]).fold(0, (s, v) => s + v);
}

/// 초과 강조 색(세부 설정의 "분석 화면 강조 표시"). 기본 6 + 파스텔 6.
class HighlightColor {
  const HighlightColor(
    this.key,
    this.swatch,
    this.background,
    this.border,
    this.text,
  );

  final String key;
  final int swatch;
  final int background;
  final int border;
  final int text;
}

const highlightColors = [
  HighlightColor('red', 0xFFE24B4A, 0xFFFCEBEB, 0xFFE24B4A, 0xFF791F1F),
  HighlightColor('blue', 0xFF185FA5, 0xFFE6F1FB, 0xFF185FA5, 0xFF042C53),
  HighlightColor('green', 0xFF3B6D11, 0xFFEAF3DE, 0xFF3B6D11, 0xFF173404),
  HighlightColor('yellow', 0xFFEF9F27, 0xFFFAEEDA, 0xFFEF9F27, 0xFF412402),
  HighlightColor('orange', 0xFFD85A30, 0xFFFAECE7, 0xFFD85A30, 0xFF4A1B0C),
  HighlightColor('purple', 0xFF534AB7, 0xFFEEEDFE, 0xFF534AB7, 0xFF26215C),
  HighlightColor('pink', 0xFFF4C0D1, 0xFFFBEAF0, 0xFFED93B1, 0xFF993556),
  HighlightColor('mint', 0xFF9FE1CB, 0xFFE1F5EE, 0xFF5DCAA5, 0xFF085041),
  HighlightColor('lavender', 0xFFCECBF6, 0xFFEEEDFE, 0xFFAFA9EC, 0xFF3C3489),
  HighlightColor('peach', 0xFFF5C4B3, 0xFFFAECE7, 0xFFF0997B, 0xFF712B13),
  HighlightColor('sky', 0xFFB5D4F4, 0xFFE6F1FB, 0xFF85B7EB, 0xFF0C447C),
  HighlightColor('beige', 0xFFD3D1C7, 0xFFF1EFE8, 0xFFB4B2A9, 0xFF444441),
];

HighlightColor highlightColorOf(String key) => highlightColors.firstWhere(
  (c) => c.key == key,
  orElse: () => highlightColors.first,
);

/// 달 전체 지출을 강조할지: 총 예산 방식이면 항상, 항목별 방식이면 설정을 켰을 때만.
bool highlightMonthTotal({
  required MonthBudget budget,
  required int spent,
  required int thresholdPercent,
  required bool alsoInCategoryMode,
}) =>
    (budget.mode == BudgetMode.total || alsoInCategoryMode) &&
    isOverBudget(spent, budget.totalBudget, thresholdPercent);
