import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/excel_export.dart';
import 'package:gagyebu/data/import_reader.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/domain/import.dart';
import 'package:gagyebu/domain/period.dart';

import '../helpers.dart';

void main() {
  test('내보낸 엑셀을 가져오기로 다시 읽으면 같은 내역이 나온다', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    await addEntry(
      db,
      date: '2026-11-08',
      time: '12:30',
      categoryId: 1,
      amount: 12000,
      place: '김밥천국',
      description: '점심',
      memo: '맛있음',
    );
    await addEntry(
      db,
      kind: EntryKind.income,
      date: '2026-11-01',
      time: '09:00',
      categoryId: 5,
      amount: 2000000,
      description: '11월 급여',
    );
    final entries = await db.watchAllEntries().first;
    final cats = {for (final c in await db.watchAllCategories().first) c.id: c};

    final bytes = buildEntriesXlsx(entries, cats);
    final table = readImportFile('내보내기.xlsx', bytes);
    expect(table.headers, excelExportHeaders);
    final m = guessMapping(table);
    expect(m.typeMode, ImportTypeMode.column);
    final rows = parseImportRows(table, m).rows;

    expect(
      [
        for (final r in rows)
          (
            r.kind,
            r.date,
            r.time,
            r.categoryRaw,
            r.amount,
            r.place,
            r.description,
            r.memo,
          ),
      ],
      [
        (
          EntryKind.income,
          '2026-11-01',
          '09:00',
          '월급',
          2000000,
          '',
          '11월 급여',
          '',
        ),
        (
          EntryKind.expense,
          '2026-11-08',
          '12:30',
          '식비',
          12000,
          '김밥천국',
          '점심',
          '맛있음',
        ),
      ],
      reason: '날짜 순',
    );
  });

  test('파일 이름: 기간이 있으면 기간, 전체면 만든 날짜', () {
    final now = DateTime(2026, 11, 20, 9);
    expect(
      excelExportFileName(
        range: const DateRange('2026-11-01', '2026-11-30'),
        now: now,
      ),
      'gagyebu-entries-20261101-20261130.xlsx',
    );
    expect(excelExportFileName(now: now), 'gagyebu-entries-all-20261120.xlsx');
  });
}
