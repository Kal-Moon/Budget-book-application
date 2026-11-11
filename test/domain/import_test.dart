import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/domain/import.dart';

/// 편한가계부 내보내기 파일의 열 구성.
const pyeonhanHeaders = [
  '날짜',
  '자산',
  '분류',
  '소분류',
  '내용',
  'KRW',
  '수입/지출',
  '메모',
  '금액',
  '화폐',
  '자산',
];

ImportTable pyeonhan(List<List<Object?>> rows) =>
    ImportTable([pyeonhanHeaders, ...rows]);

void main() {
  group('열 추측', () {
    test('정확히 같은 이름이 먼저다: "금액"을 찾을 때 "수입/지출"이 잡히지 않는다', () {
      expect(guessColumn(['수입/지출 금액', '금액'], ['금액']), 1);
      expect(guessColumn(['거래 금액'], ['금액']), 0, reason: '없으면 포함으로');
      expect(guessColumn(['이름'], ['금액']), -1);
    });

    test('편한가계부: 금액은 I열, 구분은 G열, 금액이 모두 양수라 "별도 열로"', () {
      final m = guessMapping(
        pyeonhan([
          [
            '2026-11-08',
            '현금',
            '식비',
            '',
            '점심',
            12000,
            '지출',
            '',
            12000,
            'KRW',
            12000,
          ],
        ]),
      );
      expect(m.date, 0);
      expect(m.amount, 8);
      expect(m.category, 2);
      expect(m.description, 4);
      expect(m.memo, 7);
      expect(m.type, 6);
      expect(m.typeMode, ImportTypeMode.column);
    });

    test('금액에 음수가 있으면 "금액 부호로"', () {
      final m = guessMapping(
        ImportTable([
          ['날짜', '금액', '구분'],
          ['2026-11-08', -5000, '지출'],
        ]),
      );
      expect(m.typeMode, ImportTypeMode.sign);
    });

    test('빈 헤더는 "N열"로, 완전히 빈 줄은 버린다', () {
      final t = ImportTable([
        ['날짜', '', '금액'],
        ['', null, ''],
        ['2026-11-08', 'x', 1],
      ]);
      expect(t.headers, ['날짜', '2열', '금액']);
      expect(t.rows, hasLength(1));
    });
  });

  group('날짜 읽기', () {
    test('여러 글자 형식', () {
      expect(parseDateCell('2026-11-08')!.date, '2026-11-08');
      expect(parseDateCell('2026.1.5')!.date, '2026-01-05');
      expect(parseDateCell('2026/11/08')!.date, '2026-11-08');
      expect(parseDateCell('2026년 11월 8일')!.date, '2026-11-08');
      expect(parseDateCell('11/08/2026')!.date, '2026-11-08');
    });

    test('시간이 붙어 있으면 함께 읽는다', () {
      final a = parseDateCell('2026-11-08 19:05:33')!;
      expect((a.date, a.time), ('2026-11-08', '19:05'));
      expect(parseDateCell('2026-11-08 오후 7:05')!.time, '19:05');
      expect(parseDateCell('2026-11-08')!.time, isNull);
    });

    test('DateTime과 엑셀 날짜 숫자', () {
      final a = parseDateCell(DateTime(2026, 11, 8, 9, 30))!;
      expect((a.date, a.time), ('2026-11-08', '09:30'));
      // 46334 = 2026-11-08
      expect(parseDateCell(46334)!.date, '2026-11-08');
      final b = parseDateCell(46334.5)!;
      expect((b.date, b.time), ('2026-11-08', '12:00'));
    });

    test('읽을 수 없거나 없는 날짜는 null', () {
      expect(parseDateCell(''), isNull);
      expect(parseDateCell('합계'), isNull);
      expect(parseDateCell('2026-13-01'), isNull);
      expect(parseDateCell('2026-02-30'), isNull);
      expect(parseDateCell(null), isNull);
    });
  });

  test('금액 읽기: 쉼표·원·부호·괄호', () {
    expect(parseAmountCell('12,000원'), 12000);
    expect(parseAmountCell('-3,500'), -3500);
    expect(parseAmountCell('(3,500)'), -3500);
    expect(parseAmountCell('+800'), 800);
    expect(parseAmountCell(4500.0), 4500);
    expect(parseAmountCell('금액'), isNull);
    expect(parseAmountCell(''), isNull);
  });

  group('내역으로 읽기', () {
    final table = pyeonhan([
      [
        '2026-11-08 12:30',
        '현금',
        '식비',
        '',
        '점심',
        12000,
        '지출',
        '맛있음',
        12000,
        'KRW',
        12000,
      ],
      [
        '2026-11-01',
        '통장',
        '월급',
        '',
        '11월 급여',
        2000000,
        '수입',
        '',
        2000000,
        'KRW',
        2000000,
      ],
      ['2026-11-02', '현금', '', '', '분류 없음', 3000, '지출', '', 3000, 'KRW', 3000],
      ['합계', '', '', '', '', '', '', '', 2015000, '', ''],
      ['2026-11-03', '현금', '카페', '', '공짜', 0, '지출', '', 0, 'KRW', 0],
    ]);

    test('별도 열로: 구분 열의 글자로 지출·수입을 나누고, 못 읽는 줄은 건너뛴다', () {
      final r = parseImportRows(table, guessMapping(table));
      expect(r.rows, hasLength(3));
      expect(r.skipped, 2, reason: '합계 줄 + 0원');
      final lunch = r.rows.first;
      expect(lunch.kind, EntryKind.expense);
      expect((lunch.date, lunch.time), ('2026-11-08', '12:30'));
      expect(
        (lunch.amount, lunch.description, lunch.memo),
        (12000, '점심', '맛있음'),
      );
      expect(r.rows[1].kind, EntryKind.income);
      expect(r.rows[1].time, '12:00', reason: '시간이 없으면 정오');
      expect(r.categoriesOf(EntryKind.expense), ['식비']);
      expect(r.categoriesOf(EntryKind.income), ['월급']);
      expect(r.total(EntryKind.expense), 15000);
      expect(r.total(EntryKind.income), 2000000);
    });

    test('금액 부호로: 음수는 지출, 양수는 수입(금액은 항상 양수로 저장)', () {
      final t = ImportTable([
        ['날짜', '금액', '가맹점'],
        ['2026-11-08', '-4,500', '스타벅스'],
        ['2026-11-09', '100000', '회사'],
      ]);
      final r = parseImportRows(t, guessMapping(t));
      expect(r.rows.map((e) => e.kind), [EntryKind.expense, EntryKind.income]);
      expect(r.rows.map((e) => e.amount), [4500, 100000]);
      expect(r.rows.map((e) => e.place), ['스타벅스', ''], reason: '구매처는 지출만');
    });

    test('전부 지출로', () {
      final t = ImportTable([
        ['날짜', '금액'],
        ['2026-11-08', 4500],
      ]);
      final m = guessMapping(t).copyWith(typeMode: ImportTypeMode.allExpense);
      expect(parseImportRows(t, m).rows.single.kind, EntryKind.expense);
    });
  });

  test('긴 분류 이름은 앞 8자만 쓴다', () {
    expect(importCategoryName(' 식비 '), '식비');
    expect(importCategoryName('가나다라마바사아자차'), '가나다라마바사아');
  });
}
