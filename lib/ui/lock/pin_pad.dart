import 'package:flutter/material.dart';

import '../../domain/lock.dart';
import '../theme.dart';

/// PIN 입력: 제목, 점 4개, 숫자판.
/// 4자리를 다 누르면 [onCompleted]를 부르고, 오류 문구를 돌려주면 빨갛게 보여준 뒤 비운다.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    this.subtitle = '4자리 숫자를 입력하세요',
    required this.onCompleted,
  });

  final String title;
  final String subtitle;
  final Future<String?> Function(String pin) onCompleted;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _buffer = '';
  String? _error;
  bool _busy = false;

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    // 단계가 바뀌면(예: 새 PIN → 한 번 더) 입력을 비운다.
    // 오류 문구는 지우지 않는다("번호가 서로 달라요"는 처음 단계로 돌아간 뒤에 보여야 한다).
    if (old.title != widget.title) _buffer = '';
  }

  Future<void> _press(String digit) async {
    if (_busy || _buffer.length >= pinLength) return;
    setState(() {
      _buffer += digit;
      _error = null;
    });
    if (_buffer.length < pinLength) return;
    _busy = true;
    final error = await widget.onCompleted(_buffer);
    _busy = false;
    if (!mounted) return;
    setState(() {
      _error = error;
      _buffer = '';
    });
  }

  void _backspace() {
    if (_busy || _buffer.isEmpty) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget key(String label, {VoidCallback? onTap, String? semantics}) =>
        SizedBox(
          width: 68,
          height: 68,
          child: onTap == null
              ? null
              : Semantics(
                  label: semantics,
                  button: true,
                  child: Material(
                    color: c.surface2,
                    shape: CircleBorder(
                      side: BorderSide(color: c.border, width: 0.5),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onTap,
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: c.textSecondary),
        ),
        const SizedBox(height: 26),
        Semantics(
          label: 'PIN ${_buffer.length}자리 입력됨',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < pinLength; i++)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _error != null
                        ? c.danger
                        : i < _buffer.length
                        ? c.accent
                        : Colors.transparent,
                    border: Border.all(
                      color: _error != null
                          ? c.danger
                          : i < _buffer.length
                          ? c.accent
                          : c.borderStrong,
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: Center(
            child: Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.danger),
            ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, d) in row.indexed) ...[
                  if (i > 0) const SizedBox(width: 14),
                  key(d, onTap: () => _press(d)),
                ],
              ],
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            key(''),
            const SizedBox(width: 14),
            key('0', onTap: () => _press('0')),
            const SizedBox(width: 14),
            key('⌫', onTap: _backspace, semantics: '지우기'),
          ],
        ),
      ],
    );
  }
}
