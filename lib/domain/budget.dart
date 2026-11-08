/// 내역의 종류. DB에는 순서(index)로 저장되므로 순서를 바꾸지 않는다.
enum EntryKind { expense, income }

/// 예산 방식. DB에는 순서(index)로 저장되므로 순서를 바꾸지 않는다.
enum BudgetMode {
  /// 총 예산으로 정하기
  total,

  /// 항목별로 정하기
  category;

  String get label => switch (this) {
    BudgetMode.total => '총 예산으로 정하기',
    BudgetMode.category => '항목별로 정하기',
  };
}

/// 한 달의 예산. 예산은 달별로만 저장하고, 화면은 항상 "보고 있는 달"의 값을 쓴다.
class MonthBudget {
  const MonthBudget({
    required this.monthKey,
    required this.mode,
    this.total = 0,
    this.categoryAmounts = const {},
  });

  /// 예산을 아직 정하지 않은 달. 0원으로 취급한다.
  const MonthBudget.empty(this.monthKey, {this.mode = BudgetMode.category})
    : total = 0,
      categoryAmounts = const {};

  final String monthKey;
  final BudgetMode mode;

  /// 총 예산 방식의 총액.
  final int total;

  /// 항목별 방식의 카테고리 id → 금액.
  final Map<int, int> categoryAmounts;

  /// 이 달의 총 예산. 항목별 방식이면 카테고리 예산의 합.
  int get totalBudget => switch (mode) {
    BudgetMode.total => total,
    BudgetMode.category => categoryAmounts.values.fold(0, (a, b) => a + b),
  };

  /// 카테고리 예산. 총 예산 방식인 달에는 카테고리 예산이 없다(0).
  int categoryBudget(int categoryId) => switch (mode) {
    BudgetMode.total => 0,
    BudgetMode.category => categoryAmounts[categoryId] ?? 0,
  };
}

/// 초과 판단: 예산이 있고, 쓴 금액이 예산 × 임계값(%) 이상이면 초과.
bool isOverBudget(int spent, int budget, int thresholdPercent) =>
    budget > 0 && spent * 100 >= budget * thresholdPercent;
