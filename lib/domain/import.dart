import 'budget.dart';
import 'categories.dart';

/// 가져올 파일을 표로 읽은 것. 첫 줄은 항목 이름(헤더).
/// 칸의 값은 String, num, DateTime 중 하나이거나 비어 있으면 null.
class ImportTable {
  ImportTable(List<List<Object?>> all)
    : headers = [
        for (final (i, h)
            in (all.isEmpty ? const <Object?>[] : all.first).indexed)
          _text(h).isEmpty ? '${i + 1}열' : _text(h),
      ],
      rows = [
        for (final r in all.skip(1))
          if (r.any((c) => _text(c).isNotEmpty)) r,
      ];

  final List<String> headers;
  final List<List<Object?>> rows;

  Object? cell(List<Object?> row, int column) =>
      column >= 0 && column < row.length ? row[column] : null;
}

String _text(Object? v) => v == null ? '' : v.toString().trim();

/// 수입/지출을 어떻게 구분할지.
enum ImportTypeMode {
  /// 금액 부호로: 음수는 지출, 양수는 수입.
  sign,

  /// 별도 열로: "수입"/"지출" 같은 글자가 적힌 열을 본다.
  column,

  /// 전부 지출로.
  allExpense,
}

/// 파일의 어느 열이 무엇인지. -1은 "없음".
class ImportMapping {
  const ImportMapping({
    required this.date,
    required this.amount,
    this.category = -1,
    this.place = -1,
    this.description = -1,
    this.memo = -1,
    this.type = -1,
    this.typeMode = ImportTypeMode.sign,
  });

  final int date;
  final int amount;
  final int category;
  final int place;
  final int description;
  final int memo;

  /// 수입/지출 구분 열([ImportTypeMode.column]일 때만 쓴다).
  final int type;
  final ImportTypeMode typeMode;

  ImportMapping copyWith({
    int? date,
    int? amount,
    int? category,
    int? place,
    int? description,
    int? memo,
    int? type,
    ImportTypeMode? typeMode,
  }) => ImportMapping(
    date: date ?? this.date,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    place: place ?? this.place,
    description: description ?? this.description,
    memo: memo ?? this.memo,
    type: type ?? this.type,
    typeMode: typeMode ?? this.typeMode,
  );
}

/// 헤더 이름으로 열을 추측한다. **정확히 같은 이름을 먼저** 찾고, 없으면 포함하는 이름을 찾는다.
/// (포함만 보면 '금액'을 찾을 때 '수입/지출' 같은 열이 먼저 잡히는 일이 있었다)
int guessColumn(List<String> headers, List<String> keywords) {
  final lower = [for (final h in headers) h.toLowerCase().trim()];
  for (final (i, h) in lower.indexed) {
    if (keywords.any((k) => h == k.toLowerCase())) return i;
  }
  for (final (i, h) in lower.indexed) {
    if (keywords.any((k) => h.contains(k.toLowerCase()))) return i;
  }
  return -1;
}

/// 헤더를 보고 추측한 기본 열 연결.
/// 구분 열이 있고 금액에 음수가 없으면 "별도 열로"를 고른다(편한가계부처럼 금액이 항상 양수인 파일).
ImportMapping guessMapping(ImportTable table) {
  int guess(List<String> keys) => guessColumn(table.headers, keys);
  final amount = guess(['금액', 'amount']);
  final type = guess(['수입/지출', '구분', '수입지출', 'type']);
  final hasNegative =
      amount >= 0 &&
      table.rows.any((r) => (parseAmountCell(table.cell(r, amount)) ?? 0) < 0);
  return ImportMapping(
    date: guess(['날짜', '일자', 'date', '거래일']),
    amount: amount,
    category: guess(['카테고리', '분류', 'category']),
    place: guess(['구매처', '가맹점', '상호', '장소']),
    description: guess(['내용', '내역', '품명', '상품']),
    memo: guess(['메모', '비고', 'note']),
    type: type,
    typeMode: type >= 0 && amount >= 0 && !hasNegative
        ? ImportTypeMode.column
        : ImportTypeMode.sign,
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 날짜(와 있으면 시간)를 읽는다. 읽지 못하면 null.
/// 받아들이는 형식: DateTime, 엑셀 날짜 숫자, '2026-11-08', '2026.11.08', '2026/11/08',
/// '2026년 11월 8일', 뒤에 '12:30' 같은 시간이 붙은 것, '11/08/2026'.
({String date, String? time})? parseDateCell(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) {
    final hasTime = raw.hour != 0 || raw.minute != 0;
    return (
      date: '${raw.year}-${_two(raw.month)}-${_two(raw.day)}',
      time: hasTime ? '${_two(raw.hour)}:${_two(raw.minute)}' : null,
    );
  }
  if (raw is num) {
    // 엑셀 날짜 숫자: 1970-01-01이 25569, 소수 부분은 하루 중 시각.
    if (raw < 1 || raw > 100000) return null;
    final minutes = (raw * 24 * 60).round();
    final d = DateTime.utc(1899, 12, 30).add(Duration(minutes: minutes));
    final hasTime = minutes % (24 * 60) != 0;
    return (
      date: '${d.year}-${_two(d.month)}-${_two(d.day)}',
      time: hasTime ? '${_two(d.hour)}:${_two(d.minute)}' : null,
    );
  }
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  int y, m, d;
  var ymd = RegExp(r'^(\d{4})\s*[-./년]\s*(\d{1,2})\s*[-./월]\s*(\d{1,2})')
      .firstMatch(s);
  if (ymd != null) {
    y = int.parse(ymd[1]!);
    m = int.parse(ymd[2]!);
    d = int.parse(ymd[3]!);
  } else {
    ymd = RegExp(r'^(\d{1,2})[-./](\d{1,2})[-./](\d{4})').firstMatch(s);
    if (ymd == null) return null;
    m = int.parse(ymd[1]!);
    d = int.parse(ymd[2]!);
    y = int.parse(ymd[3]!);
  }
  // 13월, 2월 30일 같은 없는 날짜는 받아들이지 않는다.
  final check = DateTime(y, m, d);
  if (check.year != y || check.month != m || check.day != d) return null;
  final t = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s.substring(ymd.end));
  String? time;
  if (t != null) {
    var h = int.parse(t[1]!);
    final min = int.parse(t[2]!);
    final rest = s.substring(ymd.end);
    if (RegExp(r'오후|PM', caseSensitive: false).hasMatch(rest) && h < 12) {
      h += 12;
    }
    if (RegExp(r'오전|AM', caseSensitive: false).hasMatch(rest) && h == 12) {
      h = 0;
    }
    if (h < 24 && min < 60) time = '${_two(h)}:${_two(min)}';
  }
  return (date: '$y-${_two(m)}-${_two(d)}', time: time);
}

/// 금액을 읽는다. 쉼표·'원'·공백은 무시하고, '-' 또는 괄호는 음수. 읽지 못하면 null.
num? parseAmountCell(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw;
  var s = raw.toString().replaceAll(RegExp(r'[,원₩\s]'), '');
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  }
  final n = num.tryParse(s);
  if (n == null) return null;
  return negative ? -n : n;
}

/// 파일에서 읽은 내역 한 줄(아직 카테고리 id는 정해지지 않았다).
class ImportRow {
  const ImportRow({
    required this.kind,
    required this.date,
    required this.time,
    required this.amount,
    required this.categoryRaw,
    required this.place,
    required this.description,
    required this.memo,
  });

  final EntryKind kind;
  final String date;
  final String time;
  final int amount;

  /// 파일에 적힌 분류 이름. 비어 있으면 미분류로 들어간다.
  final String categoryRaw;
  final String place;
  final String description;
  final String memo;
}

class ImportParseResult {
  const ImportParseResult(this.rows, this.skipped);

  final List<ImportRow> rows;

  /// 날짜·금액을 읽지 못했거나 금액이 0이라 건너뛴 줄 수.
  final int skipped;

  /// 파일에 나온 분류 이름(비어 있는 것 제외, 나온 순서대로).
  List<String> categoriesOf(EntryKind kind) {
    final seen = <String>{};
    return [
      for (final r in rows)
        if (r.kind == kind &&
            r.categoryRaw.isNotEmpty &&
            seen.add(r.categoryRaw))
          r.categoryRaw,
    ];
  }

  int total(EntryKind kind) =>
      rows.where((r) => r.kind == kind).fold(0, (s, r) => s + r.amount);
}

/// 열 연결대로 표를 내역으로 읽는다.
ImportParseResult parseImportRows(ImportTable table, ImportMapping m) {
  final rows = <ImportRow>[];
  var skipped = 0;
  for (final r in table.rows) {
    final when = parseDateCell(table.cell(r, m.date));
    final rawAmount = parseAmountCell(table.cell(r, m.amount));
    if (when == null || rawAmount == null || rawAmount == 0) {
      skipped++;
      continue;
    }
    final kind = switch (m.typeMode) {
      ImportTypeMode.sign =>
        rawAmount < 0 ? EntryKind.expense : EntryKind.income,
      ImportTypeMode.column =>
        RegExp(
              r'수입|입금|income',
              caseSensitive: false,
            ).hasMatch(_text(table.cell(r, m.type)))
            ? EntryKind.income
            : EntryKind.expense,
      ImportTypeMode.allExpense => EntryKind.expense,
    };
    rows.add(
      ImportRow(
        kind: kind,
        date: when.date,
        time: when.time ?? '12:00',
        amount: rawAmount.abs().round(),
        categoryRaw: _text(table.cell(r, m.category)),
        // 구매처는 지출에만 있다.
        place: kind == EntryKind.expense ? _text(table.cell(r, m.place)) : '',
        description: _text(table.cell(r, m.description)),
        memo: _text(table.cell(r, m.memo)),
      ),
    );
  }
  return ImportParseResult(rows, skipped);
}

/// 분류가 빈 내역이 들어가는 카테고리 이름.
const uncategorizedName = '미분류';

/// 파일의 분류 이름을 우리 카테고리 이름 규칙(최대 8자)에 맞춘 것.
String importCategoryName(String raw) {
  final t = raw.trim();
  return t.length <= categoryNameMaxLength
      ? t
      : t.substring(0, categoryNameMaxLength);
}
