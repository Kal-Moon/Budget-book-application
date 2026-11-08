import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';
import 'dates.dart';

/// 오늘 날짜(시각 제외). 날짜가 바뀌면 [TodayNotifier.refresh]가 새 값으로 바꾸고,
/// 이 값을 보는 화면은 자동으로 다시 그려진다.
class TodayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(ref.read(clockProvider).now());

  /// 시계를 다시 읽어서 날짜가 바뀌었으면 갱신한다.
  void refresh() {
    final now = dateOnly(ref.read(clockProvider).now());
    if (now != state) state = now;
  }
}

final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);

/// 이번 달 키('YYYY-MM'). 오늘이 바뀌면 함께 바뀐다.
final currentMonthKeyProvider = Provider<String>(
  (ref) => monthKeyOf(ref.watch(todayProvider)),
);

/// 앱이 다시 화면에 나올 때와 자정이 지날 때 날짜 변경을 확인한다.
/// 앱을 오래 백그라운드에 두었다가 열어도 "오늘"이 틀어지지 않게 한다.
class DateWatcher extends ConsumerStatefulWidget {
  const DateWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DateWatcher> createState() => _DateWatcherState();
}

class _DateWatcherState extends ConsumerState<DateWatcher>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(todayProvider.notifier).refresh();
      _scheduleMidnight();
    }
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = ref.read(clockProvider).now();
    // 자정 직후에 깨어나도록 1초 여유를 둔다.
    _midnightTimer = Timer(
      untilNextMidnight(now) + const Duration(seconds: 1),
      () {
        ref.read(todayProvider.notifier).refresh();
        _scheduleMidnight();
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
