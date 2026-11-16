import 'dart:math' as math;

import '../core/dates.dart';

/// 영수증 사진에서 읽은 글자 한 줄과 화면 속 위치(글자 인식기가 준 그대로).
/// [angle]은 글자 줄의 기울기(도). 사진이 기울어 있으면 0이 아니다.
class OcrLine {
  const OcrLine(
    this.text,
    this.left,
    this.top,
    this.right,
    this.bottom, {
    this.angle = 0,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double angle;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;

  /// 진단용 한 줄: 글자와 위치(잘못 읽은 영수증을 테스트로 재현할 때 쓴다).
  String get debugText =>
      '${left.round()},${top.round()},${right.round()},${bottom.round()},'
      '${angle.toStringAsFixed(1)}|$text';
}

/// 글자 인식기는 영수증의 열(품명·수량·금액)을 따로 읽는 일이 많다.
/// 같은 높이의 조각을 한 줄로 모으고, 왼쪽부터 두 칸 띄워 잇는다.
/// - 사진이 기울어 있으면 조각들의 기울기(중앙값)만큼 높이를 보정한다.
/// - **가로로 겹치는 조각은 같은 줄로 묶지 않는다**: 위아래로 붙은 두 줄(상호·주소)이
///   섞이던 문제(빌드 26)를 막는다. 한 줄 안의 조각은 서로 옆에 있어야 한다.
/// - 들어갈 줄이 여럿이면 높이가 가장 가까운 줄로.
List<String> rowsFromLines(List<OcrLine> lines) {
  final live = [
    for (final l in lines)
      if (l.text.trim().isNotEmpty) l,
  ];
  if (live.isEmpty) return const [];
  final angles = [for (final l in live) l.angle]..sort();
  final slope = math.tan(angles[angles.length ~/ 2] * math.pi / 180);
  // 기울기 값의 방향(시계/반시계)을 문서로 확신할 수 없어서, 보정 없음과 양쪽 방향으로
  // 모두 묶어 보고 줄이 가장 적게(옆 조각이 가장 잘 붙게) 나오는 쪽을 쓴다.
  var best = _groupRows(live, 0);
  for (final s in [slope, -slope]) {
    if (s == 0) continue;
    final rows = _groupRows(live, s);
    if (rows.length < best.length) best = rows;
  }
  return best;
}

List<String> _groupRows(List<OcrLine> live, double slope) {
  double level(OcrLine l) => l.centerY - l.centerX * slope;
  final heights = [for (final l in live) l.height]..sort();
  final tolerance = heights[heights.length ~/ 2] * 0.5;
  final sorted = [...live]..sort((a, b) => level(a).compareTo(level(b)));

  final rows = <List<OcrLine>>[];
  final rowLevel = <double>[];
  for (final line in sorted) {
    final y = level(line);
    int? best;
    var bestGap = double.infinity;
    for (var i = rows.length - 1; i >= 0 && i >= rows.length - 4; i--) {
      final gap = (y - rowLevel[i]).abs();
      if (gap > tolerance || gap >= bestGap) continue;
      final overlaps = rows[i].any(
        (o) => line.left < o.right && o.left < line.right,
      );
      if (overlaps) continue;
      best = i;
      bestGap = gap;
    }
    if (best == null) {
      rows.add([line]);
      rowLevel.add(y);
    } else {
      rows[best].add(line);
      rowLevel[best] =
          rows[best].map(level).reduce((a, b) => a + b) / rows[best].length;
    }
  }
  final order = [for (var i = 0; i < rows.length; i++) i]
    ..sort((a, b) => rowLevel[a].compareTo(rowLevel[b]));
  return [
    for (final i in order)
      (rows[i]..sort((a, b) => a.left.compareTo(b.left)))
          .map((l) => l.text.trim())
          .join('  '),
  ];
}

/// 영수증의 품목 한 줄.
class ReceiptItem {
  const ReceiptItem({
    required this.key,
    required this.name,
    required this.amount,
  });

  /// 같은 상품을 알아보는 열쇠(기억하기에 쓴다). 순번·띄어쓰기·대소문자를 뺀 원래 이름.
  final String key;

  /// 보여줄 이름(정리한 이름 또는 기억해 둔 이름).
  final String name;

  /// 이 품목의 금액(수량을 곱한 줄 금액).
  final int amount;

  ReceiptItem copyWith({String? name, int? amount}) => ReceiptItem(
    key: key,
    name: name ?? this.name,
    amount: amount ?? this.amount,
  );
}

/// 영수증에서 찾은 값. 못 찾은 값은 null(화면에서 오늘·빈 칸으로 둔다).
class ReceiptScan {
  const ReceiptScan({
    required this.rows,
    this.total,
    this.date,
    this.time,
    this.place,
    this.items = const [],
    this.unpricedNames = const [],
    this.fragments = const [],
  });

  /// 인식된 글자(줄 단위). "인식된 글자 보기"에 그대로 보여준다.
  final List<String> rows;

  /// 글자 조각과 위치(진단용, "인식된 글자 복사"에 함께 담는다).
  final List<String> fragments;

  /// 가격 없이 이름(과 수량)만 있는 품목들. 품목 칸에 금액이 없는 영수증(카페 등)용.
  final List<String> unpricedNames;

  /// 결제 금액(할인이 반영된 금액).
  final int? total;
  final DateTime? date;

  /// 'HH:mm'
  final String? time;
  final String? place;
  final List<ReceiptItem> items;
}

// ── 값 찾기 ─────────────────────────────────────────────────────────────

/// 결제 금액을 나타내는 말. 앞 묶음일수록 우선한다(할인 뒤 금액이 먼저).
const _totalKeywords = [
  ['받을금액', '결제금액', '결제할금액', '승인금액', '청구금액', '카드결제', '신용카드', '결제액'],
  ['합계금액', '판매합계', '총합계', '총구매액', '총금액', '총액', '합계', 'total'],
];

/// 금액처럼 보여도 결제 금액이 아닌 줄.
const _notTotalKeywords = [
  '부가세',
  '부가가치세',
  '과세',
  '면세',
  '공급가',
  '할인',
  '받은',
  '거스름',
  '잔액',
  '잔돈',
  '포인트',
  '적립',
  '봉사료',
  '쿠폰',
];

/// 품목 목록이 시작되는 머리줄.
const _headerKeywords = ['상품명', '품명', '품목', '메뉴', '상품코드'];

/// 품목 앞쪽(가게 정보)에 나오는 줄.
const _shopInfoKeywords = [
  '사업자',
  '대표',
  '전화',
  'tel',
  '주소',
  '일시',
  '일자',
  'pos',
  '영수증',
  '계산원',
  '판매원',
  '캐셔',
];

/// 품목이 끝나는 줄.
const _itemsEndKeywords = [
  '합계',
  '결제',
  '과세',
  '면세',
  '부가세',
  '공급가',
  '받을',
  '소계',
  '총구매',
  '총액',
  '총금액',
];

/// 품목이 아닌 줄.
const _notItemKeywords = ['할인', '쿠폰', '포인트', '적립', '에누리', '단가', '수량', '금액'];

/// 구매처가 아닌 줄(맨 위쪽에서 상호를 찾을 때 건너뛴다).
const _notPlaceKeywords = [
  '영수증',
  '사업자',
  '대표',
  '주소',
  '전화',
  'tel',
  '번호',
  '일시',
  '날짜',
  '카드',
  '고객',
  '감사',
  '환영',
  'pos',
  '계산',
  '교환',
  '환불',
  '매출',
  '전표',
  '거래',
];

String _compact(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

bool _hasAny(String row, List<String> words) {
  final c = _compact(row);
  return words.any(c.contains);
}

final _datePatterns = [
  RegExp(r'(20\d{2})\s*[-./년]\s*(\d{1,2})\s*[-./월]\s*(\d{1,2})'),
  RegExp(r'(?<![\d-])(\d{2})[-./](\d{1,2})[-./](\d{1,2})(?![\d])'),
];
final _timePattern = RegExp(r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?');

/// 금액이 아닌 숫자 덩어리(날짜·시각·전화번호·사업자번호·카드번호·바코드)를 지운다.
String _withoutNonMoney(String row) => row
    .replaceAll(_datePatterns[0], ' ')
    .replaceAll(_datePatterns[1], ' ')
    .replaceAll(_timePattern, ' ')
    .replaceAll(RegExp(r'\d{2,4}-\d{3,4}-\d{4}'), ' ')
    .replaceAll(RegExp(r'\d{3}-\d{2}-\d{5}'), ' ')
    // 카드번호(가운데가 *로 가려진 것)
    .replaceAllMapped(
      RegExp(r'[\d*]{4}[-\s]?[\d*]{2,4}[-\s]?[\d*]{2,4}[-\s]?[\d*]{2,4}'),
      (m) => m[0]!.contains('*') ? ' ' : m[0]!,
    )
    .replaceAll(RegExp(r'\d{8,}'), ' ');

final _moneyToken = RegExp(
  r'-?\d{1,3}(?:[,.]\d{3})+(?![\d])|-?\d{1,7}(?![\d,.])',
);

/// 줄 안의 금액들(왼쪽부터). 음수는 음수로.
List<int> _moneyIn(String row) => [
  for (final m in _moneyToken.allMatches(_withoutNonMoney(row)))
    int.parse(m[0]!.replaceAll(RegExp(r'[,.]'), '')),
];

/// 영수증 글자(줄 단위)에서 결제 금액·날짜·시간·구매처·품목을 찾는다.
/// [today]보다 뒤이거나 1년 넘게 지난 날짜는 잘못 읽은 것으로 보고 버린다.
///
/// 결제 금액: 결제 금액을 뜻하는 말 → 영수증에 여러 번 나오는 금액(합계·결제금액·카드 승인
/// 금액이 같은 숫자로 반복된다) → 품목 합계 → 가장 큰 금액 순.
/// 가격 없이 이름만 있는 품목이 하나뿐이면 결제 금액을 그 품목 금액으로 쓴다.
ReceiptScan parseReceipt(
  List<String> rows, {
  required DateTime today,
  List<String> fragments = const [],
}) {
  final (date, time) = _findDateTime(rows, dateOnly(today));
  var (items, unpriced) = _findItems(rows);
  final total =
      _findTotal(rows) ??
      _repeatedAmount(rows) ??
      (items.isNotEmpty ? items.fold<int>(0, (s, i) => s + i.amount) : null) ??
      _largestAmount(rows);
  if (items.isEmpty && unpriced.length == 1 && total != null) {
    final name = unpriced.single;
    items = [
      ReceiptItem(
        key: itemKeyOf(name),
        name: cleanItemName(name),
        amount: total,
      ),
    ];
    unpriced = const [];
  }
  return ReceiptScan(
    rows: rows,
    fragments: fragments,
    total: total,
    date: date,
    time: time,
    place: _findPlace(rows),
    items: items,
    unpricedNames: items.isEmpty
        ? [for (final n in unpriced) cleanItemName(n)]
        : const [],
  );
}

/// 두 번 이상 나오는 금액 중 가장 자주 나오는 것(같으면 큰 것). 100원 미만은 수량일 수 있어 뺀다.
int? _repeatedAmount(List<String> rows) {
  final counts = <int, int>{};
  for (final row in rows) {
    if (_hasAny(row, _notTotalKeywords)) continue;
    for (final v in _moneyIn(row)) {
      if (v >= 100 && v < 10000000) counts[v] = (counts[v] ?? 0) + 1;
    }
  }
  final repeated = counts.entries.where((e) => e.value >= 2).toList()
    ..sort((a, b) => b.value != a.value ? b.value - a.value : b.key - a.key);
  return repeated.firstOrNull?.key;
}

int? _findTotal(List<String> rows) {
  for (final group in _totalKeywords) {
    // 같은 묶음이 여러 번 나오면 아래쪽(최종 금액)을 쓴다.
    for (var i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      if (!_hasAny(row, group) || _hasAny(row, _notTotalKeywords)) continue;
      final here = _moneyIn(row).where((v) => v > 0);
      if (here.isNotEmpty) return here.last;
      if (i + 1 < rows.length) {
        final next = _moneyIn(rows[i + 1]).where((v) => v > 0);
        if (next.isNotEmpty) return next.first;
      }
    }
  }
  return null;
}

int? _largestAmount(List<String> rows) {
  int? best;
  for (final row in rows) {
    if (_hasAny(row, _notTotalKeywords)) continue;
    for (final v in _moneyIn(row)) {
      if (v >= 10 && v < 10000000 && (best == null || v > best)) best = v;
    }
  }
  return best;
}

(DateTime?, String?) _findDateTime(List<String> rows, DateTime today) {
  DateTime? date;
  String? time;
  // "거래일시·승인일시" 줄을 먼저 본다.
  final ordered = [
    ...rows.where((r) => _hasAny(r, ['일시', '일자', '거래일', '승인일', '판매일'])),
    ...rows,
  ];
  for (final row in ordered) {
    if (date == null) {
      for (final p in _datePatterns) {
        final m = p.firstMatch(row);
        if (m == null) continue;
        var y = int.parse(m[1]!);
        if (y < 100) y += 2000;
        final mo = int.parse(m[2]!);
        final d = int.parse(m[3]!);
        if (mo < 1 || mo > 12 || d < 1 || d > 31) continue;
        final candidate = DateTime(y, mo, d);
        if (candidate.month != mo) continue; // 2월 30일 같은 날짜
        if (candidate.isAfter(today) ||
            candidate.isBefore(
              DateTime(today.year - 1, today.month, today.day),
            )) {
          continue;
        }
        date = candidate;
        break;
      }
    }
    if (time == null) {
      final m = _timePattern.firstMatch(row);
      if (m != null) {
        time = '${m[1]!.padLeft(2, '0')}:${m[2]}';
      }
    }
    if (date != null && time != null) break;
  }
  return (date, date == null ? null : time);
}

/// 상호 앞뒤에 붙는 말을 뺀다.
String cleanPlaceName(String s) => s
    .replaceAll(RegExp(r'\(주\)|㈜|주식회사|\(유\)|유한회사'), ' ')
    .replaceAll(RegExp(r'[\[\]<>【】「」*=]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String? _findPlace(List<String> rows) {
  for (final row in rows) {
    // "가맹점번호 : 199432256"처럼 번호를 뜻하는 줄은 상호가 아니다.
    final m = RegExp(r'(상호|가맹점명|가맹점(?!번호)|매장명|점포명|상\s*호)\s*[:：]?\s*(.+)')
        .firstMatch(row);
    if (m != null) {
      final name = cleanPlaceName(m[2]!.split(RegExp(r'\s{2,}')).first);
      final letters = RegExp(r'[가-힣A-Za-z]').allMatches(name).length;
      final digits = RegExp(r'\d').allMatches(name).length;
      if (letters >= 2 && digits <= letters) return name;
    }
  }
  for (final row in rows.take(6)) {
    if (_hasAny(row, _notPlaceKeywords)) continue;
    final letters = RegExp(r'[가-힣A-Za-z]').allMatches(row).length;
    final digits = RegExp(r'\d').allMatches(row).length;
    if (letters < 2 || digits > letters) continue;
    final name = cleanPlaceName(row);
    if (name.isNotEmpty) return name;
  }
  return null;
}

final _numericWord = RegExp(r'^-?[\d,.]+원?$');

/// 품목 이름을 정리한다: 순번, 앞쪽 표시(P)·CJ)·(행사)), 용량·수량(1000ML·210g·*3·1+1)을 뺀다.
/// 다 빼서 아무것도 안 남으면 원래 이름을 쓴다.
String cleanItemName(String raw) {
  final original = raw.trim();
  var s = ' $original ';
  s = s.replaceFirst(RegExp(r'^\s*\d{1,3}[\s.)]+'), ' ');
  s = s.replaceAll(RegExp(r'\d{8,}'), ' ');
  s = s.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]|<[^>]*>'), ' ');
  s = s.replaceAll(RegExp(r'(?<=\s)[A-Za-z가-힣]{1,3}\)'), ' ');
  s = s.replaceAll(RegExp(r'\d+\s*\+\s*\d+'), ' ');
  s = s.replaceAll(
    RegExp(
      r'\d+(\.\d+)?\s*(ml|l|g|kg|mg|cm|mm|m|입|개입|개|매|팩|봉|구|ea|p|롤|병|캔|박스|box)(?![a-z가-힣])',
      caseSensitive: false,
    ),
    ' ',
  );
  s = s.replaceAll(RegExp(r'[*xX×]\s*\d+'), ' ');
  s = s.replaceAll(RegExp(r'[*#]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty || !RegExp(r'[가-힣A-Za-z]').hasMatch(s) ? original : s;
}

/// 같은 상품을 알아보는 열쇠: 순번·바코드·띄어쓰기를 빼고 소문자로.
String itemKeyOf(String raw) => _compact(
  raw
      .replaceFirst(RegExp(r'^\s*\d{1,3}[\s.)]+'), '')
      .replaceAll(RegExp(r'\d{8,}'), ''),
);

/// 구매처를 알아보는 열쇠.
String placeKeyOf(String place) => _compact(cleanPlaceName(place));

/// 한 줄을 (이름, 금액)으로 나눈다. 끝쪽 숫자들(단가·수량·금액) 중 맨 오른쪽이 금액.
(String, int?) _splitItemRow(String row) {
  final words = _withoutNonMoney(row)
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final numbers = <String>[];
  while (words.isNotEmpty && _numericWord.hasMatch(words.last)) {
    numbers.insert(0, words.removeLast());
  }
  final name = words.join(' ');
  if (numbers.isEmpty) return (name, null);
  final last = numbers.last.replaceAll('원', '');
  if (last.startsWith('-')) return (name, -1);
  return (name, int.tryParse(last.replaceAll(RegExp(r'[,.]'), '')));
}

bool _hasLetters(String s) => RegExp(r'[가-힣A-Za-z]').hasMatch(s);

/// 품목(이름 + 금액)과, 가격 없이 이름(과 수량)만 있는 품목 이름들.
(List<ReceiptItem>, List<String>) _findItems(List<String> rows) {
  var start = rows.indexWhere((r) => _hasAny(r, _headerKeywords));
  var end = rows.length;
  for (var i = (start < 0 ? 0 : start + 1); i < rows.length; i++) {
    if (_hasAny(rows[i], _itemsEndKeywords)) {
      end = i;
      break;
    }
  }
  if (start < 0) {
    // 머리줄이 없으면 가게 정보·날짜 줄 다음부터.
    start = -1;
    for (var i = 0; i < end; i++) {
      final r = rows[i];
      if (_hasAny(r, _shopInfoKeywords) ||
          _datePatterns.any((p) => p.hasMatch(r)) ||
          _timePattern.hasMatch(r)) {
        start = i;
      }
    }
  }

  final items = <ReceiptItem>[];
  final unpriced = <String>[];
  String? pendingName;
  for (var i = start + 1; i < end; i++) {
    final row = rows[i];
    // "주문번호 : …", "카드번호 : …"처럼 쌍점이 있는 줄은 품목이 아니다.
    if (_hasAny(row, _notItemKeywords) || row.contains(':')) {
      pendingName = null;
      continue;
    }
    var (name, amount) = _splitItemRow(row);
    // 이름만 있는 줄 다음에 숫자만 있는 줄이 오면 한 품목으로 본다.
    if (amount == null) {
      pendingName = _hasLetters(name) ? name : null;
      continue;
    }
    if (!_hasLetters(name) && pendingName != null) name = pendingName;
    pendingName = null;
    if (!_hasLetters(name) || amount < 0 || amount >= 10000000) continue;
    // 100원 미만은 가격이 아니라 수량으로 본다("아메리카노 HOT  1").
    if (amount < 100) {
      unpriced.add(name);
      continue;
    }
    items.add(
      ReceiptItem(
        key: itemKeyOf(name),
        name: cleanItemName(name),
        amount: amount,
      ),
    );
  }
  return (items, unpriced);
}

// ── 나눠 저장하기 ──────────────────────────────────────────────────────────

/// 저장할 내역 한 건(카테고리 하나).
class ReceiptEntryPlan {
  const ReceiptEntryPlan({
    required this.categoryId,
    required this.amount,
    required this.description,
    required this.memo,
  });

  final int categoryId;
  final int amount;
  final String description;
  final String memo;
}

/// 나눠 저장한 결과와, 결제 금액과 품목 합계의 차이를 어디에 반영했는지.
class ReceiptPlan {
  const ReceiptPlan(
    this.entries, {
    this.adjustment = 0,
    this.adjustedCategoryId,
  });

  final List<ReceiptEntryPlan> entries;

  /// 품목 합계 − 결제 금액. 양수면 할인으로 뺀 금액, 음수면 더한 금액.
  final int adjustment;
  final int? adjustedCategoryId;
}

/// 내역 칸: 첫 품목 이름 + "외 N건".
String receiptDescription(List<ReceiptItem> items) => items.isEmpty
    ? ''
    : items.length == 1
    ? items.first.name
    : '${items.first.name} 외 ${items.length - 1}건';

/// 메모 칸: "빵 3,500 / 우유 2,800".
String receiptMemo(List<ReceiptItem> items) =>
    items.map((i) => '${i.name} ${formatNumber(i.amount)}').join(' / ');

/// 품목을 카테고리별로 묶어 저장할 내역을 만든다.
/// - 카테고리가 하나면 결제 금액([total])을 그대로 쓴다(할인이 이미 반영된 금액).
/// - 여러 개면 묶음별 품목 합계로 나누고, 결제 금액과의 차이는 금액이 가장 큰
///   묶음에서 한 번에 빼거나 더한다(비율로 나누지 않는다).
/// - 품목이 없으면 [fallbackCategoryId]로 결제 금액 한 건. 가격 없는 품목 이름
///   ([unpricedNames])이 있으면 내역은 "첫 이름 외 N건", 메모는 이름 목록.
/// [categoryOf]는 품목 순서대로의 카테고리 id.
ReceiptPlan planReceiptEntries({
  required List<ReceiptItem> items,
  required List<int> categoryOf,
  required int total,
  int? fallbackCategoryId,
  List<String> unpricedNames = const [],
}) {
  if (items.isEmpty) {
    if (fallbackCategoryId == null) return const ReceiptPlan([]);
    final names = unpricedNames;
    return ReceiptPlan([
      ReceiptEntryPlan(
        categoryId: fallbackCategoryId,
        amount: total,
        description: names.isEmpty
            ? ''
            : names.length == 1
            ? names.first
            : '${names.first} 외 ${names.length - 1}건',
        memo: names.join(' / '),
      ),
    ]);
  }
  final groups = <int, List<ReceiptItem>>{};
  for (final (i, item) in items.indexed) {
    groups.putIfAbsent(categoryOf[i], () => []).add(item);
  }
  int sum(List<ReceiptItem> list) => list.fold(0, (s, i) => s + i.amount);

  if (groups.length == 1) {
    final MapEntry(key: id, value: list) = groups.entries.single;
    return ReceiptPlan([
      ReceiptEntryPlan(
        categoryId: id,
        amount: total,
        description: receiptDescription(list),
        memo: receiptMemo(list),
      ),
    ], adjustment: sum(list) - total);
  }

  final amounts = {for (final e in groups.entries) e.key: sum(e.value)};
  final adjustment = sum(items) - total;
  int? largest;
  if (adjustment != 0) {
    largest = amounts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    amounts[largest] = amounts[largest]! - adjustment;
  }
  return ReceiptPlan(
    [
      for (final e in groups.entries)
        ReceiptEntryPlan(
          categoryId: e.key,
          amount: amounts[e.key]!,
          description: receiptDescription(e.value),
          memo: receiptMemo(e.value),
        ),
    ],
    adjustment: adjustment,
    adjustedCategoryId: largest,
  );
}
