import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/today.dart';
import '../../data/settings.dart';
import '../../domain/budget.dart';
import '../../domain/period.dart';

/// 원 그래프·월별 추이가 달을 나누는 기준. 세부 설정에서 "월간 통계도 시작일에
/// 맞추기"를 켜면 한 달 시작일, 끄면 달력(1일~말일).
final monthStatsCalendarProvider = Provider<PeriodCalendar>(
  (ref) => ref.watch(settingsProvider.select((s) => s.alignMonthStats))
      ? ref.watch(periodCalendarProvider)
      : PeriodCalendar.calendar,
);

/// 연간 통계가 해와 달을 나누는 기준("연간 통계도 시작일에 맞추기").
final yearStatsCalendarProvider = Provider<PeriodCalendar>(
  (ref) => ref.watch(settingsProvider.select((s) => s.alignYearStats))
      ? ref.watch(periodCalendarProvider)
      : PeriodCalendar.calendar,
);

/// 통계의 [key] 달이 예산의 기간과 같은 날짜 범위인지. 다르면 예산과 비교할 수 없어
/// 초과 표시를 하지 않는다(예산은 한 달 시작일 기준으로 정한 것이라서).
bool sameAsBudgetPeriod(
  PeriodCalendar stats,
  PeriodCalendar budgets,
  String key,
) => stats.rangeOf(key) == budgets.rangeOf(key);

/// 한 달 시작일을 쓰고 있을 때 월간 통계 위에 보여줄 기준 문구. 1일 시작이면 null.
String? monthStatsBasis(
  PeriodCalendar stats,
  PeriodCalendar budgets,
  String key,
) {
  if (budgets.isCalendar) return null;
  return stats.isCalendar
      ? '달력 기준 · ${stats.rangeLabel(key)}'
      : '${stats.rangeLabel(key)} 기준';
}

enum AnalysisTab { donut, trend, year }

/// 분석 화면이 보고 있는 것. 홈과 따로 가지며, 날짜가 바뀌면 이번 달로 돌아간다.
class AnalysisView {
  const AnalysisView({
    required this.monthKey,
    required this.year,
    this.tab = AnalysisTab.donut,
    this.kind = EntryKind.expense,
    this.range = 6,
  });

  final AnalysisTab tab;

  /// 카테고리 비중에서 보고 있는 달.
  final String monthKey;

  /// 카테고리 비중의 지출/수입 전환.
  final EntryKind kind;

  /// 월별 추이 기간(3/6/12개월).
  final int range;

  /// 연간 통계에서 보고 있는 해.
  final int year;

  AnalysisView copyWith({
    AnalysisTab? tab,
    String? monthKey,
    EntryKind? kind,
    int? range,
    int? year,
  }) => AnalysisView(
    tab: tab ?? this.tab,
    monthKey: monthKey ?? this.monthKey,
    kind: kind ?? this.kind,
    range: range ?? this.range,
    year: year ?? this.year,
  );
}

class AnalysisViewNotifier extends Notifier<AnalysisView> {
  @override
  AnalysisView build() {
    final today = ref.watch(todayProvider);
    final yearKey = ref.watch(yearStatsCalendarProvider).keyOf(today);
    return AnalysisView(
      monthKey: ref.watch(monthStatsCalendarProvider).keyOf(today),
      year: int.parse(yearKey.substring(0, 4)),
    );
  }

  void setTab(AnalysisTab tab) => state = state.copyWith(tab: tab);

  void setKind(EntryKind kind) => state = state.copyWith(kind: kind);

  void setRange(int range) => state = state.copyWith(range: range);

  void moveYear(int delta) => state = state.copyWith(year: state.year + delta);

  /// 그 달의 카테고리 비중을 본다(월별 추이에서 달을 눌렀을 때).
  void showMonth(String monthKey) =>
      state = state.copyWith(tab: AnalysisTab.donut, monthKey: monthKey);

  /// 이번 달 카테고리 비중으로(홈의 비율 막대·칩을 눌렀을 때 포함).
  void showCurrentMonth() => showMonth(
    ref.read(monthStatsCalendarProvider).keyOf(ref.read(todayProvider)),
  );
}

final analysisViewProvider =
    NotifierProvider<AnalysisViewNotifier, AnalysisView>(
      AnalysisViewNotifier.new,
    );
