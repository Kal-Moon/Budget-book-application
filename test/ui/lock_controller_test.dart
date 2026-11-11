import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/clock.dart';
import 'package:gagyebu/data/lock_store.dart';
import 'package:gagyebu/domain/lock.dart';
import 'package:gagyebu/ui/lock/lock_controller.dart';

import '../helpers.dart';

void main() {
  late FakeClock clock;

  Future<ProviderContainer> start(MemorySecretStore store) async {
    clock = FakeClock(DateTime(2026, 11, 8, 10));
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        secretStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    container.read(lockProvider);
    await pumpEventQueue();
    return container;
  }

  test('해시: 같은 값·소금이면 같고, 소금이 다르면 다르며, 원래 값이 들어 있지 않다', () {
    expect(hashSecret('1234', 'a'), hashSecret('1234', 'a'));
    expect(hashSecret('1234', 'a'), isNot(hashSecret('1234', 'b')));
    expect(hashSecret('1234', 'a'), isNot(contains('1234')));
    expect(newSalt(), isNot(newSalt()));
  });

  test('답 비교는 띄어쓰기와 영문 대소문자를 무시한다', () {
    expect(normalizeAnswer(' 초 코 '), '초코');
    expect(normalizeAnswer('Co Co'), 'coco');
  });

  test('잠금이 없으면 열린 채로, 있으면 잠긴 채로 시작한다', () async {
    final open = await start(MemorySecretStore());
    expect(open.read(lockProvider).loaded, isTrue);
    expect(open.read(lockProvider).enabled, isFalse);
    expect(open.read(lockProvider).locked, isFalse);

    final locked = await start(lockedStore());
    expect(locked.read(lockProvider).enabled, isTrue);
    expect(locked.read(lockProvider).locked, isTrue);
  });

  test('PIN은 해시로만 저장하고, 맞는 PIN으로만 열린다', () async {
    final store = MemorySecretStore();
    final c = await start(store);
    final lock = c.read(lockProvider.notifier);
    await lock.setPin('4821');

    expect(c.read(lockProvider).enabled, isTrue);
    expect(store.values.values.any((v) => v.contains('4821')), isFalse);
    expect(lock.verifyPin('4821'), isTrue);
    expect(lock.verifyPin('0000'), isFalse);
  });

  test('백그라운드에 1분 넘게 있다가 돌아오면 다시 잠근다(1분 이하는 그대로)', () async {
    final c = await start(lockedStore());
    final lock = c.read(lockProvider.notifier);
    expect(lock.unlockWithPin('1234'), isTrue);

    lock.onBackgrounded();
    clock.current = clock.current.add(const Duration(seconds: 60));
    lock.onResumed();
    expect(c.read(lockProvider).locked, isFalse, reason: '파일 선택처럼 잠깐');

    lock.onBackgrounded();
    clock.current = clock.current.add(const Duration(seconds: 61));
    lock.onResumed();
    expect(c.read(lockProvider).locked, isTrue);
  });

  test('잠금을 쓰지 않으면 오래 있다 와도 잠그지 않는다', () async {
    final c = await start(MemorySecretStore());
    final lock = c.read(lockProvider.notifier);
    lock.onBackgrounded();
    clock.current = clock.current.add(const Duration(hours: 3));
    lock.onResumed();
    expect(c.read(lockProvider).locked, isFalse);
  });

  group('비밀번호 찾기 질문', () {
    test('맞는 답(띄어쓰기·대소문자 무시)이면 통과', () async {
      final c = await start(lockedStore(question: '반려동물 이름은?', answer: 'Coco'));
      final lock = c.read(lockProvider.notifier);
      expect(c.read(lockProvider).question, '반려동물 이름은?');
      expect(await lock.checkAnswer(' co co '), isA<AnswerCorrect>());
    });

    test('5번 틀리면 5분 동안 막히고, 그동안은 맞는 답도 받지 않는다', () async {
      final store = lockedStore(question: 'q', answer: '초코');
      final c = await start(store);
      final lock = c.read(lockProvider.notifier);

      for (var left = 4; left >= 1; left--) {
        final r = await lock.checkAnswer('틀림');
        expect((r as AnswerWrong).attemptsLeft, left);
      }
      expect(await lock.checkAnswer('틀림'), isA<AnswerLockedOut>());
      expect(await lock.checkAnswer('초코'), isA<AnswerLockedOut>());

      // 틀린 횟수와 막힌 시각은 저장소에 남아서 앱을 껐다 켜도 이어진다.
      expect(store.values.containsKey('lock.answerLockedUntil'), isTrue);

      clock.current = clock.current.add(const Duration(minutes: 5, seconds: 1));
      expect(lock.answerLockedUntil, isNull);
      expect(await lock.checkAnswer('초코'), isA<AnswerCorrect>());
    });

    test('맞히면 틀린 횟수가 지워진다', () async {
      final c = await start(lockedStore(question: 'q', answer: '초코'));
      final lock = c.read(lockProvider.notifier);
      for (var i = 0; i < 4; i++) {
        await lock.checkAnswer('틀림');
      }
      expect(await lock.checkAnswer('초코'), isA<AnswerCorrect>());
      final r = await lock.checkAnswer('틀림');
      expect((r as AnswerWrong).attemptsLeft, 4);
    });
  });

  test('잠금을 끄면 잠금 정보가 모두 지워진다', () async {
    final store = lockedStore(biometric: true, question: 'q', answer: 'a');
    final c = await start(store);
    await c.read(lockProvider.notifier).disable();
    expect(store.values, isEmpty);
    expect(c.read(lockProvider).enabled, isFalse);
    expect(c.read(lockProvider).locked, isFalse);
  });
}
