import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/providers.dart';
import '../theme.dart';
import 'home_view.dart';

/// 홈 날짜 선택: 기본은 일 단위 달력, 연/월 버튼으로 다른 달로 이동한다.
/// 날을 고르면 그날만, "○월 전체 보기"를 누르면 그 달 전체를 본다.
Future<void> showHomeDatePicker(BuildContext context) => showModalBottomSheet(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: context.colors.surface0,
  builder: (_) => const _DatePickerSheet(),
);

enum _Panel { day, year, month }

class _DatePickerSheet extends ConsumerStatefulWidget {
  const _DatePickerSheet();

  @override
  ConsumerState<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends ConsumerState<_DatePickerSheet> {
  late DateTime _month = monthStartOf(ref.read(homeViewProvider).monthKey);
  _Panel _panel = _Panel.day;

  void _pickDay(String date) {
    ref.read(homeViewProvider.notifier).showDay(date);
    Navigator.pop(context);
  }

  void _showWholeMonth() {
    ref.read(homeViewProvider.notifier).showMonth(monthKeyOf(_month));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = switch (_panel) {
      _Panel.day => '날짜 선택',
      _Panel.year => '년도 선택',
      _Panel.month => '${_month.year}년 · 월 선택',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_panel != _Panel.day)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _panel = _Panel.day),
                  icon: const Icon(Icons.chevron_left, size: 18),
                  label: const Text('날짜 선택으로'),
                ),
              ),
            switch (_panel) {
              _Panel.day => _dayPanel(c),
              _Panel.year => _yearPanel(c),
              _Panel.month => _monthPanel(c),
            },
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, VoidCallback onTap) => Expanded(
    child: Material(
      color: context.colors.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ),
  );

  Widget _dayPanel(AppColors c) {
    final monthKey = monthKeyOf(_month);
    final entries = ref.watch(monthEntriesProvider(monthKey)).value ?? [];
    final withEntries = entries.map((e) => e.date).toSet();
    final today = dateKeyOf(ref.watch(todayProvider));
    final selected = ref.watch(homeViewProvider).selectedDate;
    // 달력은 일요일부터 시작한다.
    final leading = _month.weekday % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    const headers = ['일', '월', '화', '수', '목', '금', '토'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _pill(
              '${_month.year}년',
              () => setState(() => _panel = _Panel.year),
            ),
            const SizedBox(width: 9),
            _pill(
              '${_month.month}월',
              () => setState(() => _panel = _Panel.month),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (i, h) in headers.indexed)
              Expanded(
                child: Text(
                  h,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: i == 0
                        ? c.danger
                        : i == 6
                        ? c.accent
                        : c.textMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++)
              _dayCell(c, DateTime(_month.year, _month.month, d), (
                today: today,
                selected: selected,
                withEntries: withEntries,
              )),
          ],
        ),
        Divider(color: c.border, height: 20),
        TextButton(
          onPressed: _showWholeMonth,
          child: Text('${_month.year}년 ${_month.month}월 전체 보기'),
        ),
      ],
    );
  }

  Widget _dayCell(
    AppColors c,
    DateTime day,
    ({String today, String? selected, Set<String> withEntries}) info,
  ) {
    final key = dateKeyOf(day);
    final isSel = key == info.selected;
    final dow = day.weekday % 7;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _pickDay(key),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSel ? c.accent : null,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: key == info.today
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: isSel
                    ? Colors.white
                    : dow == 0
                    ? c.danger
                    : dow == 6
                    ? c.accent
                    : c.textPrimary,
              ),
            ),
          ),
          if (info.withEntries.contains(key) && !isSel)
            Positioned(
              top: 6,
              right: 8,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gridButton(
    AppColors c,
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) => Material(
    color: selected ? c.accent : c.surface2,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: selected ? Colors.white : c.textPrimary,
          ),
        ),
      ),
    ),
  );

  Widget _yearPanel(AppColors c) {
    final thisYear = ref.watch(todayProvider).year;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      mainAxisSpacing: 7,
      crossAxisSpacing: 7,
      childAspectRatio: 2.4,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var y = thisYear - 2; y <= thisYear + 2; y++)
          _gridButton(
            c,
            '$y년',
            selected: y == _month.year,
            onTap: () => setState(() {
              _month = DateTime(y, _month.month);
              _panel = _Panel.day;
            }),
          ),
      ],
    );
  }

  Widget _monthPanel(AppColors c) => GridView.count(
    crossAxisCount: 4,
    shrinkWrap: true,
    mainAxisSpacing: 6,
    crossAxisSpacing: 6,
    childAspectRatio: 2,
    physics: const NeverScrollableScrollPhysics(),
    children: [
      for (var m = 1; m <= 12; m++)
        _gridButton(
          c,
          '$m월',
          selected: m == _month.month,
          onTap: () => setState(() {
            _month = DateTime(_month.year, m);
            _panel = _Panel.day;
          }),
        ),
    ],
  );
}
