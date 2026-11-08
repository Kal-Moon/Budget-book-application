import '../domain/budget.dart';

class DefaultCategory {
  const DefaultCategory(this.kind, this.icon, this.name, this.color);

  final EntryKind kind;
  final String icon;
  final String name;
  final int color;
}

/// 처음 설치할 때와 초기화할 때만 넣는 기본 카테고리.
const defaultCategories = [
  DefaultCategory(EntryKind.expense, '🍚', '식비', 0xFF378ADD),
  DefaultCategory(EntryKind.expense, '🚌', '교통', 0xFFE24B4A),
  DefaultCategory(EntryKind.expense, '☕', '카페', 0xFF3B6D11),
  DefaultCategory(EntryKind.expense, '🛍️', '쇼핑', 0xFFEF9F27),
  DefaultCategory(EntryKind.income, '💼', '월급', 0xFF185FA5),
  DefaultCategory(EntryKind.income, '💵', '용돈', 0xFF5DCAA5),
  DefaultCategory(EntryKind.income, '💰', '부수입', 0xFFD85A30),
  DefaultCategory(EntryKind.income, '🏦', '금융수입', 0xFF534AB7),
];
