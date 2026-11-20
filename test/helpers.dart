import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/clock.dart';
import 'package:gagyebu/data/settings.dart';
import 'package:gagyebu/data/database.dart';
import 'package:gagyebu/data/lock_store.dart';
import 'package:gagyebu/domain/budget.dart';
import 'package:gagyebu/domain/lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 정해진 시각을 돌려주는 테스트용 시계. [now]를 바꿔 날짜 변경을 흉내 낸다.
class FakeClock implements Clock {
  FakeClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}

/// 가짜 시계와 설정 저장소를 넣은 컨테이너(화면 없이 프로바이더만 확인할 때).
/// [settings]는 'settings.' 접두어를 뺀 이름 → 값.
Future<ProviderContainer> clockContainer(
  FakeClock clock, {
  Map<String, Object> settings = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    for (final MapEntry(:key, :value) in settings.entries)
      'settings.$key': value,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(clock),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return container;
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

/// 메모리에만 두는 보안 저장소(테스트용).
class MemorySecretStore implements SecretStore {
  MemorySecretStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<Map<String, String>> readAll() async => {...values};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

/// 이미 잠금이 켜져 있는 저장소를 만든다.
MemorySecretStore lockedStore({
  String pin = '1234',
  bool biometric = false,
  String? question,
  String? answer,
}) => MemorySecretStore({
  'lock.pinSalt': 's1',
  'lock.pinHash': hashSecret(pin, 's1'),
  if (biometric) 'lock.biometric': '1',
  if (question != null && answer != null) ...{
    'lock.question': question,
    'lock.answerSalt': 's2',
    'lock.answerHash': hashSecret(normalizeAnswer(answer), 's2'),
  },
});

/// 정해 둔 대로 답하는 지문·얼굴 인식(테스트용).
class FakeBiometricAuth implements BiometricAuth {
  FakeBiometricAuth({this.available = false, this.succeeds = false});

  bool available;
  bool succeeds;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return succeeds;
  }
}
