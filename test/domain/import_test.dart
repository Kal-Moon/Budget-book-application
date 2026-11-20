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

  group('표를 보면서 맞추기', () {
    test('위에 제목·기간 줄이 있으면 항목 이름이 있는 줄을 헤더로 고른다', () {
      final all = <List<Object?>>[
        ['신한카드 이용내역'],
        ['조회기간: 2026.11.01 ~ 2026.11.30'],
        [],
        ['이용일', '가맹점명', '이용금액', '비고'],
        ['2026.11.08', '스타벅스', '4,500', ''],
        ['2026.11.09', 'GS25', '3,200', '간식'],
      ];
      expect(guessHeaderRow(all), 3);
      final t = ImportTable(all, headerRow: 3);
      expect(t.headers, ['이용일', '가맹점명', '이용금액', '비고']);
      expect(t.rows, hasLength(2));
      final m = guessMapping(t);
      expect((m.date, m.place, m.amount, m.memo), (0, 1, 2, 3));
    });

    test('항목 이름이 없으면 값을 보고 날짜·금액 열을 찾는다', () {
      final t = ImportTable([
        ['A', 'B', 'C'],
        ['점심', '2026-11-08', '-12000'],
        ['커피', '2026-11-09', '-4500'],
      ]);
      final m = guessMapping(t);
      expect((m.date, m.amount), (1, 2));
    });

    test('출금액·입금액이 따로 있으면 "지출·수입 금액 열이 따로"로 읽고, 둘 다 있으면 두 건', () {
      final t = ImportTable([
        ['거래일시', '적요', '출금액', '입금액', '잔액'],
        ['2026-11-08 12:30', '점심', '12,000', '', '88,000'],
        ['2026-11-09', '급여', '', '2,000,000', '2,088,000'],
        ['2026-11-10', '환불', '1,000', '500', '2,087,500'],
        ['2026-11-11', '잔액만', '', '', '2,087,500'],
      ]);
      final m = guessMapping(t);
      expect(m.typeMode, ImportTypeMode.split);
      expect(
        (m.date, m.description, m.expenseAmount, m.incomeAmount),
        (0, 1, 2, 3),
      );
      expect(m.amount, -1);
      final r = parseImportRows(t, m);
      expect(r.rows.map((e) => (e.kind, e.amount)), [
        (EntryKind.expense, 12000),
        (EntryKind.income, 2000000),
        (EntryKind.expense, 1000),
        (EntryKind.income, 500),
      ]);
      expect(r.rows.first.time, '12:30');
      expect(r.skipped, 1);
    });

    test('시간 열이 따로 있으면 그 시간을 쓴다', () {
      final t = ImportTable([
        ['날짜', '시간', '금액'],
        ['2026-11-08', '오후 3:20', -5000],
        ['2026-11-09', 0.5, -5000],
        ['2026-11-10', '', -5000],
      ]);
      final m = guessMapping(t);
      expect(m.time, 1);
      expect(parseImportRows(t, m).rows.map((e) => e.time), [
        '15:20',
        '12:00',
        '12:00',
      ]);
      expect(parseTimeCell('09:05:00'), '09:05');
      expect(parseTimeCell(DateTime(2026, 1, 1, 7, 30)), '07:30');
    });

    test('열에 역할 정하기: 한 역할은 한 열에만, 금액과 지출/수입 금액은 함께 쓰지 않는다', () {
      var m = const ImportMapping(date: 0, amount: 1);
      m = m.assign(2, ImportRole.amount);
      expect((m.amount, m.roleOf(1)), (2, null), reason: '금액이 2열로 옮겨감');
      m = m.assign(2, ImportRole.date);
      expect((m.date, m.amount), (2, -1), reason: '0열은 비고, 2열의 예전 역할(금액)도 비움');
      expect(m.problem, '금액 열을 정해주세요.');

      m = m
          .assign(3, ImportRole.expenseAmount)
          .assign(4, ImportRole.incomeAmount);
      expect(m.typeMode, ImportTypeMode.split);
      expect(m.problem, isNull);
      m = m.assign(5, ImportRole.amount);
      expect(
        (m.expenseAmount, m.incomeAmount, m.typeMode),
        (-1, -1, ImportTypeMode.sign),
      );

      m = m.assign(6, ImportRole.type);
      expect(m.typeMode, ImportTypeMode.column);
      m = m.assign(6, null);
      expect((m.type, m.typeMode), (-1, ImportTypeMode.sign));
      expect(
        const ImportMapping(
          amount: 0,
          typeMode: ImportTypeMode.column,
        ).copyWith(date: 1).problem,
        '수입/지출을 구분할 열을 정해주세요.',
      );
    });
  });

  test('긴 분류 이름은 앞 8자만 쓴다', () {
    expect(importCategoryName(' 식비 '), '식비');
    expect(importCategoryName('가나다라마바사아자차'), '가나다라마바사아');
  });
}
