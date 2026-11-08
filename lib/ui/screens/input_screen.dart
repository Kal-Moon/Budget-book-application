import 'package:flutter/material.dart';

import 'coming_soon.dart';

class InputScreen extends StatelessWidget {
  const InputScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoon(
    title: '내역 입력',
    message: '지출·수입 입력 화면은\n다음 단계에서 옮겨올 예정이에요',
  );
}
