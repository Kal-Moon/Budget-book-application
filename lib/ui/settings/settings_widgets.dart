import 'package:flutter/material.dart';

import '../theme.dart';

/// 설정 화면의 묶음 제목.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.colors.textMuted,
          ),
        ),
        const SizedBox(height: 9),
        ...children,
      ],
    ),
  );
}

/// 누르면 다른 화면·시트로 가는 줄.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.value,
    required this.onTap,
    this.danger = false,
  });

  final String label;

  /// 오른쪽에 보여줄 현재 값(없으면 화살표만).
  final String? value;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: c.surface2,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.border, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: danger ? c.danger : c.textPrimary,
                    ),
                  ),
                ),
                if (!danger)
                  Text(
                    value == null ? '›' : '$value ›',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 켜고 끄는 줄.
class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13.5)),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      description!,
                      style: TextStyle(fontSize: 11.5, color: c.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: label,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// 여러 값 중 하나를 고르는 버튼 줄.
class SettingsChoice<T> extends StatelessWidget {
  const SettingsChoice({
    super.key,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> items;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(item),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                decoration: BoxDecoration(
                  color: item == selected ? c.accentBg : c.surface2,
                  border: Border.all(
                    color: item == selected ? c.accent : c.border,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labelOf(item),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: item == selected ? c.accent : c.textSecondary,
                    fontWeight: item == selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 설정 항목 아래의 작은 설명.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        height: 1.6,
        color: context.colors.textMuted,
      ),
    ),
  );
}
