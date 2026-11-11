import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/analysis.dart';
import '../../domain/budget.dart';
import '../home/home_widgets.dart';
import '../theme.dart';
import 'analysis_view.dart';
import 'analysis_widgets.dart';

/// 연간 통계: 한 해의 지출을 카테고리별로, 카테고리를 누르면 월별로 보여준다.
class YearPane extends ConsumerWidget {
  const YearPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final year = ref.watch(analysisViewProvider.select((v) => v.year));
    final notifier = ref.read(analysisViewProvider.notifier);
    final entries = ref.watch(allEntriesProvider).value;
    final categories = ref.watch(categoriesProvider(EntryKind.expense)).value;
    if (entries == null || categories == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final stats = YearStats(entries, year, ref.watch(todayProvider));
    final ranked =
        categories.where((cat) => stats.categoryTotal(cat.id) > 0).toList()
          ..sort(
            (a, b) =>
                stats.categoryTotal(b.id).compareTo(stats.categoryTotal(a.id)),
          );

    void openCategory(Category cat) {
      final monthly = stats.byCategory[cat.id]!;
      final maxValue = math.max(1, monthly.reduce(math.max));
      showListSheet(
        context,
        title: '$year년 · ${cat.icon} ${cat.name} 월별 내역',
        children: [
          for (final (i, v) in monthly.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${i + 1}월',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: RatioBar(
                      ratio: v / maxValue,
                      color: Color(cat.color),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      formatWon(v),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '이전 년도',
              onPressed: () => notifier.moveYear(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '$year년',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            IconButton(
              tooltip: '다음 년도',
              onPressed: () => notifier.moveYear(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (stats.total == 0)
          EmptyMessage('$year년 지출 내역이 없어요 🙂')
        else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '$year년 총 지출',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  formatWon(stats.total),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '월평균 ${formatWon(stats.monthlyAverage)}',
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: DonutChart(
              slices: [
                for (final cat in ranked)
                  DonutSlice(cat.color, stats.categoryTotal(cat.id)),
              ],
              label: '$year년 지출',
              total: stats.total,
              size: 180,
            ),
          ),
          const SizedBox(height: 16),
          for (final cat in ranked)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Material(
                color: c.surface2,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => openCategory(cat),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            cat.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: RatioBar(
                            ratio: stats.categoryTotal(cat.id) / stats.total,
                            color: Color(cat.color),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          formatWon(stats.categoryTotal(cat.id)),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 16, color: c.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
