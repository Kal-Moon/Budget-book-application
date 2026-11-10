import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/budget.dart';
import '../../domain/summary.dart';
import '../theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/confirm_sheet.dart';
import 'category_picker_sheet.dart';

/// 내역 입력·수정 화면.
/// 순서: 날짜/시간 → 지출/수입 → 카테고리 → 금액 → 구매처(지출만) → 내역 → 메모.
/// [entry]가 있으면 수정, 없으면 새 입력. 저장·취소·삭제가 끝나면 [onDone].
class EntryEditor extends ConsumerStatefulWidget {
  const EntryEditor({
    super.key,
    this.entry,
    required this.onDone,
    this.handleBack = true,
  });

  final Entry? entry;
  final VoidCallback onDone;

  /// 뒤로가기를 취소로 처리할지. 입력 탭은 다른 탭에 있을 때도 화면에 남아 있으므로
  /// 입력 탭이 열려 있을 때만 켠다.
  final bool handleBack;

  @override
  ConsumerState<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<EntryEditor> {
  late EntryKind _kind;
  late DateTime _date;
  late TimeOfDay _time;
  int? _categoryId;
  final _amount = TextEditingController();
  final _place = TextEditingController();
  final _description = TextEditingController();
  final _memo = TextEditingController();
  final _amountFocus = FocusNode();
  final _placeFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  bool _saving = false;

  /// 입력 중 안내는 이 화면 안(저장 버튼 위)에 띄운다. 앱 전체 안내 자리는
  /// 하단 탭 위라서 이 화면의 저장 버튼을 가린다.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  void _toast(String message) => _messenger.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
      ),
    );

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      _kind = e.kind;
      _date = DateTime.parse(e.date);
      final [h, m] = e.time.split(':').map(int.parse).toList();
      _time = TimeOfDay(hour: h, minute: m);
      _categoryId = e.categoryId;
      _amount.text = formatNumber(e.amount);
      _place.text = e.place;
      _description.text = e.description;
      _memo.text = e.memo;
    } else {
      // 날짜·시간 기본값은 항상 지금(휴대폰 시계).
      _kind = EntryKind.expense;
      _date = ref.read(todayProvider);
      _time = TimeOfDay.fromDateTime(ref.read(clockProvider).now());
    }
    _descriptionFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_amount, _place, _description, _memo]) {
      c.dispose();
    }
    for (final f in [_amountFocus, _placeFocus, _descriptionFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  String get _timeKey =>
      '${_time.hour.toString().padLeft(2, '0')}:'
      '${_time.minute.toString().padLeft(2, '0')}';

  void _setKind(EntryKind kind) {
    if (kind == _kind) return;
    // 지출·수입 카테고리는 서로 다르므로 고른 카테고리를 비운다.
    setState(() {
      _kind = kind;
      _categoryId = null;
    });
  }

  Future<void> _pickCategory() async {
    final id = await showCategoryPicker(
      context,
      kind: _kind,
      selectedId: _categoryId,
    );
    if (id == null || !mounted) return;
    setState(() => _categoryId = id);
    // 카테고리를 고르면 금액 칸으로 자동 이동.
    if (_amount.text.isEmpty) _amountFocus.requestFocus();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount <= 0) {
      _toast(_kind == EntryKind.expense ? '💰 금액을 입력해주세요' : '💰 수입 금액을 입력해주세요');
      return;
    }
    // 고른 카테고리가 카테고리 관리에서 삭제됐을 수도 있다.
    final categories = ref.read(categoryMapProvider).value ?? const {};
    if (!categories.containsKey(_categoryId)) {
      setState(() => _categoryId = null);
      _toast('🗂️ 카테고리를 선택해주세요');
      await _pickCategory();
      return;
    }
    if (ref.read(settingsProvider).mistapProtection) {
      final ok = await showConfirmSheet(
        context,
        title: '저장할까요?',
        description: Text(
          '${formatWon(amount)}을 ${_kind == EntryKind.income ? '수입' : '지출'}으로 저장해요.',
        ),
        confirmLabel: '저장하기',
      );
      if (!ok || !mounted) return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(databaseProvider)
        .saveEntry(
          EntriesCompanion(
            kind: Value(_kind),
            date: Value(dateKeyOf(_date)),
            time: Value(_timeKey),
            categoryId: Value(_categoryId!),
            amount: Value(amount),
            place: Value(_kind == EntryKind.expense ? _place.text.trim() : ''),
            description: Value(_description.text.trim()),
            memo: Value(_memo.text.trim()),
          ),
          id: widget.entry?.id,
        );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _editing
                ? '✓ 수정됐어요'
                : _kind == EntryKind.expense
                ? '✓ ${formatWon(amount)} 저장됐어요'
                : '✓ 수입 ${formatWon(amount)} 저장됐어요',
            textAlign: TextAlign.center,
          ),
        ),
      );
    widget.onDone();
  }

  Future<void> _cancel() async {
    if (ref.read(settingsProvider).mistapProtection) {
      final ok = await showConfirmSheet(
        context,
        title: '정말 나가시겠어요?',
        description: const Text('입력하던 내용이 저장되지 않고 사라져요.'),
        confirmLabel: '나가기',
      );
      if (!ok) return;
    }
    widget.onDone();
  }

  Future<void> _delete() async {
    final ok = await showConfirmSheet(
      context,
      title: '이 내역을 삭제할까요?',
      description: const Text('삭제한 내역은 되돌릴 수 없어요.'),
      confirmLabel: '삭제하기',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(databaseProvider).deleteEntry(widget.entry!.id);
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('삭제됐어요', textAlign: TextAlign.center),
      ),
    );
    widget.onDone();
  }

  /// 저장하면 그 달 예산을 넘게 되는지(지출만).
  String? _warning() {
    if (_kind != EntryKind.expense || _categoryId == null) return null;
    final monthKey = monthKeyOf(_date);
    final entries = ref.watch(monthEntriesProvider(monthKey)).value;
    final budget = ref.watch(monthBudgetProvider(monthKey)).value;
    final category = ref.watch(categoryMapProvider).value?[_categoryId];
    if (entries == null || budget == null || category == null) return null;
    final others = entries.where(
      (e) => e.kind == EntryKind.expense && e.id != widget.entry?.id,
    );
    final byCategory = budget.mode == BudgetMode.category;
    return budgetWarning(
      label: byCategory ? category.name : '${_date.month}월',
      spentBefore: byCategory
          ? EntryTotals(others).spentIn(category.id)
          : EntryTotals(others).expense,
      amount: parseAmount(_amount.text),
      budget: byCategory
          ? budget.categoryBudget(category.id)
          : budget.totalBudget,
      thresholdPercent: ref.watch(
        settingsProvider.select((s) => s.budgetThreshold),
      ),
    );
  }

  List<String> _suggestions() {
    if (!_descriptionFocus.hasFocus || _categoryId == null) return const [];
    final all = ref.watch(allEntriesProvider).value ?? const [];
    return suggestDescriptions(
      all.where((e) => e.kind == _kind && e.categoryId == _categoryId),
      _description.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final expense = _kind == EntryKind.expense;
    final category = ref.watch(categoryMapProvider).value?[_categoryId];
    final warning = _warning();
    final suggestions = _suggestions();

    return PopScope(
      canPop: !widget.handleBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('내역 입력'),
            automaticallyImplyLeading: false,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              const _Label('날짜 & 시간'),
              Row(
                children: [
                  Expanded(
                    child: _PickerButton(
                      icon: Icons.calendar_today_outlined,
                      label: '날짜',
                      value:
                          '${_date.year}.${_date.month.toString().padLeft(2, '0')}.'
                          '${_date.day.toString().padLeft(2, '0')}',
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _PickerButton(
                      icon: Icons.schedule,
                      label: '시간',
                      value: _timeKey,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _KindButton(
                      label: '지출',
                      selected: expense,
                      color: c.accent,
                      background: c.accentBg,
                      onTap: () => _setKind(EntryKind.expense),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _KindButton(
                      label: '수입',
                      selected: !expense,
                      color: c.income,
                      background: c.incomeBg,
                      onTap: () => _setKind(EntryKind.income),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _Label('카테고리'),
              Material(
                color: c.surface2,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: c.border, width: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _pickCategory,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: category == null
                              ? Text(
                                  '카테고리를 선택하세요',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: c.textMuted,
                                  ),
                                )
                              : Text(
                                  '${category.icon}  ${category.name}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        Icon(Icons.chevron_right, color: c.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      expense ? '얼마를 사용했나요?' : '얼마를 받았나요?',
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        SizedBox(
                          width: 210,
                          child: TextField(
                            controller: _amount,
                            focusNode: _amountFocus,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: const [ThousandsFormatter()],
                            textAlign: TextAlign.right,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) =>
                                (expense ? _placeFocus : _descriptionFocus)
                                    .requestFocus(),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '원',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (warning != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.dangerBg,
                    border: Border.all(color: c.danger, width: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: c.danger,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          warning,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFA32D2D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (expense) ...[
                const SizedBox(height: 16),
                const _Label('구매처'),
                _TextBox(
                  controller: _place,
                  focusNode: _placeFocus,
                  hint: '예: 이마트, 쿠팡 (선택)',
                  onSubmitted: () => _descriptionFocus.requestFocus(),
                ),
              ],
              const SizedBox(height: 16),
              const _Label('내역'),
              _TextBox(
                controller: _description,
                focusNode: _descriptionFocus,
                hint: expense ? '예: 라면 (선택)' : '예: 11월 급여 (선택)',
                onChanged: () => setState(() {}),
              ),
              for (final s in suggestions)
                Material(
                  color: c.surface0,
                  child: InkWell(
                    onTap: () {
                      _description.text = s;
                      _descriptionFocus.unfocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 15, color: c.textMuted),
                          const SizedBox(width: 8),
                          Text(s, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '비워두면 목록에는 카테고리 이름으로 표시돼요',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),
              ),
              Divider(color: c.border, height: 28),
              const _Label('메모'),
              _TextBox(
                controller: _memo,
                hint: '추가로 남기고 싶은 메모 (선택)',
                maxLines: 2,
              ),
              if (_editing) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.danger,
                    side: BorderSide(color: c.danger, width: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('이 내역 삭제하기'),
                ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: c.surface0,
                border: Border(top: BorderSide(color: c.border, width: 0.5)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('저장'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.colors.textMuted,
      ),
    ),
  );
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface2,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: c.border, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 10.5, color: c.textMuted),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindButton extends StatelessWidget {
  const _KindButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? background : c.surface2,
          border: Border.all(color: selected ? color : c.border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? color : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TextBox extends StatelessWidget {
  const _TextBox({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;
  final VoidCallback? onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13.5, color: c.textMuted),
        isDense: true,
        filled: true,
        fillColor: c.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border, width: 0.5),
        ),
      ),
    );
  }
}
