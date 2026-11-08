import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../data/database.dart';
import '../../domain/budget.dart';
import '../../domain/summary.dart';
import '../theme.dart';

/// 이번 달 예산이 0원일 때 보여주는 안내.
class SetupBanner extends StatelessWidget {
  const SetupBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFFFAEEDA),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    child: const Text(
      '예산이 설정되지 않았어요 · 설정에서 정할 수 있어요',
      style: TextStyle(fontSize: 12, color: Color(0xFF854F0B)),
    ),
  );
}

/// 지출 / 남은 예산 + 진행바.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.spentLabel,
    required this.spentShown,
    required this.monthSpent,
    required this.budget,
    required this.threshold,
  });

  /// '11월 지출' 또는 '선택한 날 지출'
  final String spentLabel;

  /// 왼쪽에 보여줄 지출(하루를 보고 있으면 그날 지출).
  final int spentShown;

  /// 남은 예산·진행바 계산에 쓰는 그 달 전체 지출.
  final int monthSpent;
  final int budget;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final over = isOverBudget(monthSpent, budget, threshold);
    final exceeded = budget > 0 && monthSpent > budget;
    final ratio = budget > 0 ? (monthSpent / budget).clamp(0.0, 1.0) : 0.0;
    final labelStyle = TextStyle(fontSize: 11.5, color: c.textMuted);
    const valueStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

    return Container(
      color: c.surface2,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spentLabel, style: labelStyle),
                    const SizedBox(height: 4),
                    Text(formatWon(spentShown), style: valueStyle),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('남은 예산', style: labelStyle),
                    const SizedBox(height: 4),
                    Text(
                      exceeded
                          ? '${formatWon(monthSpent - budget)} 초과'
                          : formatWon(budget - monthSpent),
                      style: valueStyle.copyWith(
                        color: exceeded ? c.danger : c.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: c.surface0,
              color: over ? c.danger : c.accent,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '사용 ${budget > 0 ? (monthSpent * 100 ~/ budget) : 0}%',
                style: labelStyle,
              ),
              Text('총 ${formatWon(budget)}', style: labelStyle),
            ],
          ),
        ],
      ),
    );
  }
}

/// 수입 · 지출 · 차액 한 줄.
class IncomeStrip extends StatelessWidget {
  const IncomeStrip({super.key, required this.month, required this.totals});

  final int month;
  final EntryTotals totals;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diff = totals.difference;
    Widget col(String label, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: c.textMuted)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          col('수입', formatWon(totals.income), c.income),
          col('지출', formatWon(totals.expense), c.textPrimary),
          col(
            '차액',
            '${diff >= 0 ? '+' : ''}${formatWon(diff)}',
            diff >= 0 ? const Color(0xFF185FA5) : c.danger,
          ),
        ],
      ),
    );
  }
}

/// 하루만 보고 있을 때의 안내와 "그 달 전체 보기".
class DayFilterBanner extends StatelessWidget {
  const DayFilterBanner({
    super.key,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.accentBg,
      padding: const EdgeInsets.fromLTRB(18, 2, 6, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: c.accent)),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 11.5,
                color: c.accent,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 카테고리 색으로 나뉜 지출 비율 막대 + 카테고리 칩. 누르면 [onTap](분석으로 이동).
class SpendingBreakdown extends StatelessWidget {
  const SpendingBreakdown({
    super.key,
    required this.categories,
    required this.totals,
    required this.budget,
    required this.threshold,
    required this.onTap,
  });

  /// 지출 카테고리(정렬 순서대로).
  final List<Category> categories;
  final EntryTotals totals;
  final MonthBudget budget;
  final int threshold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = totals.expense;
    return Container(
      color: c.surface2,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                label: '카테고리별 지출 비율',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: total == 0
                        ? ColoredBox(color: c.border)
                        : Row(
                            children: [
                              for (final cat in categories)
                                if (totals.spentIn(cat.id) > 0)
                                  Expanded(
                                    flex: totals.spentIn(cat.id),
                                    child: ColoredBox(color: Color(cat.color)),
                                  ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, i) {
                final cat = categories[i];
                final spent = totals.spentIn(cat.id);
                final String detail;
                var over = false;
                if (budget.mode == BudgetMode.category) {
                  final catBudget = budget.categoryBudget(cat.id);
                  over = isOverBudget(spent, catBudget, threshold);
                  detail =
                      '${formatNumber(spent)} / ${formatNumber(catBudget)}';
                } else {
                  final pct = total > 0 ? (spent * 100 / total).round() : 0;
                  detail = '${formatNumber(spent)} · $pct%';
                }
                return GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    constraints: const BoxConstraints(minWidth: 72),
                    decoration: BoxDecoration(
                      color: c.surface0,
                      border: Border.all(
                        color: over
                            ? c.danger
                            : Color(cat.color).withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Dot(Color(cat.color)),
                            const SizedBox(width: 4),
                            Text(
                              '${cat.icon} ${cat.name}',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: over ? c.danger : c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// 가로로 나열된 선택 칩 한 줄.
class ChoiceChipRow<T> extends StatelessWidget {
  const ChoiceChipRow({
    super.key,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.expand = false,
  });

  final List<T> items;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  /// true면 칩이 한 줄을 나눠 가진다(전체/지출/수입).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget chip(T item) {
      final sel = item == selected;
      return GestureDetector(
        onTap: () => onSelected(item),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? c.accentBg : c.surface0,
            border: Border.all(
              color: sel ? c.accent : c.border,
              width: expand ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(expand ? 9 : 16),
          ),
          child: Text(
            labelOf(item),
            style: TextStyle(
              fontSize: 11.5,
              color: sel ? c.accent : c.textSecondary,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    if (expand) {
      return Row(
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(child: chip(item)),
          ],
        ],
      );
    }
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, i) => chip(items[i]),
      ),
    );
  }
}

/// 날짜 묶음의 머리글.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.label, this.net});

  final String label;

  /// 그날의 수입 − 지출. 검색 결과에서는 보여주지 않는다.
  final int? net;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
          if (net case final n?)
            Text(
              '${n >= 0 ? '+' : ''}${formatWon(n)}',
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
        ],
      ),
    );
  }
}

/// 내역 한 줄.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.category,
    this.overBudget = false,
    this.onTap,
  });

  final Entry entry;
  final Category? category;

  /// 항목별 예산 방식에서 이 카테고리가 그 달 예산을 넘었는지.
  final bool overBudget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final income = entry.kind == EntryKind.income;
    final catName = category?.name ?? '(삭제된 카테고리)';
    final hasDesc = entry.description.isNotEmpty;
    final sub = [
      catName,
      if (!income && entry.place.isNotEmpty) entry.place,
      if (overBudget) '예산 초과',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Material(
        color: c.surface2,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: overBudget
                ? c.danger
                : income
                ? const Color(0xFFA9CB8A)
                : c.border,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color(category?.color ?? 0xFF888780)
                        .withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    category?.icon ?? '❔',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasDesc ? entry.description : catName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: hasDesc
                              ? FontWeight.w500
                              : FontWeight.w400,
                          fontStyle: hasDesc ? null : FontStyle.italic,
                          color: hasDesc ? c.textPrimary : c.textMuted,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: overBudget ? c.danger : c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${income ? '+' : ''}${formatWon(entry.amount)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: income
                            ? c.income
                            : overBudget
                            ? c.danger
                            : c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.time,
                      style: TextStyle(fontSize: 10.5, color: c.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 내역이 없을 때 안내.
class EmptyMessage extends StatelessWidget {
  const EmptyMessage(this.message, {super.key, this.hint});

  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: c.textMuted, height: 1.9),
          ),
          if (hint != null)
            Text(hint!, style: TextStyle(fontSize: 12, color: c.textMuted)),
        ],
      ),
    );
  }
}
