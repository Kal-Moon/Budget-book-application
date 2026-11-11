import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/confirm_sheet.dart';

/// 이번 달(오늘 기준) 예산을 정하는 시트: 방식 선택 → 금액 입력.
/// 이번 달 예산이 아직 없으면 [prefill](지난달 예산)의 금액을 미리 채운다.
Future<void> showBudgetSheet(BuildContext context, {MonthBudget? prefill}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.colors.surface0,
      builder: (_) => _BudgetSheet(prefill: prefill),
    );

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.prefill});

  final MonthBudget? prefill;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  /// null이면 방식 선택 단계.
  BudgetMode? _mode;
  MonthBudget? _source;
  List<Category> _categories = const [];
  final _total = TextEditingController();
  final Map<int, TextEditingController> _amounts = {};

  late final String _monthKey = ref.read(currentMonthKeyProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final current = await db.getMonthBudget(_monthKey);
    final cats = await db.watchCategories(EntryKind.expense).first;
    if (!mounted) return;
    // 금액을 미리 채울 출처: 이번 달 예산 → 없으면 지난달 예산.
    final source = current.isSet ? current : (widget.prefill ?? current);
    setState(() {
      _source = source;
      _categories = cats;
      if (source.totalBudget > 0) {
        _total.text = formatNumber(source.totalBudget);
      }
      for (final c in cats) {
        final amount = source.categoryAmounts[c.id] ?? 0;
        _amounts[c.id] = TextEditingController(
          text: amount > 0 ? formatNumber(amount) : '',
        );
      }
    });
  }

  @override
  void dispose() {
    _total.dispose();
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref
        .read(databaseProvider)
        .saveMonthBudget(
          MonthBudget(
            monthKey: _monthKey,
            mode: _mode!,
            total: parseAmount(_total.text),
            categoryAmounts: {
              for (final c in _categories)
                c.id: parseAmount(_amounts[c.id]!.text),
            },
          ),
        );
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('✓ 예산이 저장됐어요', textAlign: TextAlign.center),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final month = monthStartOf(_monthKey);
    final source = _source;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: source == null
              ? const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    Row(
                      children: [
                        if (_mode != null)
                          IconButton(
                            tooltip: '방식 다시 고르기',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _mode = null),
                            icon: const Icon(Icons.chevron_left),
                          ),
                        Text(
                          switch (_mode) {
                            null => '예산 설정',
                            BudgetMode.total => '총 예산 입력',
                            BudgetMode.category => '카테고리별 예산 입력',
                          },
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${month.year}년 ${month.month}월 예산을 설정해요 (오늘 기준 이번 달)',
                      style: TextStyle(fontSize: 11.5, color: c.textMuted),
                    ),
                    const SizedBox(height: 14),
                    ...switch (_mode) {
                      null => _pickStep(c, source),
                      BudgetMode.total => _totalStep(c),
                      BudgetMode.category => _categoryStep(c),
                    },
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _pickStep(AppColors c, MonthBudget source) => [
    for (final (mode, icon) in [
      (BudgetMode.total, '💵'),
      (BudgetMode.category, '🗂️'),
    ])
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: GestureDetector(
          onTap: () => setState(() => _mode = mode),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: source.isSet && source.mode == mode ? c.accentBg : null,
              border: Border.all(
                color: source.isSet && source.mode == mode
                    ? c.accent
                    : c.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 19)),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    mode.label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: c.textMuted),
              ],
            ),
          ),
        ),
      ),
  ];

  Widget _saveButton() => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: FilledButton(
      onPressed: _save,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: const Text('저장하고 적용하기'),
    ),
  );

  List<Widget> _totalStep(AppColors c) => [
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text('한 달 총 예산', style: TextStyle(fontSize: 12, color: c.textMuted)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 190,
                child: AmountField(
                  controller: _total,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('원', style: TextStyle(fontSize: 18, color: c.textSecondary)),
            ],
          ),
        ],
      ),
    ),
    _saveButton(),
  ];

  List<Widget> _categoryStep(AppColors c) => [
    for (final cat in _categories)
      Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                cat.icon,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(cat.name, style: const TextStyle(fontSize: 13)),
            ),
            Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: c.surface1,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AmountField(
                controller: _amounts[cat.id]!,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 6),
            Text('원', style: TextStyle(fontSize: 11.5, color: c.textMuted)),
          ],
        ),
      ),
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('총 예산', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          Text(
            formatWon(
              _amounts.values.fold(0, (s, t) => s + parseAmount(t.text)),
            ),
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
        ],
      ),
    ),
    _saveButton(),
  ];
}

/// 새 달에 앱을 처음 열 때의 예산 처리.
/// - 이번 달 예산이 이미 있거나, 이어받을 지난 예산이 없으면 아무것도 하지 않는다.
/// - "지난달 예산 자동 적용"이 켜져 있으면 묻지 않고 복사한다.
/// - 꺼져 있으면 한 달에 한 번만 묻는다. "나중에"를 고르면 홈 배너만 남는다.
Future<void> handleNewMonthBudget(
  BuildContext context, {
  required AppDatabase db,
  required String monthKey,
  required bool autoCopy,
  required String promptedMonth,
  required Future<void> Function() markPrompted,
}) async {
  final current = await db.getMonthBudget(monthKey);
  if (current.isSet) return;
  final previous = await db.latestBudgetBefore(monthKey);
  if (previous == null || !context.mounted) return;
  final prevMonth = monthStartOf(previous.monthKey).month;

  if (autoCopy) {
    await db.saveMonthBudget(copyBudgetTo(monthKey, previous));
    if (context.mounted) showToast(context, '$prevMonth월 예산을 이어서 적용했어요');
    return;
  }
  if (promptedMonth == monthKey) return;
  await markPrompted();
  if (!context.mounted) return;

  final c = context.colors;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: c.surface0,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${monthStartOf(monthKey).month}월 예산을 정해주세요',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '$prevMonth월 예산: ${previous.mode.label} · 총 ${formatWon(previous.totalBudget)}',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(context, 'copy'),
              child: Text('$prevMonth월 예산 그대로 쓰기'),
            ),
            const SizedBox(height: 9),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(context, 'new'),
              child: const Text('새로 정하기'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context, 'later'),
              child: Text('나중에', style: TextStyle(color: c.textMuted)),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'copy':
      await db.saveMonthBudget(copyBudgetTo(monthKey, previous));
      if (context.mounted) showToast(context, '$prevMonth월 예산을 이어서 적용했어요');
    case 'new':
      await showBudgetSheet(context, prefill: previous);
  }
}
