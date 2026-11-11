import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/analysis.dart';
import '../../domain/budget.dart';
import '../home/home_widgets.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import 'analysis_view.dart';
import 'analysis_widgets.dart';

/// 월별 추이: 이번 달에서 끝나는 최근 3/6/12개월의 지출.
class TrendPane extends ConsumerWidget {
  const TrendPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final view = ref.watch(analysisViewProvider);
    final notifier = ref.read(analysisViewProvider.notifier);
    final entries = ref.watch(allEntriesProvider).value;
    final budgets = ref.watch(allBudgetsProvider).value;
    final threshold = ref.watch(
      settingsProvider.select((s) => s.budgetThreshold),
    );
    if (entries == null || budgets == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // 추이는 항상 이번 달에서 끝난다(홈이나 도넛에서 보던 달과 무관).
    final months = monthlyExpenseTotals(
      entries,
      ref.watch(currentMonthKeyProvider),
      view.range,
    );
    final stats = TrendStats(months);
    int budgetOf(String key) => budgets[key]?.totalBudget ?? 0;
    bool overIn(MonthTotal m) =>
        isOverBudget(m.total, budgetOf(m.monthKey), threshold);
    final maxValue = months.fold(
      1,
      (v, m) => math.max(v, math.max(m.total, budgetOf(m.monthKey))),
    );
    final diff = stats.difference;
    final diffColor = diff > 0
        ? c.danger
        : diff < 0
        ? const Color(0xFF185FA5)
        : c.textPrimary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        ChoiceChipRow<int>(
          items: const [3, 6, 12],
          selected: view.range,
          expand: true,
          labelOf: (n) => '$n개월',
          onSelected: notifier.setRange,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Semantics(
            label: '월별 지출 추이 그래프',
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxValue * 1.15,
                lineTouchData: const LineTouchData(enabled: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: c.border, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (value != i.toDouble() ||
                            i < 0 ||
                            i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        // 12개월은 글자가 겹치지 않게 한 칸씩 건너 표시한다.
                        if (months.length > 6 &&
                            (months.length - 1 - i).isOdd) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            months[i].label,
                            style: TextStyle(fontSize: 10, color: c.textMuted),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  // 예산 선(점선)
                  LineChartBarData(
                    spots: [
                      for (final (i, m) in months.indexed)
                        FlSpot(i.toDouble(), budgetOf(m.monthKey).toDouble()),
                    ],
                    color: c.borderStrong,
                    barWidth: 1.5,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
                  // 지출 선(초과한 달은 빨간 점)
                  LineChartBarData(
                    spots: [
                      for (final (i, m) in months.indexed)
                        FlSpot(i.toDouble(), m.total.toDouble()),
                    ],
                    color: c.accent,
                    barWidth: 2,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: c.accent.withValues(alpha: 0.12),
                    ),
                    dotData: FlDotData(
                      getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
                        radius: 4,
                        color: overIn(months[i]) ? c.danger : c.accent,
                        strokeWidth: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatCard(label: '평균 지출', value: formatWon(stats.average)),
            const SizedBox(width: 9),
            _StatCard(
              label: '전월 대비',
              value: '${diff >= 0 ? '+' : ''}${formatWon(diff)}',
              sub: stats.previous == null
                  ? null
                  : percentChange(stats.previous!, stats.last),
              color: diffColor,
            ),
            const SizedBox(width: 9),
            _StatCard(
              label: '최고 지출월',
              value: stats.highest == null || stats.highest!.total == 0
                  ? '-'
                  : stats.highest!.label,
              sub: stats.highest == null || stats.highest!.total == 0
                  ? null
                  : formatWon(stats.highest!.total),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final (i, m) in months.indexed.toList().reversed)
          _MonthRow(
            month: m,
            ratio: m.total / maxValue,
            over: overIn(m),
            delta: i > 0 ? m.total - months[i - 1].total : null,
            deltaPercent: i > 0
                ? percentChange(months[i - 1].total, m.total)
                : null,
            onTap: () {
              notifier.showMonth(m.monthKey);
              showToast(context, '${m.label} 카테고리별 분석으로 이동했어요');
            },
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.sub,
    this.color,
  });

  final String label;
  final String value;
  final String? sub;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10.5, color: c.textMuted)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (sub != null)
              Text(
                sub!,
                style: TextStyle(fontSize: 10, color: color ?? c.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.month,
    required this.ratio,
    required this.over,
    required this.delta,
    required this.deltaPercent,
    required this.onTap,
  });

  final MonthTotal month;
  final double ratio;
  final bool over;
  final int? delta;
  final String? deltaPercent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = delta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        month.label,
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: RatioBar(
                        ratio: ratio,
                        color: over ? c.danger : c.accent,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      formatWon(month.total),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: c.textMuted),
                  ],
                ),
                if (d != null && d != 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 16),
                      child: Text(
                        '${d > 0 ? '▲' : '▼'} ${formatNumber(d.abs())} ($deltaPercent)',
                        style: TextStyle(
                          fontSize: 10,
                          color: d > 0 ? c.danger : const Color(0xFF185FA5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
