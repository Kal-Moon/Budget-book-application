import 'budget.dart';
import 'categories.dart';

/// 파일의 시트 하나를 읽은 그대로(제목 줄·빈 줄 포함).
/// 칸의 값은 String, num, DateTime 중 하나이거나 비어 있으면 null.
class ImportSheet {
  const ImportSheet(this.name, this.rows);

  final String name;
  final List<List<Object?>> rows;

  bool get isEmpty => !rows.any((r) => r.any((c) => _text(c).isNotEmpty));
}

/// 가져올 표. [headerRow]번째 줄(0부터)이 항목 이름(헤더)이고, 그 아래가 내역이다.
/// 헤더 위의 줄(제목·기간 같은 것)은 읽지 않는다.
class ImportTable {
  ImportTable(List<List<Object?>> all, {this.headerRow = 0})
    : raw = all,
      headers = [
        for (final (i, h)
            in (headerRow < all.length ? all[headerRow] : const <Object?>[])
                .indexed)
          _text(h).isEmpty ? '${i + 1}열' : _text(h),
      ],
      rows = [
        for (final r in all.skip(headerRow + 1))
          if (r.any((c) => _text(c).isNotEmpty)) r,
      ];

  /// 시트 전체(헤더 위의 줄 포함). 표를 보면서 맞출 때 보여준다.
  final List<List<Object?>> raw;
  final int headerRow;
  final List<String> headers;
  final List<List<Object?>> rows;

  /// 표의 열 수(가장 긴 줄 기준).
  int get columnCount => raw.fold(0, (n, r) => r.length > n ? r.length : n);

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

  /// 지출 금액 열과 수입 금액 열이 따로 있다(은행 "출금액/입금액" 같은 파일).
  split,
}

/// 열 하나가 무엇인지. 열마다 하나, 같은 역할은 한 열에만.
enum ImportRole {
  date('날짜'),
  time('시간'),
  amount('금액'),
  expenseAmount('지출 금액'),
  incomeAmount('수입 금액'),
  type('수입/지출 구분'),
  category('카테고리'),
  place('구매처'),
  description('내역'),
  memo('메모');

  const ImportRole(this.label);

  final String label;
}

/// 파일의 어느 열이 무엇인지. -1은 "없음".
class ImportMapping {
  const ImportMapping({
    this.date = -1,
    this.amount = -1,
    this.time = -1,
    this.category = -1,
    this.place = -1,
    this.description = -1,
    this.memo = -1,
    this.type = -1,
    this.expenseAmount = -1,
    this.incomeAmount = -1,
    this.typeMode = ImportTypeMode.sign,
  });

  final int date;

  /// 금액 열 하나로 지출·수입을 함께 적은 파일의 금액 열([ImportTypeMode.split]이 아닐 때).
  final int amount;
  final int time;
  final int category;
  final int place;
  final int description;
  final int memo;

  /// 수입/지출 구분 열([ImportTypeMode.column]일 때만 쓴다).
  final int type;

  /// 지출 금액 열·수입 금액 열([ImportTypeMode.split]일 때만 쓴다).
  final int expenseAmount;
  final int incomeAmount;
  final ImportTypeMode typeMode;

  int columnOf(ImportRole role) => switch (role) {
    ImportRole.date => date,
    ImportRole.time => time,
    ImportRole.amount => amount,
    ImportRole.expenseAmount => expenseAmount,
    ImportRole.incomeAmount => incomeAmount,
    ImportRole.type => type,
    ImportRole.category => category,
    ImportRole.place => place,
    ImportRole.description => description,
    ImportRole.memo => memo,
  };

  /// 이 열에 정한 역할. 없으면 null.
  ImportRole? roleOf(int column) => column < 0
      ? null
      : ImportRole.values.where((r) => columnOf(r) == column).firstOrNull;

  /// [column]을 [role]로 정한다(null이면 "안 씀").
  /// 그 열의 예전 역할과, 그 역할을 갖고 있던 다른 열은 비운다.
  /// "금액"과 "지출/수입 금액"은 함께 쓰지 않는다(하나를 고르면 다른 쪽을 비운다).
  ImportMapping assign(int column, ImportRole? role) {
    final cols = {for (final r in ImportRole.values) r: columnOf(r)};
    for (final r in ImportRole.values) {
      if (cols[r] == column) cols[r] = -1;
    }
    var mode = typeMode;
    if (role != null) {
      cols[role] = column;
      switch (role) {
        case ImportRole.expenseAmount || ImportRole.incomeAmount:
          cols[ImportRole.amount] = -1;
          mode = ImportTypeMode.split;
        case ImportRole.amount:
          cols[ImportRole.expenseAmount] = -1;
          cols[ImportRole.incomeAmount] = -1;
          if (mode == ImportTypeMode.split) {
            mode = cols[ImportRole.type]! >= 0
                ? ImportTypeMode.column
                : ImportTypeMode.sign;
          }
        case ImportRole.type:
          if (mode != ImportTypeMode.split) mode = ImportTypeMode.column;
        default:
      }
    }
    if (mode == ImportTypeMode.split &&
        cols[ImportRole.expenseAmount]! < 0 &&
        cols[ImportRole.incomeAmount]! < 0) {
      mode = ImportTypeMode.sign;
    }
    if (mode == ImportTypeMode.column && cols[ImportRole.type]! < 0) {
      mode = ImportTypeMode.sign;
    }
    return ImportMapping(
      date: cols[ImportRole.date]!,
      time: cols[ImportRole.time]!,
      amount: cols[ImportRole.amount]!,
      expenseAmount: cols[ImportRole.expenseAmount]!,
      incomeAmount: cols[ImportRole.incomeAmount]!,
      type: cols[ImportRole.type]!,
      category: cols[ImportRole.category]!,
      place: cols[ImportRole.place]!,
      description: cols[ImportRole.description]!,
      memo: cols[ImportRole.memo]!,
      typeMode: mode,
    );
  }

  /// 이대로 가져올 수 없으면 그 이유. 가져올 수 있으면 null.
  String? get problem {
    final hasAmount = typeMode == ImportTypeMode.split
        ? expenseAmount >= 0 || incomeAmount >= 0
        : amount >= 0;
    if (date < 0 && !hasAmount) return '날짜와 금액 열을 정해주세요.';
    if (date < 0) return '날짜 열을 정해주세요.';
    if (!hasAmount) return '금액 열을 정해주세요.';
    if (typeMode == ImportTypeMode.column && type < 0) {
      return '수입/지출을 구분할 열을 정해주세요.';
    }
    return null;
  }

  ImportMapping copyWith({
    int? date,
    int? amount,
    int? time,
    int? category,
    int? place,
    int? description,
    int? memo,
    int? type,
    int? expenseAmount,
    int? incomeAmount,
    ImportTypeMode? typeMode,
  }) => ImportMapping(
    date: date ?? this.date,
    amount: amount ?? this.amount,
    time: time ?? this.time,
    category: category ?? this.category,
    place: place ?? this.place,
    description: description ?? this.description,
    memo: memo ?? this.memo,
    type: type ?? this.type,
    expenseAmount: expenseAmount ?? this.expenseAmount,
    incomeAmount: incomeAmount ?? this.incomeAmount,
    typeMode: typeMode ?? this.typeMode,
  );
}

/// 헤더 이름으로 열을 추측한다. **정확히 같은 이름을 먼저** 찾고, 없으면 포함하는 이름을 찾는다.
/// (포함만 보면 '금액'을 찾을 때 '수입/지출' 같은 열이 먼저 잡히는 일이 있었다)
int guessColumn(List<String> headers, List<String> keywords) {
  final exact = _exactColumn(headers, keywords);
  if (exact >= 0) return exact;
  final lower = [for (final h in headers) h.toLowerCase().trim()];
  for (final (i, h) in lower.indexed) {
    if (keywords.any((k) => h.contains(k.toLowerCase()))) return i;
  }
  return -1;
}

int _exactColumn(List<String> headers, List<String> keywords) {
  for (final (i, h) in headers.indexed) {
    final t = h.toLowerCase().trim();
    if (keywords.any((k) => t == k.toLowerCase())) return i;
  }
  return -1;
}

const _dateKeys = ['날짜', '일자', 'date', '거래일', '일시', '이용일', '사용일', '결제일'];
const _timeKeys = ['시간', '시각', 'time'];
const _amountKeys = ['금액', 'amount'];
const _expenseKeys = ['출금액', '출금', '지출 금액', '지출금액', '지출액', '찾으신금액', '찾으신 금액'];
const _incomeKeys = ['입금액', '입금', '수입 금액', '수입금액', '수입액', '맡기신금액', '맡기신 금액'];
const _typeKeys = ['수입/지출', '구분', '수입지출', 'type', '입출금'];
const _categoryKeys = ['카테고리', '분류', 'category'];
const _placeKeys = ['구매처', '가맹점', '상호', '장소', '사용처', '이용처', '거래처'];
const _descriptionKeys = ['내용', '내역', '품명', '상품', '적요'];
const _memoKeys = ['메모', '비고', 'note'];

const _allKeys = [
  ..._dateKeys,
  ..._timeKeys,
  ..._amountKeys,
  ..._expenseKeys,
  ..._incomeKeys,
  ..._typeKeys,
  ..._categoryKeys,
  ..._placeKeys,
  ..._descriptionKeys,
  ..._memoKeys,
];

bool _isDateLike(Object? v) =>
    v is DateTime || (v is String && parseDateCell(v) != null);

/// 글자로 된 칸(날짜·숫자가 아닌 것)인지. 헤더 줄을 찾을 때 쓴다.
bool _isLabel(Object? v) {
  final t = _text(v);
  return t.isNotEmpty &&
      v is! num &&
      v is! DateTime &&
      parseDateCell(t) == null &&
      parseAmountCell(t) == null;
}

/// 시트에서 항목 이름(헤더)이 있는 줄을 추측한다.
/// 위에 제목·기간 줄이 있는 파일(은행·카드사 내역 등)을 위해 앞쪽 30줄에서
/// 아는 항목 이름이 가장 많은 줄을 고른다. 없으면 바로 아래에 날짜가 있는 글자 줄, 그것도 없으면 첫 줄.
int guessHeaderRow(List<List<Object?>> all) {
  final limit = all.length < 30 ? all.length : 30;
  var best = -1;
  var bestScore = 0;
  for (var i = 0; i < limit; i++) {
    final score = all[i].where((c) {
      if (!_isLabel(c)) return false;
      final t = _text(c).toLowerCase();
      return _allKeys.any((k) => t.contains(k.toLowerCase()));
    }).length;
    if (score > bestScore) {
      best = i;
      bestScore = score;
    }
  }
  if (best >= 0) return best;
  for (var i = 0; i + 1 < limit; i++) {
    if (all[i].where(_isLabel).length >= 2 && all[i + 1].any(_isDateLike)) {
      return i;
    }
  }
  return 0;
}

/// 헤더 이름으로 못 찾았을 때 값을 보고 찾는다: 앞쪽 20줄의 채워진 칸 중 절반 넘게 [test]를 만족하는 첫 열.
int _guessByValues(ImportTable t, bool Function(Object?) test, Set<int> taken) {
  final sample = t.rows.take(20).toList();
  for (var col = 0; col < t.columnCount; col++) {
    if (taken.contains(col)) continue;
    final filled = [
      for (final r in sample)
        if (_text(t.cell(r, col)).isNotEmpty) t.cell(r, col),
    ];
    if (filled.isEmpty) continue;
    if (filled.where(test).length * 2 > filled.length) return col;
  }
  return -1;
}

/// 헤더(와 값)를 보고 추측한 기본 열 연결.
/// - 구분 열이 있고 금액에 음수가 없으면 "별도 열로"(편한가계부처럼 금액이 항상 양수인 파일).
/// - "금액" 열이 없고 출금액·입금액 열이 있으면 "지출·수입 금액 열이 따로".
ImportMapping guessMapping(ImportTable table) {
  int guess(List<String> keys) => guessColumn(table.headers, keys);
  var date = guess(_dateKeys);
  var time = guess(_timeKeys);
  if (time == date) time = -1;
  final taken = <int>{};
  if (date < 0) {
    date = _guessByValues(table, _isDateLike, taken);
  }
  if (date >= 0) taken.add(date);

  var amount = _exactColumn(table.headers, _amountKeys);
  var expense = -1;
  var income = -1;
  if (amount < 0) {
    expense = guess(_expenseKeys);
    income = guess(_incomeKeys);
    if (expense == income) income = -1;
    if (expense < 0 && income < 0) amount = guess(_amountKeys);
  }
  if (amount < 0 && expense < 0 && income < 0) {
    amount = _guessByValues(
      table,
      (v) => v is! DateTime && parseAmountCell(v) != null,
      taken,
    );
  }
  final split = expense >= 0 || income >= 0;
  final type = split ? -1 : guess(_typeKeys);
  final hasNegative =
      amount >= 0 &&
      table.rows.any((r) => (parseAmountCell(table.cell(r, amount)) ?? 0) < 0);
  return ImportMapping(
    date: date,
    time: time,
    amount: split ? -1 : amount,
    expenseAmount: expense,
    incomeAmount: income,
    category: guess(_categoryKeys),
    place: guess(_placeKeys),
    description: guess(_descriptionKeys),
    memo: guess(_memoKeys),
    type: type,
    typeMode: split
        ? ImportTypeMode.split
        : type >= 0 && amount >= 0 && !hasNegative
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
  final time = _timeOfText(s.substring(ymd.end));
  return (date: '$y-${_two(m)}-${_two(d)}', time: time);
}

/// 글자에서 '12:30', '오후 3:20' 같은 시각을 찾는다.
String? _timeOfText(String s) {
  final t = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
  if (t == null) return null;
  var h = int.parse(t[1]!);
  final min = int.parse(t[2]!);
  if (RegExp(r'오후|PM', caseSensitive: false).hasMatch(s) && h < 12) h += 12;
  if (RegExp(r'오전|AM', caseSensitive: false).hasMatch(s) && h == 12) h = 0;
  return h < 24 && min < 60 ? '${_two(h)}:${_two(min)}' : null;
}

/// 시간 칸을 읽는다(시간 열이 따로 있는 파일). DateTime, 엑셀 시각 숫자(하루의 몇 분의 몇),
/// '12:30', '오후 3:20', '12:30:00'. 읽지 못하면 null.
String? parseTimeCell(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return '${_two(raw.hour)}:${_two(raw.minute)}';
  if (raw is num) {
    if (raw < 0) return null;
    final minutes = ((raw - raw.floor()) * 24 * 60).round() % (24 * 60);
    return '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
  }
  return _timeOfText(raw.toString());
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
/// 지출·수입 금액 열이 따로 있는 파일에서 한 줄에 둘 다 적혀 있으면 두 건으로 읽는다.
ImportParseResult parseImportRows(ImportTable table, ImportMapping m) {
  final rows = <ImportRow>[];
  var skipped = 0;
  for (final r in table.rows) {
    final when = parseDateCell(table.cell(r, m.date));
    final amounts = <(EntryKind, num)>[];
    if (when != null) {
      if (m.typeMode == ImportTypeMode.split) {
        final e = parseAmountCell(table.cell(r, m.expenseAmount)) ?? 0;
        final i = parseAmountCell(table.cell(r, m.incomeAmount)) ?? 0;
        if (e != 0) amounts.add((EntryKind.expense, e));
        if (i != 0) amounts.add((EntryKind.income, i));
      } else {
        final raw = parseAmountCell(table.cell(r, m.amount)) ?? 0;
        if (raw != 0) {
          final kind = switch (m.typeMode) {
            ImportTypeMode.column =>
              RegExp(
                    r'수입|입금|income',
                    caseSensitive: false,
                  ).hasMatch(_text(table.cell(r, m.type)))
                  ? EntryKind.income
                  : EntryKind.expense,
            ImportTypeMode.allExpense => EntryKind.expense,
            _ => raw < 0 ? EntryKind.expense : EntryKind.income,
          };
          amounts.add((kind, raw));
        }
      }
    }
    if (when == null || amounts.isEmpty) {
      skipped++;
      continue;
    }
    final time =
        (m.time >= 0 ? parseTimeCell(table.cell(r, m.time)) : null) ??
        when.time ??
        '12:00';
    for (final (kind, amount) in amounts) {
      rows.add(
        ImportRow(
          kind: kind,
          date: when.date,
          time: time,
          amount: amount.abs().round(),
          categoryRaw: _text(table.cell(r, m.category)),
          // 구매처는 지출에만 있다.
          place: kind == EntryKind.expense ? _text(table.cell(r, m.place)) : '',
          description: _text(table.cell(r, m.description)),
          memo: _text(table.cell(r, m.memo)),
        ),
      );
    }
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
