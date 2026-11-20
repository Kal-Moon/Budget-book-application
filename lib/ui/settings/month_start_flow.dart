import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/settings.dart';
import '../../domain/period.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';

/// 세부 설정의 "한 달 시작일" 바꾸기: 날 고르기 → 확인창(항상) → 저장.
/// 바꾼 시작일은 이번 달부터 바로 적용하고, 새 시작일 전 날짜는 전월에 넣는다(`PeriodCalendar.withStartDay`).
Future<void> changeMonthStart(BuildContext context, WidgetRef ref) async {
  final calendar = ref.read(periodCalendarProvider);
  final day = await _pickDay(context, calendar.chosenDay);
  if (day == null || !context.mounted) return;

  final today = ref.read(todayProvider);
  final changed = calendar.withStartDay(today, day);
  if (changed.encode() == calendar.encode()) return;

  final ok = await showConfirmSheet(
    context,
    title: '한 달 시작일을 ${monthStartDayLabel(day)}로 바꿀까요?',
    description: Text(_explain(calendar, changed, today)),
    confirmLabel: '바꾸기',
  );
  if (!ok || !context.mounted) return;
  await ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(monthStartChanges: changed.encode()));
  if (context.mounted) {
    showToast(context, '✓ 한 달 시작일을 ${monthStartDayLabel(day)}로 바꿨어요');
  }
}

/// 확인창 설명: 이번 달과 전월 기간이 어떻게 되는지.
String _explain(PeriodCalendar before, PeriodCalendar after, DateTime today) {
  String month(String key) => '${monthStartOf(key).month}월';
  String days(String key) =>
      '${after.endOf(key).difference(after.startOf(key)).inDays + 1}일';

  final thisMonth = monthKeyOf(today);
  final prev = shiftMonthKey(thisMonth, -1);
  final lines = [
    '이번 달부터 바로 적용돼요. 새 시작일 전 날짜는 전월에 들어가요.',
    '· ${month(prev)}: ${after.rangeLabel(prev)} (${days(prev)})',
    '· ${month(thisMonth)}: ${after.rangeLabel(thisMonth)}',
  ];
  if (after.keyOf(today) == prev) {
    lines.add('오늘(${today.month}.${today.day})은 아직 ${month(prev)}이에요.');
  }
  if (before.rangeOf(prev) != after.rangeOf(prev)) {
    lines.add(
      '${month(prev)} 날짜가 바뀌어서 ${month(prev)} 합계와 예산 초과 표시가 달라질 수 있어요.',
    );
  }
  return lines.join('\n');
}

/// 시작일 고르기(1~28일, 말일). 고르지 않고 닫으면 null.
Future<int?> _pickDay(BuildContext context, int selected) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '한 달 시작일',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '월급날처럼 한 달을 시작할 날을 골라주세요',
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.4,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final d in monthStartDays)
                    _DayButton(
                      label: monthStartDayLabel(d),
                      selected: d == selected,
                      onTap: () => Navigator.pop(context, d),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.accentBg : c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? c.accent : c.border,
          width: selected ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? c.accent : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
