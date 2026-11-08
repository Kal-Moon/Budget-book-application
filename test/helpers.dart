import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gagyebu/core/clock.dart';
import 'package:gagyebu/data/database.dart';

/// 정해진 시각을 돌려주는 테스트용 시계. [now]를 바꿔 날짜 변경을 흉내 낸다.
class FakeClock implements Clock {
  FakeClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}

AppDatabase memoryDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);
