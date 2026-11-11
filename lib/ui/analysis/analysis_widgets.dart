import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../data/database.dart';
import '../theme.dart';

/// 도넛 차트의 한 조각.
class DonutSlice {
  const DonutSlice(this.color, this.value);

  final int color;
  final int value;
}

/// 가운데에 제목과 금액이 들어가는 도넛. 합계가 0이면 회색 빈 원을 그린다
/// (0원 조각을 억지로 그려서 같은 크기로 보이게 하지 않는다).
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.label,
    required this.total,
    this.totalColor,
    this.size = 200,
  });

  final List<DonutSlice> slices;
  final String label;
  final int total;
  final Color? totalColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = slices.where((s) => s.value > 0).toList();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: shown.length > 1 ? 2 : 0,
              centerSpaceRadius: size * 0.34,
              pieTouchData: PieTouchData(enabled: false),
              sections: shown.isEmpty
                  ? [
                      PieChartSectionData(
                        value: 1,
                        color: c.border,
                        radius: size * 0.16,
                        showTitle: false,
                      ),
                    ]
                  : [
                      for (final s in shown)
                        PieChartSectionData(
                          value: s.value.toDouble(),
                          color: Color(s.color),
                          radius: size * 0.16,
                          showTitle: false,
                        ),
                    ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
              const SizedBox(height: 4),
              Text(
                formatWon(total),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: totalColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 가로 막대(비율 0~1).
class RatioBar extends StatelessWidget {
  const RatioBar({super.key, required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(
      value: ratio.clamp(0.0, 1.0),
      minHeight: 8,
      backgroundColor: context.colors.surface0,
      color: color,
    ),
  );
}

/// 수입 · 지출 · 차액 한 줄(분석 화면용).
class AnalysisIncomeStrip extends StatelessWidget {
  const AnalysisIncomeStrip({
    super.key,
    required this.income,
    required this.expense,
  });

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diff = income - expense;
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          col('수입', formatWon(income), c.income),
          col('지출', formatWon(expense), c.textPrimary),
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

/// 아래에서 올라오는 목록 시트의 공통 틀.
Future<void> showListSheet(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: context.colors.surface0,
  builder: (context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  ),
);

/// 카테고리 내역 시트의 한 줄.
class SheetEntryRow extends StatelessWidget {
  const SheetEntryRow({
    super.key,
    required this.entry,
    required this.category,
    required this.onTap,
  });

  final Entry entry;
  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final date = DateTime.parse(entry.date);
    final hasDesc = entry.description.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasDesc ? entry.description : category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: hasDesc ? c.textPrimary : c.textMuted,
                          fontStyle: hasDesc ? null : FontStyle.italic,
                        ),
                      ),
                      Text(
                        '${date.month}월 ${date.day}일 · ${entry.time}',
                        style: TextStyle(fontSize: 11.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatWon(entry.amount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
