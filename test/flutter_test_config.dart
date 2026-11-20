import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// 모든 테스트 전에 한 번: 한국어 날짜 형식(요일 이름 등)을 준비한다.
/// 앱에서는 main()이 같은 일을 한다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting('ko_KR');
  await testMain();
}
