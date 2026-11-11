import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/analysis_view.dart';
import '../analysis/donut_pane.dart';
import '../analysis/trend_pane.dart';
import '../analysis/year_pane.dart';
import '../home/home_widgets.dart';
import '../theme.dart';

/// 분석 탭: 카테고리 비중 / 월별 추이 / 연간 통계.
class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(analysisViewProvider.select((v) => v.tab));
    return Scaffold(
      appBar: AppBar(title: const Text('분석')),
      body: Column(
        children: [
          Container(
            color: context.colors.surface2,
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
            child: ChoiceChipRow<AnalysisTab>(
              items: AnalysisTab.values,
              selected: tab,
              expand: true,
              labelOf: (t) => switch (t) {
                AnalysisTab.donut => '카테고리 비중',
                AnalysisTab.trend => '월별 추이',
                AnalysisTab.year => '연간 통계',
              },
              onSelected: ref.read(analysisViewProvider.notifier).setTab,
            ),
          ),
          Expanded(
            child: switch (tab) {
              AnalysisTab.donut => const DonutPane(),
              AnalysisTab.trend => const TrendPane(),
              AnalysisTab.year => const YearPane(),
            },
          ),
        ],
      ),
    );
  }
}
