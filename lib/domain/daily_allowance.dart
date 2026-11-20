/// "오늘 쓸 수 있는 돈"을 어떻게 보여줄지(세부 설정). 기본은 안 보기.
enum DailyAllowanceMode {
  /// 보지 않는다.
  off,

  /// 오늘 남은 돈: 하루 기준 금액에서 오늘 쓴 돈을 뺀다(쓸수록 줄어든다).
  leftToday,

  /// 하루 기준 금액: 어제까지 쓴 돈으로 정해서 오늘 하루 동안은 그대로다.
  perDay,
}

/// 오늘 쓸 수 있는 돈 계산 결과.
class DailyAllowance {
  const DailyAllowance({
    required this.perDay,
    required this.spentToday,
    required this.daysLeft,
  });

  /// 어제까지 남은 예산 ÷ 오늘을 포함한 남은 날 수(원 단위 버림).
  final int perDay;
  final int spentToday;

  /// 오늘을 포함해 이번 기간에 남은 날 수.
  final int daysLeft;

  /// 오늘 더 쓸 수 있는 돈. 음수면 그만큼 더 썼다.
  int get leftToday => perDay - spentToday;
}

/// 이번 기간(한 달)의 예산과 지출로 오늘 쓸 수 있는 돈을 계산한다.
/// 예산이 0원이거나 이미 예산을 넘었으면 null(보여주지 않는다).
/// [today]와 [periodEnd]는 'YYYY-MM-DD'.
DailyAllowance? dailyAllowanceOf({
  required int budget,
  required int spentBeforeToday,
  required int spentToday,
  required String today,
  required String periodEnd,
}) {
  if (budget <= 0 || spentBeforeToday + spentToday > budget) return null;
  final daysLeft =
      DateTime.parse(periodEnd).difference(DateTime.parse(today)).inDays + 1;
  if (daysLeft <= 0) return null;
  return DailyAllowance(
    perDay: (budget - spentBeforeToday) ~/ daysLeft,
    spentToday: spentToday,
    daysLeft: daysLeft,
  );
}
