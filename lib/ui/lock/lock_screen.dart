import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lock_store.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../analysis/analysis_view.dart';
import '../home/home_view.dart';
import '../navigation.dart';
import '../theme.dart';
import 'lock_controller.dart';
import 'pin_pad.dart';

enum _Mode { unlock, forgot, question, newPin, confirmPin, reset }

/// 잠금 화면. 앱 전체를 덮으며, PIN·지문으로 열거나 PIN을 잊었을 때 복구한다.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  _Mode _mode = _Mode.unlock;
  String _firstPin = '';
  final _answer = TextEditingController();
  String? _message;
  bool _busy = false;

  LockNotifier get _lock => ref.read(lockProvider.notifier);

  @override
  void initState() {
    super.initState();
    // 지문·얼굴 인식을 켜 뒀으면 인식 창을 먼저 띄운다(취소하면 PIN 입력).
    if (ref.read(lockProvider).biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometricUnlock());
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _go(_Mode mode) => setState(() {
    _mode = mode;
    _message = null;
  });

  Future<bool> _biometric(String reason) async {
    if (_busy) return false;
    _busy = true;
    final ok = await ref.read(biometricAuthProvider).authenticate(reason);
    _busy = false;
    return ok;
  }

  Future<void> _biometricUnlock() async {
    if (await _biometric('가계부 잠금을 풀어요') && mounted) _lock.unlock();
  }

  Future<void> _biometricRecover() async {
    final ok = await _biometric('본인 확인 후 새 PIN을 설정해요');
    if (!mounted) return;
    if (ok) {
      _go(_Mode.newPin);
    } else {
      setState(() => _message = '확인하지 못했어요. 다시 시도하거나 다른 방법을 골라주세요.');
    }
  }

  Future<void> _submitAnswer() async {
    if (_answer.text.trim().isEmpty) return;
    final result = await _lock.checkAnswer(_answer.text);
    if (!mounted) return;
    switch (result) {
      case AnswerCorrect():
        _answer.clear();
        _go(_Mode.newPin);
      case AnswerWrong(:final attemptsLeft):
        setState(() => _message = '답이 달라요. $attemptsLeft번 더 시도할 수 있어요.');
      case AnswerLockedOut():
        setState(() => _message = _lockoutMessage());
    }
  }

  String? _lockoutMessage() {
    final until = _lock.answerLockedUntil;
    if (until == null) return null;
    final t = TimeOfDay.fromDateTime(until);
    return '너무 많이 틀렸어요. '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} 이후에 다시 시도해주세요.';
  }

  /// 앱 전체 초기화: 기록·설정·잠금을 모두 지우고 처음 상태로.
  Future<void> _resetEverything() async {
    final container = ProviderScope.containerOf(context);
    await ref.read(databaseProvider).clearRecords();
    container.invalidate(homeViewProvider);
    container.invalidate(analysisViewProvider);
    container.read(appTabProvider.notifier).select(AppTab.home);
    await ref.read(settingsProvider.notifier).clearAll();
    await _lock.disable();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lock = ref.watch(lockProvider);
    return Material(
      color: c.surface0,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: switch (_mode) {
              _Mode.unlock => _unlock(c, lock),
              _Mode.forgot => _forgot(c, lock),
              _Mode.question => _question(c, lock),
              _Mode.newPin => PinPad(
                title: '새 PIN을 설정해주세요',
                onCompleted: (pin) async {
                  _firstPin = pin;
                  _go(_Mode.confirmPin);
                  return null;
                },
              ),
              _Mode.confirmPin => PinPad(
                title: '한 번 더 입력해주세요',
                onCompleted: (pin) async {
                  if (pin != _firstPin) {
                    _go(_Mode.newPin);
                    return '입력한 번호가 서로 달라요. 처음부터 다시 시도해주세요.';
                  }
                  await _lock.setPin(pin);
                  return null;
                },
              ),
              _Mode.reset => _reset(c),
            },
          ),
        ),
      ),
    );
  }

  Widget _unlock(AppColors c, AppLockState lock) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      PinPad(
        title: 'PIN을 입력해주세요',
        onCompleted: (pin) async =>
            _lock.unlockWithPin(pin) ? null : '번호가 올바르지 않아요.',
      ),
      const SizedBox(height: 18),
      if (lock.biometric)
        TextButton.icon(
          onPressed: _biometricUnlock,
          icon: const Icon(Icons.fingerprint),
          label: const Text('지문·얼굴로 열기'),
        ),
      TextButton(
        onPressed: () => _go(_Mode.forgot),
        child: Text(
          'PIN을 잊었어요',
          style: TextStyle(
            fontSize: 12.5,
            color: c.textMuted,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    ],
  );

  Widget _option(
    AppColors c,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: danger ? c.danger : c.textPrimary,
          side: BorderSide(color: danger ? c.danger : c.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label),
      ),
    ),
  );

  Widget _header(AppColors c, String title, String description) => Column(
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        description,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, height: 1.6, color: c.textSecondary),
      ),
      const SizedBox(height: 22),
    ],
  );

  Widget _messageText(AppColors c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      _message ?? '',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: c.danger),
    ),
  );

  Widget _backLink(AppColors c, _Mode to) => TextButton(
    onPressed: () => _go(to),
    child: Text('돌아가기', style: TextStyle(color: c.textMuted)),
  );

  Widget _forgot(AppColors c, AppLockState lock) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _header(
        c,
        'PIN을 잊으셨나요?',
        lock.biometric || lock.question != null
            ? '본인 확인을 하면 데이터는 그대로 두고 새 PIN을 정할 수 있어요.'
            : '복구 방법을 정해두지 않아서, 앱을 처음 상태로 되돌려야만 다시 쓸 수 있어요.',
      ),
      if (_message != null) _messageText(c),
      if (lock.biometric) _option(c, '지문·얼굴 인식으로 확인', _biometricRecover),
      if (lock.question != null)
        _option(c, '질문에 답하기', () {
          _go(_Mode.question);
          setState(() => _message = _lockoutMessage());
        }),
      _option(c, '앱 전체 초기화', () => _go(_Mode.reset), danger: true),
      _backLink(c, _Mode.unlock),
    ],
  );

  Widget _question(AppColors c, AppLockState lock) {
    final lockedOut = _lock.answerLockedUntil != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(c, '질문에 답해주세요', '띄어쓰기와 영문 대소문자는 구분하지 않아요.'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            lock.question ?? '',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _answer,
          enabled: !lockedOut,
          onSubmitted: (_) => _submitAnswer(),
          decoration: InputDecoration(
            hintText: '답',
            isDense: true,
            filled: true,
            fillColor: c.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.border),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _messageText(c),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: lockedOut ? null : _submitAnswer,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('확인'),
          ),
        ),
        _backLink(c, _Mode.forgot),
      ],
    );
  }

  Widget _reset(AppColors c) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _header(
        c,
        '앱 전체를 초기화할까요?',
        '지출·수입 내역, 카테고리, 예산과 모든 설정, 잠금까지 사라지고 처음 상태로 돌아가요.',
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(
          '이 작업은 되돌릴 수 없어요.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.danger,
          ),
        ),
      ),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _resetEverything,
          style: FilledButton.styleFrom(
            backgroundColor: c.danger,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('모두 지우고 초기화하기'),
        ),
      ),
      _backLink(c, _Mode.forgot),
    ],
  );
}

/// 잠겨 있으면 앱 위에 잠금 화면을 덮고, 백그라운드에 오래 있다가 돌아오면 다시 잠근다.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(lockProvider.notifier);
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        lock.onBackgrounded();
      case AppLifecycleState.resumed:
        lock.onResumed();
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockProvider);
    if (!lock.loaded) {
      // 잠금 여부를 알기 전에는 내용을 보여주지 않는다.
      return ColoredBox(color: context.colors.surface0);
    }
    return Stack(
      children: [
        // 잠긴 동안에는 아래 화면이 눌리거나 읽히지 않게 한다.
        ExcludeSemantics(
          excluding: lock.locked,
          child: IgnorePointer(ignoring: lock.locked, child: widget.child),
        ),
        if (lock.locked)
          // 입력 칸(질문의 답)이 쓸 수 있도록 자체 Overlay를 둔다.
          Positioned.fill(
            child: Overlay(
              initialEntries: [
                OverlayEntry(builder: (_) => const LockScreen()),
              ],
            ),
          ),
      ],
    );
  }
}
