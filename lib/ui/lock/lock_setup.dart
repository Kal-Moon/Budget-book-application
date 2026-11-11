import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lock_store.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import 'lock_controller.dart';
import 'pin_pad.dart';

Future<T?> _push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<T>(builder: (_) => page));

/// 현재 PIN을 맞게 입력하면 true(잠금 설정을 바꾸기 전에 확인).
Future<bool> confirmCurrentPin(BuildContext context) async =>
    await _push<bool>(context, const _PinCheckPage()) ?? false;

/// 새 PIN을 두 번 입력받는다. 취소하면 null.
Future<String?> askNewPin(BuildContext context) =>
    _push<String>(context, const _NewPinPage());

/// 복구 방법(지문·얼굴, 비밀번호 찾기 질문)을 고르고 저장한다. 저장하면 true.
Future<bool> editRecovery(BuildContext context) async =>
    await _push<bool>(context, const _RecoveryPage()) ?? false;

/// 잠금 켜기: 새 PIN → 복구 방법. 복구 방법까지 마쳐야 잠금이 켜진다.
Future<void> startLockSetup(BuildContext context, WidgetRef ref) async {
  final pin = await askNewPin(context);
  if (pin == null || !context.mounted) return;
  final done = await _push<bool>(context, _RecoveryPage(newPin: pin)) ?? false;
  if (done && context.mounted) showToast(context, '✓ 앱 잠금이 설정됐어요');
}

class _PinCheckPage extends ConsumerWidget {
  const _PinCheckPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('PIN 확인')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: PinPad(
          title: '현재 PIN을 입력해주세요',
          onCompleted: (pin) async {
            if (!ref.read(lockProvider.notifier).verifyPin(pin)) {
              return '번호가 올바르지 않아요.';
            }
            Navigator.of(context).pop(true);
            return null;
          },
        ),
      ),
    ),
  );
}

class _NewPinPage extends StatefulWidget {
  const _NewPinPage();

  @override
  State<_NewPinPage> createState() => _NewPinPageState();
}

class _NewPinPageState extends State<_NewPinPage> {
  String? _first;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PIN 설정')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: PinPad(
          title: _first == null ? '새 PIN을 설정해주세요' : '한 번 더 입력해주세요',
          onCompleted: (pin) async {
            final first = _first;
            if (first == null) {
              setState(() => _first = pin);
              return null;
            }
            if (pin != first) {
              setState(() => _first = null);
              return '입력한 번호가 서로 달라요. 처음부터 다시 시도해주세요.';
            }
            Navigator.of(context).pop(pin);
            return null;
          },
        ),
      ),
    ),
  );
}

/// 복구 방법 고르기. [newPin]이 있으면 잠금을 처음 켜는 중이라 PIN도 함께 저장한다.
class _RecoveryPage extends ConsumerStatefulWidget {
  const _RecoveryPage({this.newPin});

  final String? newPin;

  @override
  ConsumerState<_RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends ConsumerState<_RecoveryPage> {
  bool? _biometricAvailable;
  late bool _useBiometric = ref.read(lockProvider).biometric;
  late bool _useQuestion = ref.read(lockProvider).question != null;
  // dispose에서 처음 만들어지는 일이 없도록 initState에서 만든다.
  late final TextEditingController _question;
  final _answer = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _question = TextEditingController(
      text: ref.read(lockProvider).question ?? '',
    );
    ref.read(biometricAuthProvider).isAvailable().then((available) {
      if (!mounted) return;
      setState(() {
        _biometricAvailable = available;
        if (!available) _useBiometric = false;
      });
    });
  }

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_useQuestion &&
        (_question.text.trim().isEmpty || _answer.text.trim().isEmpty)) {
      setState(() => _error = '질문과 답을 모두 입력해주세요.');
      return;
    }
    setState(() => _error = null);
    if (!_useBiometric && !_useQuestion) {
      final ok = await showConfirmSheet(
        context,
        title: '복구 방법 없이 켤까요?',
        description: const Text(
          'PIN을 잊으면 데이터를 되찾을 수 없어요. 앱을 처음 상태로 되돌려야만 다시 쓸 수 있어요.',
        ),
        confirmLabel: '그래도 켜기',
        cancelLabel: '다시 고르기',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final lock = ref.read(lockProvider.notifier);
    final wasBiometric = ref.read(lockProvider).biometric;
    if (_useBiometric && !wasBiometric) {
      // 켜기 전에 실제로 인식되는지 한 번 확인한다.
      final ok = await ref
          .read(biometricAuthProvider)
          .authenticate('지문·얼굴 인식을 앱 잠금에 사용해요');
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = '지문·얼굴을 확인하지 못했어요. 다시 시도하거나 체크를 풀어주세요.');
        return;
      }
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    if (widget.newPin case final pin?) await lock.setPin(pin);
    await lock.setRecovery(
      biometric: _useBiometric,
      question: _useQuestion ? _question.text : null,
      answer: _useQuestion ? _answer.text : null,
    );
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final available = _biometricAvailable;
    final fieldDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: c.surface0,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: c.border),
      ),
    );
    Widget option({
      required String label,
      required String description,
      required bool value,
      required ValueChanged<bool>? onChanged,
      Widget? child,
    }) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 10),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: value ? c.accent : c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: label,
                child: Checkbox(
                  key: ValueKey('recovery-$label'),
                  value: value,
                  onChanged: onChanged == null
                      ? null
                      : (v) => onChanged(v ?? false),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (child != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 0, 0),
              child: child,
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('PIN을 잊었을 때')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        children: [
          Text(
            'PIN을 잊었을 때 어떻게 확인할까요?',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '하나만 골라도, 둘 다 골라도 돼요. 확인되면 데이터는 그대로 두고 새 PIN을 정할 수 있어요.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          option(
            label: '지문·얼굴 인식',
            description: available == false
                ? '이 기기에 등록된 지문·얼굴이 없어서 쓸 수 없어요.'
                : '켜두면 앱을 열 때도 PIN 대신 지문·얼굴로 열 수 있어요.',
            value: _useBiometric,
            onChanged: available == true
                ? (v) => setState(() => _useBiometric = v)
                : null,
          ),
          option(
            label: '비밀번호 찾기 질문',
            description: '질문과 답을 직접 만들어요.',
            value: _useQuestion,
            onChanged: (v) => setState(() => _useQuestion = v),
            child: !_useQuestion
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _question,
                        maxLength: 40,
                        decoration: fieldDecoration.copyWith(
                          labelText: '질문',
                          hintText: '예: 첫 번째 반려동물 이름은?',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _answer,
                        maxLength: 40,
                        decoration: fieldDecoration.copyWith(
                          labelText: '답',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '가족도 모르는 나만 아는 답으로 정해주세요. 답은 암호화해서 저장해서 '
                        '나중에 다시 볼 수 없어요. 띄어쓰기와 영문 대소문자는 구분하지 않아요.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.6,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: c.danger),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: FilledButton(
            onPressed: available == null || _saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(widget.newPin == null ? '저장' : '잠금 켜기'),
          ),
        ),
      ),
    );
  }
}
