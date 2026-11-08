import 'package:intl/intl.dart';

const weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// 날짜만 남긴 값(시·분·초 제거).
DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// 'YYYY-MM' 형식의 달 키. 달별 예산과 월별 조회에 쓴다.
String monthKeyOf(DateTime t) => '${t.year}-${_two(t.month)}';

/// 'YYYY-MM-DD' 형식. 내역의 날짜 저장 형식과 같다.
String dateKeyOf(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

/// 'HH:mm' 형식. 내역의 시간 저장 형식과 같다.
String timeKeyOf(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// 'YYYY-MM' 키를 그 달 1일로 바꾼다.
DateTime monthStartOf(String monthKey) {
  final parts = monthKey.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

/// 기준 달에서 [delta]개월 이동한 달 키.
String shiftMonthKey(String monthKey, int delta) {
  final start = monthStartOf(monthKey);
  return monthKeyOf(DateTime(start.year, start.month + delta));
}

/// 다음 자정까지 남은 시간.
Duration untilNextMidnight(DateTime now) {
  final next = DateTime(now.year, now.month, now.day + 1);
  return next.difference(now);
}

final _won = NumberFormat('#,###', 'ko_KR');

/// 12345 → '12,345원'
String formatWon(int amount) => '${_won.format(amount)}원';

String _two(int n) => n.toString().padLeft(2, '0');
