import 'package:flutter/material.dart';

import '../../domain/import.dart';
import '../theme.dart';

/// 가져올 파일을 엑셀처럼 표로 보여준다.
/// - 맨 위 칸(열마다): 그 열의 역할. 누르면 [onColumnTap].
/// - 왼쪽 줄 번호: 누르면 그 줄을 항목 이름(헤더)으로([onRowTap]).
/// - 헤더 줄은 파란 배경, 헤더 위의 줄(읽지 않음)은 흐리게.
class ImportTableView extends StatelessWidget {
  const ImportTableView({
    super.key,
    required this.table,
    required this.mapping,
    required this.onColumnTap,
    required this.onRowTap,
  });

  final ImportTable table;
  final ImportMapping mapping;
  final ValueChanged<int> onColumnTap;
  final ValueChanged<int> onRowTap;

  static const _cellWidth = 96.0;
  static const _numberWidth = 34.0;
  static const _rowHeight = 34.0;

  /// 보여줄 줄 수: 헤더 아래로 6줄, 적어도 8줄, 최대 30줄.
  int get _visibleRows {
    final want = table.headerRow + 7 < 8 ? 8 : table.headerRow + 7;
    final n = want > 30 ? 30 : want;
    return n > table.raw.length ? table.raw.length : n;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final columns = table.columnCount > 30 ? 30 : table.columnCount;

    Widget box({
      required Widget child,
      required double width,
      Color? color,
      Key? key,
      VoidCallback? onTap,
    }) => InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        width: width,
        height: _rowHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: color,
          border: Border(
            right: BorderSide(color: c.border, width: 0.5),
            bottom: BorderSide(color: c.border, width: 0.5),
          ),
        ),
        child: child,
      ),
    );

    final roleRow = Row(
      children: [
        box(width: _numberWidth, color: c.surface2, child: const SizedBox()),
        for (var col = 0; col < columns; col++)
          () {
            final role = mapping.roleOf(col);
            return box(
              key: ValueKey('role-$col'),
              width: _cellWidth,
              color: role == null ? c.surface2 : c.accent,
              onTap: () => onColumnTap(col),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      role?.label ?? '안 씀',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: role == null ? c.textMuted : c.onAccent,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: role == null ? c.textMuted : c.onAccent,
                  ),
                ],
              ),
            );
          }(),
      ],
    );

    Widget dataRow(int i) {
      final row = table.raw[i];
      final isHeader = i == table.headerRow;
      final above = i < table.headerRow;
      return Row(
        children: [
          box(
            key: ValueKey('row-$i'),
            width: _numberWidth,
            color: isHeader ? c.accent : c.surface2,
            onTap: () => onRowTap(i),
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isHeader ? c.onAccent : c.textMuted,
                ),
              ),
            ),
          ),
          for (var col = 0; col < columns; col++)
            box(
              width: _cellWidth,
              color: isHeader
                  ? c.accentBg
                  : mapping.roleOf(col) != null && !above
                  ? c.surface1
                  : null,
              onTap: () => isHeader || above ? onRowTap(i) : onColumnTap(col),
              child: Text(
                _show(col < row.length ? row[col] : null),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isHeader ? FontWeight.w700 : null,
                  color: above
                      ? c.textMuted
                      : isHeader
                      ? c.accentStrong
                      : c.textPrimary,
                ),
              ),
            ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.borderStrong, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            roleRow,
            for (var i = 0; i < _visibleRows; i++) dataRow(i),
          ],
        ),
      ),
    );
  }
}

String _show(Object? v) {
  if (v == null) return '';
  if (v is DateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${v.year}-${two(v.month)}-${two(v.day)}';
    return v.hour == 0 && v.minute == 0
        ? date
        : '$date ${two(v.hour)}:${two(v.minute)}';
  }
  if (v is double && v == v.roundToDouble()) return v.toInt().toString();
  return v.toString().trim();
}

/// 열의 역할을 고르는 시트. 고르면 그 역할(또는 "안 씀"은 null)을 담아 돌려주고, 닫으면 null.
Future<({ImportRole? role})?> showRolePicker(
  BuildContext context, {
  required int column,
  required String header,
  required ImportMapping mapping,
}) {
  final c = context.colors;
  final current = mapping.roleOf(column);
  return showModalBottomSheet<({ImportRole? role})>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '${column + 1}열 "$header"은(는) 무엇인가요?',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final role in ImportRole.values)
              ListTile(
                key: ValueKey('pick-${role.name}'),
                dense: true,
                title: Text(role.label),
                subtitle: switch (mapping.columnOf(role)) {
                  < 0 => null,
                  final col when col == column => null,
                  final col => Text(
                    '지금은 ${col + 1}열 · 고르면 이 열로 옮겨요',
                    style: TextStyle(fontSize: 11.5, color: c.textMuted),
                  ),
                },
                trailing: current == role
                    ? Icon(Icons.check, color: c.accent)
                    : null,
                onTap: () => Navigator.of(context).pop((role: role)),
              ),
            ListTile(
              key: const ValueKey('pick-none'),
              dense: true,
              title: const Text('안 씀'),
              trailing: current == null
                  ? Icon(Icons.check, color: c.accent)
                  : null,
              onTap: () => Navigator.of(context).pop((role: null)),
            ),
          ],
        ),
      ),
    ),
  );
}
