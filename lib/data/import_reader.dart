import 'dart:convert';
import 'dart:typed_data';

import 'package:cp949_codec/cp949_codec.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../domain/import.dart';

/// 파일을 읽지 못했을 때. [message]는 화면에 그대로 보여준다.
class ImportReadException implements Exception {
  const ImportReadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 엑셀(.xlsx) 또는 CSV 파일의 시트들을 읽은 그대로 돌려준다(빈 시트는 뺀다).
/// 옛 엑셀 형식(.xls)은 지원하지 않는다.
List<ImportSheet> readImportSheets(String fileName, Uint8List bytes) {
  final name = fileName.toLowerCase();
  final List<ImportSheet> sheets;
  if (name.endsWith('.xlsx')) {
    sheets = _readXlsx(bytes);
  } else if (name.endsWith('.csv') || name.endsWith('.txt')) {
    sheets = [ImportSheet('CSV', _readCsv(bytes))];
  } else if (name.endsWith('.xls')) {
    throw const ImportReadException(
      '옛 엑셀 형식(.xls)은 읽을 수 없어요. 엑셀에서 "다른 이름으로 저장 → .xlsx"로 바꿔서 올려주세요.',
    );
  } else {
    throw const ImportReadException('엑셀(.xlsx) 또는 CSV 파일만 가져올 수 있어요.');
  }
  final filled = [
    for (final s in sheets)
      if (!s.isEmpty) s,
  ];
  if (filled.isEmpty) {
    throw const ImportReadException('파일에서 데이터를 찾지 못했어요.');
  }
  return filled;
}

/// 시트 하나를 가져올 표로: 헤더 줄을 추측해서 만든다.
/// 헤더 아래에 내역이 없으면 [ImportReadException].
ImportTable tableOfSheet(ImportSheet sheet, {int? headerRow}) =>
    ImportTable(sheet.rows, headerRow: headerRow ?? guessHeaderRow(sheet.rows));

/// 파일의 첫 시트를 표로 읽는다(헤더 줄은 추측).
ImportTable readImportFile(String fileName, Uint8List bytes) {
  final table = tableOfSheet(readImportSheets(fileName, bytes).first);
  if (table.rows.isEmpty) {
    throw const ImportReadException('헤더 아래에 데이터 행이 없어요.');
  }
  return table;
}

List<ImportSheet> _readXlsx(Uint8List bytes) {
  final Excel book;
  try {
    book = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const ImportReadException('파일을 읽지 못했어요. 엑셀(.xlsx) 파일이 맞는지 확인해주세요.');
  }
  return [
    for (final MapEntry(key: name, value: sheet) in book.tables.entries)
      ImportSheet(name, _rowsOf(sheet)),
  ];
}

List<List<Object?>> _rowsOf(Sheet sheet) => [
  for (final row in sheet.rows)
    [
      for (final cell in row)
        switch (cell?.value) {
          null => null,
          IntCellValue(:final value) => value,
          DoubleCellValue(:final value) => value,
          DateCellValue(:final year, :final month, :final day) => DateTime(
            year,
            month,
            day,
          ),
          DateTimeCellValue(
            :final year,
            :final month,
            :final day,
            :final hour,
            :final minute,
          ) =>
            DateTime(year, month, day, hour, minute),
          TimeCellValue(:final hour, :final minute) =>
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
          final other => other.toString(),
        },
    ],
];

List<List<Object?>> _readCsv(Uint8List bytes) {
  // UTF-8이 아니면 한글 윈도우 엑셀이 저장하는 CP949(EUC-KR)로 읽는다.
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    try {
      text = cp949.decode(bytes);
    } catch (_) {
      throw const ImportReadException(
        '파일의 글자를 읽지 못했어요. CSV를 UTF-8로 저장해서 다시 올려주세요.',
      );
    }
  }
  if (text.startsWith('﻿')) text = text.substring(1);
  return Csv().decode(text);
}
