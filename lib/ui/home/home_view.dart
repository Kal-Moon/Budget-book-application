import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../domain/budget.dart';

/// 홈의 전체/지출/수입 필터.
enum HomeTypeFilter { all, expense, income }

/// 홈에서 보고 있는 범위와 필터. 앱을 쓰는 동안만 유지하고 저장하지 않는다.
/// 날짜가 바뀌면 이번 달로 돌아간다.
class HomeView {
  const HomeView({
    required this.monthKey,
    this.selectedDate,
    this.type = HomeTypeFilter.all,
    this.categoryId,
  });

  /// 보고 있는 달 'YYYY-MM'.
  final String monthKey;

  /// 하루만 보고 있으면 'YYYY-MM-DD'.
  final String? selectedDate;
  final HomeTypeFilter type;

  /// 카테고리 필터(없으면 전체).
  final int? categoryId;

  /// 카테고리 필터 칩에 보여줄 종류. "수입"이면 수입 카테고리, 그 외는 지출 카테고리.
  EntryKind get categoryKind =>
      type == HomeTypeFilter.income ? EntryKind.income : EntryKind.expense;
}

class HomeViewNotifier extends Notifier<HomeView> {
  @override
  HomeView build() => HomeView(monthKey: monthKeyOf(ref.watch(todayProvider)));

  void showMonth(String monthKey) => state = HomeView(
    monthKey: monthKey,
    type: state.type,
    categoryId: state.categoryId,
  );

  void showDay(String date) => state = HomeView(
    monthKey: date.substring(0, 7),
    selectedDate: date,
    type: state.type,
    categoryId: state.categoryId,
  );

  /// 하루 보기를 풀고 그 달 전체를 본다.
  void clearDay() => showMonth(state.monthKey);

  /// 종류를 바꾸면 카테고리 필터는 풀린다(지출·수입 카테고리가 다르므로).
  void setType(HomeTypeFilter type) => state = HomeView(
    monthKey: state.monthKey,
    selectedDate: state.selectedDate,
    type: type,
  );

  void setCategory(int? categoryId) => state = HomeView(
    monthKey: state.monthKey,
    selectedDate: state.selectedDate,
    type: state.type,
    categoryId: categoryId,
  );
}

final homeViewProvider = NotifierProvider<HomeViewNotifier, HomeView>(
  HomeViewNotifier.new,
);

/// 날짜 키 'YYYY-MM-DD' → '11월 8일 토'
String dayLabel(String date) {
  final d = DateTime.parse(date);
  return '${d.month}월 ${d.day}일 ${weekdayNames[d.weekday - 1]}';
}
