import 'dart:convert';
import 'dart:typed_data';

import 'package:cp949_codec/cp949_codec.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/import_reader.dart';
import 'package:gagyebu/domain/import.dart';

Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  const csv = '날짜,금액,내용\n2026-11-08,"12,000",점심\n2026-11-09,4500,"커피, 케이크"\n';

  test('CSV(UTF-8, BOM 포함)를 읽는다', () {
    final t = readImportFile('내역.csv', bytesOf('﻿$csv'));
    expect(t.headers, ['날짜', '금액', '내용']);
    expect(t.rows, hasLength(2));
    expect(t.rows[0][1], '12,000');
    expect(t.rows[1][2], '커피, 케이크');
  });

  test('CSV(CP949, 한글 윈도우 엑셀 저장본)를 읽는다', () {
    final t = readImportFile('내역.CSV', Uint8List.fromList(cp949.encode(csv)));
    expect(t.headers, ['날짜', '금액', '내용']);
    expect(t.rows[0][2], '점심');
  });

  test('엑셀(.xlsx)을 읽는다: 숫자는 숫자로, 날짜는 날짜로', () {
    final book = Excel.createExcel();
    final sheet = book[book.getDefaultSheet()!];
    sheet.appendRow([
      TextCellValue('날짜'),
      TextCellValue('금액'),
      TextCellValue('내용'),
    ]);
    sheet.appendRow([
      DateTimeCellValue(year: 2026, month: 11, day: 8, hour: 12, minute: 30),
      IntCellValue(12000),
      TextCellValue('점심'),
    ]);
    final t = readImportFile('편한가계부.xlsx', Uint8List.fromList(book.encode()!));

    expect(t.headers, ['날짜', '금액', '내용']);
    final row = t.rows.single;
    final when = parseDateCell(row[0])!;
    expect((when.date, when.time), ('2026-11-08', '12:30'));
    expect(parseAmountCell(row[1]), 12000);
    expect(row[2], '점심');
  });

  test('읽을 수 없는 파일은 이유를 알려준다', () {
    String messageOf(String name, String content) {
      try {
        readImportFile(name, bytesOf(content));
        return '';
      } on ImportReadException catch (e) {
        return e.message;
      }
    }

    expect(messageOf('옛날.xls', 'x'), contains('.xlsx'));
    expect(messageOf('사진.png', 'x'), contains('엑셀(.xlsx) 또는 CSV'));
    expect(messageOf('깨짐.xlsx', '엑셀 아님'), contains('읽지 못했어요'));
    expect(messageOf('빈.csv', ''), contains('데이터를 찾지 못했어요'));
    expect(messageOf('헤더만.csv', '날짜,금액\n'), contains('데이터 행이 없어요'));
  });
}
