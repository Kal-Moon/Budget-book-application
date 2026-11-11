import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/analysis.dart';
import '../../domain/budget.dart';
import '../../domain/summary.dart';
import '../home/home_widgets.dart';
import '../screens/input_screen.dart';
import '../theme.dart';
import 'analysis_view.dart';
import 'analysis_widgets.dart';

/// 카테고리 비중: 보고 있는 달의 지출(또는 수입)을 카테고리별로 나눠 보여준다.
class DonutPane extends ConsumerWidget {
  const DonutPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final view = ref.watch(analysisViewProvider);
    final notifier = ref.read(analysisViewProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final entries = ref.watch(monthEntriesProvider(view.monthKey)).value;
    final budget = ref.watch(monthBudgetProvider(view.monthKey)).value;
    final categories = ref.watch(categoriesProvider(view.kind)).value;
    if (entries == null || budget == null || categories == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final month = monthStartOf(view.monthKey);
    final isCurrent = view.monthKey == ref.watch(currentMonthKeyProvider);
    final expense = view.kind == EntryKind.expense;
    final totals = EntryTotals(entries);
    final ofKind = entries.where((e) => e.kind == view.kind).toList();
    final byCategory = <int, int>{};
    for (final e in ofKind) {
      byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
    }
    final total = expense ? totals.expense : totals.income;
    final highlight = highlightColorOf(settings.highlightColor);
    final totalOver =
        expense &&
        highlightMonthTotal(
          budget: budget,
          spent: totals.expense,
          thresholdPercent: settings.budgetThreshold,
          alsoInCategoryMode: settings.totalHighlightInCategoryMode,
        );

    void openCategory(Category cat) {
      final list = ofKind.where((e) => e.categoryId == cat.id).toList()
        ..sort(
          (a, b) => b.date.compareTo(a.date) != 0
              ? b.date.compareTo(a.date)
              : b.time.compareTo(a.time),
        );
      showListSheet(
        context,
        title: '${month.month}월 · ${cat.icon} ${cat.name} 내역',
        children: list.isEmpty
            ? [const EmptyMessage('이 달엔 내역이 없어요')]
            : [
                for (final e in list)
                  SheetEntryRow(
                    entry: e,
                    category: cat,
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      openEntryEditor(navigator.context, e);
                    },
                  ),
              ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        if (!isCurrent)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(12, 0, 2, 0),
            decoration: BoxDecoration(
              color: c.accentBg,
              border: Border.all(color: c.accent, width: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${month.year}년 ${month.month}월 데이터를 보는 중',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF185FA5),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: notifier.showCurrentMonth,
                  child: const Text(
                    '이번 달로 돌아가기',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF185FA5),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (settings.showAnalysisIncome)
          AnalysisIncomeStrip(income: totals.income, expense: totals.expense),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                '${month.month}월 예산 방식',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                budget.isSet ? budget.mode.label : '아직 정하지 않음',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.accent,
                ),
              ),
            ],
          ),
        ),
        ChoiceChipRow<EntryKind>(
          items: EntryKind.values,
          selected: view.kind,
          expand: true,
          labelOf: (k) => k == EntryKind.expense ? '지출' : '수입',
          onSelected: notifier.setKind,
        ),
        const SizedBox(height: 16),
        Center(
          child: DonutChart(
            slices: [
              for (final cat in categories)
                DonutSlice(cat.color, byCategory[cat.id] ?? 0),
            ],
            label: '${month.month}월 ${expense ? '지출' : '수입'}',
            total: total,
            totalColor: totalOver ? Color(highlight.text) : null,
          ),
        ),
        if (total == 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '아직 ${isCurrent ? '이번 달' : '${month.month}월'} ${expense ? '지출' : '수입'}이 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: c.textMuted),
            ),
          ),
        const SizedBox(height: 12),
        for (final cat in categories)
          _LegendRow(
            category: cat,
            amount: byCategory[cat.id] ?? 0,
            total: total,
            over:
                expense &&
                budget.mode == BudgetMode.category &&
                isOverBudget(
                  byCategory[cat.id] ?? 0,
                  budget.categoryBudget(cat.id),
                  settings.budgetThreshold,
                ),
            highlight: highlight,
            onTap: () => openCategory(cat),
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.category,
    required this.amount,
    required this.total,
    required this.over,
    required this.highlight,
    required this.onTap,
  });

  final Category category;
  final int amount;
  final int total;
  final bool over;
  final HighlightColor highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = total > 0 ? (amount * 100 / total).round() : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: over ? Color(highlight.background) : c.surface2,
        shape: RoundedRectangleBorder(
          side: over
              ? BorderSide(color: Color(highlight.border), width: 0.5)
              : BorderSide.none,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: Color(category.color),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 9),
                Text(category.icon, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 9),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (over)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Color(highlight.text),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '초과',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  formatWon(amount),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: over ? Color(highlight.text) : null,
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: c.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
