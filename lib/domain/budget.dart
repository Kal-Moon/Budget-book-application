import '../core/dates.dart';

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
  }) : isSet = true;

  /// 예산을 아직 정하지 않은 달. 0원으로 취급한다.
  const MonthBudget.empty(this.monthKey, {this.mode = BudgetMode.category})
    : total = 0,
      categoryAmounts = const {},
      isSet = false;

  final String monthKey;

  /// 이 달 예산을 정한 적이 있는지(0원으로 정한 것도 정한 것이다).
  final bool isSet;
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

/// 내역을 저장하면 예산을 넘게 되는지 알려주는 문구. 넘지 않으면 null.
/// [spentBefore]는 이 내역을 뺀 그 달(항목별이면 그 카테고리)의 지출,
/// [label]은 '식비' 같은 카테고리 이름 또는 '11월'.
String? budgetWarning({
  required String label,
  required int spentBefore,
  required int amount,
  required int budget,
  required int thresholdPercent,
}) {
  if (amount <= 0) return null;
  final projected = spentBefore + amount;
  if (!isOverBudget(projected, budget, thresholdPercent)) return null;
  if (projected > budget) {
    return '$label 예산을 ${formatWon(projected - budget)} 초과해요';
  }
  return '$label 예산의 ${projected * 100 ~/ budget}%를 쓰게 돼요';
}

/// [source] 달의 예산을 [monthKey] 달로 그대로 옮긴 것("지난달 예산 그대로 쓰기").
MonthBudget copyBudgetTo(String monthKey, MonthBudget source) => MonthBudget(
  monthKey: monthKey,
  mode: source.mode,
  total: source.total,
  categoryAmounts: source.categoryAmounts,
);
