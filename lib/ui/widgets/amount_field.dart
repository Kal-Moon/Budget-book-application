import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _grouping = NumberFormat('#,###', 'ko_KR');

/// 숫자만 받고 세 자리마다 쉼표를 넣는다. 최대 12자리(1조 원 미만).
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > 12) return oldValue;
    final text = _grouping.format(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// 입력 칸의 글자에서 금액을 읽는다. 비어 있으면 0.
int parseAmount(String text) =>
    int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// 금액 입력 칸. 비어 있으면 회색 '0'만 보인다(미리 채운 금액 없음).
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.onChanged,
    this.style,
    this.textAlign = TextAlign.right,
    this.decoration,
  });

  final TextEditingController controller;
  final ValueChanged<int>? onChanged;
  final TextStyle? style;
  final TextAlign textAlign;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: const [ThousandsFormatter()],
    textAlign: textAlign,
    style: style,
    decoration:
        decoration ??
        const InputDecoration(
          hintText: '0',
          border: InputBorder.none,
          isDense: true,
        ),
    onChanged: (t) => onChanged?.call(parseAmount(t)),
  );
}
