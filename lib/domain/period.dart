import 'dart:convert';

import '../core/dates.dart';

/// "한 달 시작일" 값. 1~28은 그날, [lastDay]는 그 달의 마지막 날.
const lastDay = 0;

/// 고를 수 있는 시작일(1~28일, 말일).
final monthStartDays = List<int>.unmodifiable([
  for (var d = 1; d <= 28; d++) d,
  lastDay,
]);

/// '1일', '10일', '말일'
String monthStartDayLabel(int day) => day == lastDay ? '말일' : '$day일';

/// 시작일을 바꾼 기록 하나: [fromKey] 기간부터 [day]일에 시작한다.
class MonthStartChange {
  const MonthStartChange(this.fromKey, this.day);

  /// 'YYYY-MM' 기간 이름.
  final String fromKey;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is MonthStartChange && other.fromKey == fromKey && other.day == day;

  @override
  int get hashCode => Object.hash(fromKey, day);
}

/// 날짜를 "한 달"(기간)로 나누는 규칙.
///
/// - 기간 이름은 시작하는 달이다. 10일 시작이면 '2026-11' = 2026.11.10 ~ 12.9.
/// - 시작일을 바꾸면 다음 기간부터 적용한다([withStartDay]). 지난 기간은 그대로이고,
///   바꾼 그 기간만 다음 기간의 새 시작일 전날까지 늘어나거나 줄어든다.
/// - 기록이 없으면 달력과 같다(1일~말일).
class PeriodCalendar {
  PeriodCalendar([Iterable<MonthStartChange> changes = const []])
    : changes = List.unmodifiable(
        [...changes]..sort((a, b) => a.fromKey.compareTo(b.fromKey)),
      );

  /// 달력 기준(1일~말일). 통계를 시작일에 맞추지 않을 때 쓴다.
  static final calendar = PeriodCalendar();

  /// 오래된 것부터 정렬된 변경 기록.
  final List<MonthStartChange> changes;

  /// 모든 기간이 1일~말일이면 true.
  bool get isCalendar => changes.every((c) => c.day == 1);

  /// 사용자가 마지막으로 고른 시작일(설정 화면에 보여줄 값).
  int get chosenDay => changes.isEmpty ? 1 : changes.last.day;

  /// [key] 기간의 시작일 값.
  int startDayOf(String key) {
    var day = 1;
    for (final c in changes) {
      if (c.fromKey.compareTo(key) > 0) break;
      day = c.day;
    }
    return day;
  }

  /// [key] 기간의 첫날.
  DateTime startOf(String key) {
    final m = monthStartOf(key);
    final day = startDayOf(key);
    return day == lastDay
        ? DateTime(m.year, m.month + 1, 0)
        : DateTime(m.year, m.month, day);
  }

  /// [key] 기간의 마지막 날(다음 기간 첫날의 전날).
  DateTime endOf(String key) {
    final next = startOf(shiftMonthKey(key, 1));
    return DateTime(next.year, next.month, next.day - 1);
  }

  /// [key] 기간의 날짜 범위('YYYY-MM-DD', 양 끝 포함).
  DateRange rangeOf(String key) =>
      DateRange(dateKeyOf(startOf(key)), dateKeyOf(endOf(key)));

  /// [date]가 속한 기간 이름.
  String keyOf(DateTime date) {
    final d = dateOnly(date);
    final own = monthKeyOf(d);
    // 기간의 첫날은 언제나 이름과 같은 달 안에 있다.
    return startOf(own).isAfter(d) ? shiftMonthKey(own, -1) : own;
  }

  /// 'YYYY-MM-DD' 날짜가 속한 기간 이름.
  String keyOfDate(String date) => keyOf(DateTime.parse(date));

  /// [key] 기간이 1일~말일과 같은지(아니면 화면에 날짜 범위를 함께 보여준다).
  bool isPlainMonth(String key) =>
      startDayOf(key) == 1 && startDayOf(shiftMonthKey(key, 1)) == 1;

  /// '11.10 ~ 12.9'
  String rangeLabel(String key) => _label(startOf(key), endOf(key));

  /// [year]년의 날짜 범위: 그해 1월 기간의 첫날 ~ 다음 해 1월 기간 첫날의 전날.
  DateRange yearRange(int year) {
    final first = startOf('$year-01');
    final next = startOf('${year + 1}-01');
    return DateRange(
      dateKeyOf(first),
      dateKeyOf(DateTime(next.year, next.month, next.day - 1)),
    );
  }

  /// '2026.1.10 ~ 2027.1.9'
  String yearRangeLabel(int year) {
    final r = yearRange(year);
    String f(String d) {
      final t = DateTime.parse(d);
      return '${t.year}.${t.month}.${t.day}';
    }

    return '${f(r.start)} ~ ${f(r.end)}';
  }

  /// [today]에 시작일을 [day]로 바꾼 결과. 지금 기간 다음부터 적용한다.
  /// 같은 기간 안에서 여러 번 바꾸면 마지막 값만 남는다.
  PeriodCalendar withStartDay(DateTime today, int day) {
    final from = shiftMonthKey(keyOf(today), 1);
    final kept = changes.where((c) => c.fromKey.compareTo(from) < 0);
    final base = PeriodCalendar(kept);
    if (base.startDayOf(from) == day) return base;
    return PeriodCalendar([...kept, MonthStartChange(from, day)]);
  }

  /// 설정에 저장하는 문자열. 기록이 없으면 ''.
  String encode() => changes.isEmpty
      ? ''
      : jsonEncode([
          for (final c in changes) [c.fromKey, c.day],
        ]);

  /// 저장된 문자열을 읽는다. 형식이 맞지 않으면 달력 기준.
  factory PeriodCalendar.decode(String text) {
    if (text.isEmpty) return PeriodCalendar();
    try {
      final list = jsonDecode(text) as List<Object?>;
      return PeriodCalendar([
        for (final item in list)
          if (item case [final String key, final int day]
              when _validKey(key) && monthStartDays.contains(day))
            MonthStartChange(key, day),
      ]);
    } catch (_) {
      return PeriodCalendar();
    }
  }

  static bool _validKey(String key) =>
      RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(key);

  static String _label(DateTime a, DateTime b) =>
      '${a.month}.${a.day} ~ ${b.month}.${b.day}';
}

/// 날짜 범위('YYYY-MM-DD', 양 끝 포함).
class DateRange {
  const DateRange(this.start, this.end);

  final String start;
  final String end;

  bool contains(String date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start ~ $end';
}
