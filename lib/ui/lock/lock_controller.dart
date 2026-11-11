import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../data/lock_store.dart';
import '../../domain/lock.dart';

/// 앱 잠금 상태.
class AppLockState {
  const AppLockState({
    this.loaded = false,
    this.enabled = false,
    this.locked = false,
    this.biometric = false,
    this.question,
  });

  /// 저장소에서 읽어 왔는지. 읽기 전에는 화면을 가린다.
  final bool loaded;

  /// PIN 잠금을 쓰는지.
  final bool enabled;

  /// 지금 잠겨 있는지.
  final bool locked;

  /// 지문·얼굴 인식을 쓰는지(앱 열기와 PIN 복구에 함께 쓴다).
  final bool biometric;

  /// 비밀번호 찾기 질문(설정하지 않았으면 null).
  final String? question;

  AppLockState copyWith({bool? locked, bool? biometric}) => AppLockState(
    loaded: loaded,
    enabled: enabled,
    locked: locked ?? this.locked,
    biometric: biometric ?? this.biometric,
    question: question,
  );
}

/// 질문에 답한 결과.
sealed class AnswerResult {
  const AnswerResult();
}

class AnswerCorrect extends AnswerResult {
  const AnswerCorrect();
}

class AnswerWrong extends AnswerResult {
  const AnswerWrong(this.attemptsLeft);

  final int attemptsLeft;
}

/// 너무 많이 틀려서 [until]까지 시도할 수 없다.
class AnswerLockedOut extends AnswerResult {
  const AnswerLockedOut(this.until);

  final DateTime until;
}

const _kPinHash = 'lock.pinHash';
const _kPinSalt = 'lock.pinSalt';
const _kBiometric = 'lock.biometric';
const _kQuestion = 'lock.question';
const _kAnswerHash = 'lock.answerHash';
const _kAnswerSalt = 'lock.answerSalt';
const _kAnswerFails = 'lock.answerFails';
const _kAnswerLockedUntil = 'lock.answerLockedUntil';

class LockNotifier extends Notifier<AppLockState> {
  Map<String, String> _values = {};
  DateTime? _backgroundedAt;

  SecretStore get _store => ref.read(secretStoreProvider);
  DateTime get _now => ref.read(clockProvider).now();

  @override
  AppLockState build() {
    _load();
    return const AppLockState();
  }

  /// 앱을 켤 때 한 번: 잠금을 쓰고 있으면 잠긴 상태로 시작한다.
  Future<void> _load() async {
    try {
      _values = await _store.readAll();
    } catch (_) {
      // 보안 저장소를 읽지 못하면(기기 변경 후 복원 등) 잠금이 없는 것으로 본다.
      _values = {};
    }
    state = _stateFromValues(locked: _values.containsKey(_kPinHash));
  }

  AppLockState _stateFromValues({required bool locked}) => AppLockState(
    loaded: true,
    enabled: _values.containsKey(_kPinHash),
    locked: locked,
    biometric: _values[_kBiometric] == '1',
    question: _values[_kQuestion],
  );

  Future<void> _write(String key, String value) async {
    _values[key] = value;
    await _store.write(key, value);
  }

  Future<void> _delete(String key) async {
    _values.remove(key);
    await _store.delete(key);
  }

  bool verifyPin(String pin) {
    final salt = _values[_kPinSalt];
    return salt != null && hashSecret(pin, salt) == _values[_kPinHash];
  }

  /// PIN이 맞으면 잠금을 푼다.
  bool unlockWithPin(String pin) {
    if (!verifyPin(pin)) return false;
    unlock();
    return true;
  }

  void unlock() {
    _backgroundedAt = null;
    state = state.copyWith(locked: false);
  }

  /// PIN을 정한다(처음 켤 때와 바꿀 때). 화면은 잠그지 않는다.
  Future<void> setPin(String pin) async {
    final salt = newSalt();
    await _write(_kPinSalt, salt);
    await _write(_kPinHash, hashSecret(pin, salt));
    state = _stateFromValues(locked: false);
  }

  /// PIN을 잊었을 때 쓸 복구 방법을 정한다. 질문·답이 null이면 질문은 쓰지 않는다.
  Future<void> setRecovery({
    required bool biometric,
    String? question,
    String? answer,
  }) async {
    if (biometric) {
      await _write(_kBiometric, '1');
    } else {
      await _delete(_kBiometric);
    }
    if (question != null && answer != null) {
      final salt = newSalt();
      await _write(_kQuestion, question.trim());
      await _write(_kAnswerSalt, salt);
      await _write(_kAnswerHash, hashSecret(normalizeAnswer(answer), salt));
    } else {
      await _delete(_kQuestion);
      await _delete(_kAnswerSalt);
      await _delete(_kAnswerHash);
    }
    await _delete(_kAnswerFails);
    await _delete(_kAnswerLockedUntil);
    state = _stateFromValues(locked: state.locked);
  }

  /// 잠금을 끄고 잠금 정보를 모두 지운다(앱 전체 초기화에서도 부른다).
  Future<void> disable() async {
    _values = {};
    await _store.deleteAll();
    state = const AppLockState(loaded: true);
  }

  /// 질문 시도가 막혀 있으면 풀리는 시각.
  DateTime? get answerLockedUntil {
    final ms = int.tryParse(_values[_kAnswerLockedUntil] ?? '');
    if (ms == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(ms);
    return until.isAfter(_now) ? until : null;
  }

  /// 질문의 답을 확인한다. 틀린 횟수는 앱을 껐다 켜도 이어진다.
  Future<AnswerResult> checkAnswer(String answer) async {
    final lockedUntil = answerLockedUntil;
    if (lockedUntil != null) return AnswerLockedOut(lockedUntil);
    final salt = _values[_kAnswerSalt];
    if (salt != null &&
        hashSecret(normalizeAnswer(answer), salt) == _values[_kAnswerHash]) {
      await _delete(_kAnswerFails);
      await _delete(_kAnswerLockedUntil);
      return const AnswerCorrect();
    }
    final fails = (int.tryParse(_values[_kAnswerFails] ?? '') ?? 0) + 1;
    if (fails >= maxAnswerAttempts) {
      final until = _now.add(answerLockout);
      await _delete(_kAnswerFails);
      await _write(
        _kAnswerLockedUntil,
        until.millisecondsSinceEpoch.toString(),
      );
      return AnswerLockedOut(until);
    }
    await _write(_kAnswerFails, fails.toString());
    return AnswerWrong(maxAnswerAttempts - fails);
  }

  /// 앱이 백그라운드로 갔다.
  void onBackgrounded() => _backgroundedAt ??= _now;

  /// 앱이 다시 화면에 나왔다. 오래 있다가 돌아왔으면 다시 잠근다.
  void onResumed() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || !state.enabled || state.locked) return;
    if (_now.difference(since) > relockAfter) {
      state = state.copyWith(locked: true);
    }
  }
}

final lockProvider = NotifierProvider<LockNotifier, AppLockState>(
  LockNotifier.new,
);
