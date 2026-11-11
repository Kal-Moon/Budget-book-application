import 'package:flutter/widgets.dart';

/// 잠겨 있을 때 뒤로가기를 삼킨다(먼저 등록된 관찰자가 처리하면 화면은 닫히지 않는다).
/// 잠금 화면 아래의 화면이 닫히거나 앱 종료 확인창이 뜨지 않게, 앱보다 먼저 등록한다.
class LockedBackBlocker with WidgetsBindingObserver {
  LockedBackBlocker(this.isLocked);

  final bool Function() isLocked;

  @override
  Future<bool> didPopRoute() async => isLocked();
}
