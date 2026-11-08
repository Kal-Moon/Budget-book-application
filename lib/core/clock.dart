import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 현재 시각을 알려주는 시계. 테스트에서 날짜를 바꿀 수 있도록 주입해서 쓴다.
/// "오늘"이나 "이번 달"을 따로 저장하지 말고, 필요할 때마다 여기서 읽는다.
class Clock {
  const Clock();

  DateTime now() => DateTime.now();
}

final clockProvider = Provider<Clock>((ref) => const Clock());
