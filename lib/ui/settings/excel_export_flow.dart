import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/excel_export.dart';
import '../../data/providers.dart';
import '../../domain/period.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/file_out.dart';

enum _ExportPeriod { all, thisMonth, lastMonth, custom }

/// 엑셀로 내보내기: 기간 고르기 → 저장 또는 보내기.
/// 기간은 한 달 시작일을 따른다("이번 달" = 지금 예산 기간).
Future<void> startExcelExport(BuildContext context, WidgetRef ref) async {
  final calendar = ref.read(periodCalendarProvider);
  final monthKey = ref.read(currentMonthKeyProvider);
  final lastKey = shiftMonthKey(monthKey, -1);
  String monthName(String key) => '${int.parse(key.substring(5))}월';
  final c = context.colors;

  final period = await showModalBottomSheet<_ExportPeriod>(
    context: context,
    builder: (context) {
      Widget option(_ExportPeriod value, String label, [String? detail]) =>
          ListTile(
            title: Text(label),
            subtitle: detail == null
                ? null
                : Text(
                    detail,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
            onTap: () => Navigator.of(context).pop(value),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  '어느 기간을 내보낼까요?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              option(_ExportPeriod.all, '전체 기간'),
              option(
                _ExportPeriod.thisMonth,
                '이번 달 (${monthName(monthKey)})',
                calendar.rangeLabel(monthKey),
              ),
              option(
                _ExportPeriod.lastMonth,
                '지난달 (${monthName(lastKey)})',
                calendar.rangeLabel(lastKey),
              ),
              option(_ExportPeriod.custom, '기간 직접 고르기'),
            ],
          ),
        ),
      );
    },
  );
  if (period == null || !context.mounted) return;

  DateRange? range;
  switch (period) {
    case _ExportPeriod.all:
      range = null;
    case _ExportPeriod.thisMonth:
      range = calendar.rangeOf(monthKey);
    case _ExportPeriod.lastMonth:
      range = calendar.rangeOf(lastKey);
    case _ExportPeriod.custom:
      final current = calendar.rangeOf(monthKey);
      final today = ref.read(todayProvider);
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(today.year + 1, 12, 31),
        initialDateRange: DateTimeRange(
          start: DateTime.parse(current.start),
          end: DateTime.parse(current.end),
        ),
        helpText: '내보낼 기간',
        saveText: '선택',
      );
      if (picked == null || !context.mounted) return;
      range = DateRange(dateKeyOf(picked.start), dateKeyOf(picked.end));
  }

  final db = ref.read(databaseProvider);
  final entries = range == null
      ? await db.watchAllEntries().first
      : await db.watchEntriesBetween(range.start, range.end).first;
  if (!context.mounted) return;
  if (entries.isEmpty) {
    showToast(context, '이 기간에는 내역이 없어요');
    return;
  }
  final categories = {
    for (final cat in await db.watchAllCategories().first) cat.id: cat,
  };
  if (!context.mounted) return;
  await deliverFile(
    context,
    ref,
    what: '엑셀 파일',
    name: excelExportFileName(range: range, now: ref.read(clockProvider).now()),
    build: () async => buildEntriesXlsx(entries, categories),
  );
}
