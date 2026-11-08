import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gagyebu/core/clock.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/domain/budget.dart';

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

/// 테스트용 내역 추가. [categoryId]는 기본 카테고리 순서 기준
/// (지출 1 식비, 2 교통, 3 카페, 4 쇼핑 / 수입 5 월급, 6 용돈, 7 부수입, 8 금융수입).
Future<int> addEntry(
  AppDatabase db, {
  EntryKind kind = EntryKind.expense,
  required String date,
  String time = '12:00',
  required int categoryId,
  required int amount,
  String description = '',
  String place = '',
  String memo = '',
}) => db
    .into(db.entries)
    .insert(
      EntriesCompanion.insert(
        kind: kind,
        date: date,
        time: time,
        categoryId: categoryId,
        amount: amount,
        description: Value(description),
        place: Value(place),
        memo: Value(memo),
      ),
    );
