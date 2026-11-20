/// 고정 지출의 날짜 규칙. 날짜는 'YYYY-MM-DD', 달력 기준(한 달 시작일과 무관).
/// [day]는 1~31. 그 달에 없는 날(2월 30일 등)은 그 달 말일로 입력한다.
library;

String _two(int n) => n.toString().padLeft(2, '0');

String _dateKey(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return '$year-${_two(month)}-${_two(day > last ? last : day)}';
}

/// [year]년 [month]월에 [day]일이 되는 날짜(없는 날이면 말일).
String fixedDateIn(int year, int month, int day) => _dateKey(year, month, day);

/// [from] 날짜 이후(그날 포함) 처음 오는 [day]일.
String firstFixedDateFrom(String from, int day) {
  final d = DateTime.parse(from);
  final thisMonth = _dateKey(d.year, d.month, day);
  return thisMonth.compareTo(from) >= 0
      ? thisMonth
      : _dateKey(d.year, d.month + 1, day);
}

/// [date] 다음 달의 [day]일.
String nextFixedDate(String date, int day) {
  final d = DateTime.parse(date);
  final next = DateTime(d.year, d.month + 1);
  return _dateKey(next.year, next.month, day);
}

/// 날짜를 바꾸거나 멈췄다 다시 켤 때의 다음 입력일.
/// 이미 입력한 달에 또 입력하지 않도록 지금 다음 입력일의 달보다 앞당기지 않고,
/// 지난 날짜를 한꺼번에 채우지 않도록 오늘보다 앞당기지도 않는다.
String resumeFixedDate({
  required String storedNext,
  required int day,
  required String today,
}) {
  final stored = DateTime.parse(storedNext);
  final sameMonth = _dateKey(stored.year, stored.month, day);
  final fromToday = firstFixedDateFrom(today, day);
  return sameMonth.compareTo(fromToday) >= 0 ? sameMonth : fromToday;
}

/// [next]부터 [today]까지(그날 포함) 입력할 날짜들과, 그다음 입력일.
({List<String> dates, String next}) dueFixedDates({
  required String next,
  required int day,
  required String today,
}) {
  final dates = <String>[];
  var cursor = next;
  while (cursor.compareTo(today) <= 0) {
    dates.add(cursor);
    cursor = nextFixedDate(cursor, day);
  }
  return (dates: dates, next: cursor);
}
