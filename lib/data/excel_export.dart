import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../domain/budget.dart';
import '../domain/period.dart';
import 'database.dart';

/// 엑셀로 내보내는 열. 가져오기가 같은 이름으로 열을 알아본다(내보낸 파일을 다시 가져올 수 있다).
const excelExportHeaders = [
  '날짜',
  '시간',
  '수입/지출',
  '카테고리',
  '금액',
  '구매처',
  '내역',
  '메모',
];

/// 내역을 엑셀(.xlsx) 파일로 만든다. 날짜·시간 순. 금액은 항상 양수이고 "수입/지출" 열로 구분한다.
Uint8List buildEntriesXlsx(List<Entry> entries, Map<int, Category> categories) {
  final book = Excel.createExcel();
  const sheetName = '내역';
  book.rename(book.getDefaultSheet()!, sheetName);
  final sheet = book[sheetName];
  sheet.appendRow([for (final h in excelExportHeaders) TextCellValue(h)]);
  final sorted = [...entries]
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.time.compareTo(b.time);
    });
  for (final e in sorted) {
    final parts = e.date.split('-').map(int.parse).toList();
    sheet.appendRow([
      DateCellValue(year: parts[0], month: parts[1], day: parts[2]),
      TextCellValue(e.time),
      TextCellValue(e.kind == EntryKind.income ? '수입' : '지출'),
      TextCellValue(categories[e.categoryId]?.name ?? ''),
      IntCellValue(e.amount),
      TextCellValue(e.place),
      TextCellValue(e.description),
      TextCellValue(e.memo),
    ]);
  }
  const widths = [12.0, 7.0, 9.0, 11.0, 12.0, 16.0, 20.0, 20.0];
  for (final (i, w) in widths.indexed) {
    sheet.setColumnWidth(i, w);
  }
  return Uint8List.fromList(book.encode()!);
}

/// 내보낼 파일 이름. 기간이 없으면(전체) 만든 날짜만 붙인다.
String excelExportFileName({DateRange? range, required DateTime now}) {
  String compact(String dateKey) => dateKey.replaceAll('-', '');
  String two(int n) => n.toString().padLeft(2, '0');
  return range == null
      ? 'gagyebu-entries-all-${now.year}${two(now.month)}${two(now.day)}.xlsx'
      : 'gagyebu-entries-${compact(range.start)}-${compact(range.end)}.xlsx';
}
