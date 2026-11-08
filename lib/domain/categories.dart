/// 카테고리 이름 최대 길이(모든 화면 공통).
const categoryNameMaxLength = 8;

/// 새 카테고리를 만들 때 돌아가며 쓰는 이모지.
const newCategoryEmojis = ['💊', '🎬', '✈️', '🐾', '📚', '🎮', '🎵', '🏠'];

/// 새 카테고리 기본 색(회색). 색상은 세부 설정에서 바꾼다.
const newCategoryColor = 0xFF888780;

/// 카테고리 이름 검사. 문제가 없으면 null, 있으면 화면에 보여줄 문구.
/// [otherNames]는 같은 종류(지출/수입)의 다른 카테고리 이름들.
String? validateCategoryName(String name, Iterable<String> otherNames) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '이름을 입력해주세요';
  if (trimmed.length > categoryNameMaxLength) {
    return '이름은 $categoryNameMaxLength자까지 쓸 수 있어요';
  }
  if (otherNames.any((n) => n.trim() == trimmed)) return '이미 있는 이름이에요';
  return null;
}

/// 겹치지 않는 새 카테고리 이름: '새 항목', '새 항목 2', ...
String uniqueNewCategoryName(Iterable<String> existing) {
  const base = '새 항목';
  final names = existing.map((n) => n.trim()).toSet();
  if (!names.contains(base)) return base;
  var i = 2;
  while (names.contains('$base $i')) {
    i++;
  }
  return '$base $i';
}

/// 화면에서 편집 중인 카테고리(아직 저장 전). [id]가 없으면 새로 만들 카테고리.
class CategoryDraft {
  CategoryDraft({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final int? id;
  String name;
  final String icon;
  final int color;
}
