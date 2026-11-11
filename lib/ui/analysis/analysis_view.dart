import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../domain/budget.dart';

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
    return AnalysisView(monthKey: monthKeyOf(today), year: today.year);
  }

  void setTab(AnalysisTab tab) => state = state.copyWith(tab: tab);

  void setKind(EntryKind kind) => state = state.copyWith(kind: kind);

  void setRange(int range) => state = state.copyWith(range: range);

  void moveYear(int delta) => state = state.copyWith(year: state.year + delta);

  /// 그 달의 카테고리 비중을 본다(월별 추이에서 달을 눌렀을 때).
  void showMonth(String monthKey) =>
      state = state.copyWith(tab: AnalysisTab.donut, monthKey: monthKey);

  /// 이번 달 카테고리 비중으로(홈의 비율 막대·칩을 눌렀을 때 포함).
  void showCurrentMonth() => showMonth(ref.read(currentMonthKeyProvider));
}

final analysisViewProvider =
    NotifierProvider<AnalysisViewNotifier, AnalysisView>(
      AnalysisViewNotifier.new,
    );
