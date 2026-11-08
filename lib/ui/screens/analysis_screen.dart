import 'package:flutter/material.dart';

import 'coming_soon.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoon(
    title: '분석',
    message: '카테고리 비중, 월별 추이, 연간 통계는\n다음 단계에서 옮겨올 예정이에요',
  );
}
