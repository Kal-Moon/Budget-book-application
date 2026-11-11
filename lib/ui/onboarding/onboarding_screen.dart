import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/budget.dart';
import '../../domain/categories.dart';
import '../settings/backup_flow.dart';
import '../theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/confirm_sheet.dart';

/// 온보딩 5단계: 환영 → 예산 방식 → 카테고리 → 금액 → 검토.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

const _stepCount = 5;

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  BudgetMode _mode = BudgetMode.total;
  List<_EditableCategory>? _categories;
  final _totalController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final rows = await ref
        .read(databaseProvider)
        .watchCategories(EntryKind.expense)
        .first;
    if (!mounted) return;
    setState(() {
      _categories = [
        for (final c in rows)
          _EditableCategory(
            CategoryDraft(id: c.id, name: c.name, icon: c.icon, color: c.color),
          ),
      ];
    });
  }

  @override
  void dispose() {
    _totalController.dispose();
    for (final c in _categories ?? const <_EditableCategory>[]) {
      c.dispose();
    }
    super.dispose();
  }

  List<_EditableCategory> get _cats => _categories ?? const [];

  String? _nameError(_EditableCategory cat) => validateCategoryName(
    cat.nameController.text,
    _cats.where((o) => o != cat).map((o) => o.nameController.text),
  );

  bool get _categoriesValid =>
      _cats.isNotEmpty && _cats.every((c) => _nameError(c) == null);

  int get _categorySum =>
      _cats.fold(0, (s, c) => s + parseAmount(c.amountController.text));

  int get _totalBudget => _mode == BudgetMode.total
      ? parseAmount(_totalController.text)
      : _categorySum;

  /// 올바른 이름은 저장 대상에 반영하고, 잘못된 이름은 마지막 올바른 이름으로 되돌린다.
  void _syncNames() {
    for (final c in _cats) {
      _nameError(c) == null ? c.acceptName() : c.revertName();
    }
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    _syncNames();
    setState(() => _step = step);
  }

  Future<void> _next() async {
    if (_step == _stepCount - 1) return _finish(skipped: false);
    _goTo(_step + 1);
  }

  void _addCategory() {
    final i = _cats.length;
    setState(() {
      _categories = [
        ..._cats,
        _EditableCategory(
          CategoryDraft(
            name: uniqueNewCategoryName(
              _cats.map((c) => c.nameController.text),
            ),
            icon: newCategoryEmojis[i % newCategoryEmojis.length],
            color: newCategoryColor,
          ),
        ),
      ];
    });
  }

  void _removeCategory(_EditableCategory cat) {
    if (_cats.length <= 1) {
      showToast(context, '카테고리는 최소 1개 필요해요');
      return;
    }
    setState(() => _categories = [..._cats.where((c) => c != cat)]);
    cat.dispose();
  }

  Future<void> _confirmSkip() async {
    final ok = await showConfirmSheet(
      context,
      title: '온보딩을 건너뛸까요?',
      description: const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '지금까지의 설명을 전부 건너뛰고 '),
            TextSpan(
              text: '바로 홈 화면',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: '으로 이동해요.\n\n예산은 '),
            TextSpan(
              text: '0원',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: '으로 시작하고, 나중에 '),
            TextSpan(
              text: '설정 › 예산 설정 바꾸기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: '에서 언제든 정할 수 있어요.'),
          ],
        ),
      ),
      confirmLabel: '네, 건너뛸게요',
      cancelLabel: '아니요, 계속할게요',
    );
    if (ok) await _finish(skipped: true);
  }

  /// 저장하고 홈으로. 건너뛰면 카테고리 편집만 남기고 예산은 0원.
  Future<void> _finish({required bool skipped}) async {
    if (_saving) return;
    _syncNames();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final cats = _cats;
    await ref
        .read(databaseProvider)
        .saveOnboarding(
          drafts: [for (final c in cats) c.draft],
          monthKey: ref.read(currentMonthKeyProvider),
          mode: skipped ? null : _mode,
          total: parseAmount(_totalController.text),
          categoryAmounts: {
            for (final (i, c) in cats.indexed)
              i: parseAmount(c.amountController.text),
          },
        );
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(onboardingDone: true));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          skipped ? '건너뛰었어요 · 예산은 설정에서 정할 수 있어요' : '🎉 가계부 시작!',
          textAlign: TextAlign.center,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_categories == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canGoNext = _step != 2 || _categoriesValid;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _goTo(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                step: _step,
                onBack: _step > 0 ? () => _goTo(_step - 1) : null,
                onSkip: _step < _stepCount - 1 ? _confirmSkip : null,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
                  child: switch (_step) {
                    0 => _WelcomeStep(
                      onRestore: () => startRestoreFlow(context, ref),
                    ),
                    1 => _ModeStep(
                      mode: _mode,
                      onChanged: (m) => setState(() => _mode = m),
                    ),
                    2 => _CategoryStep(
                      categories: _cats,
                      errorOf: _nameError,
                      onChanged: () => setState(() {}),
                      onRemove: _removeCategory,
                      onAdd: _addCategory,
                    ),
                    3 => _AmountStep(
                      mode: _mode,
                      categories: _cats,
                      totalController: _totalController,
                      categorySum: _categorySum,
                      onChanged: () => setState(() {}),
                    ),
                    _ => _ReviewStep(
                      mode: _mode,
                      total: _totalBudget,
                      categories: _cats,
                    ),
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: canGoNext && !_saving ? _next : null,
                    child: Text(switch (_step) {
                      0 => '시작하기',
                      4 => '가계부 시작하기',
                      _ => '다음',
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 편집 중인 카테고리 한 줄: 이름 칸과 금액 칸을 함께 가진다.
class _EditableCategory {
  _EditableCategory(this.draft)
    : nameController = TextEditingController(text: draft.name),
      _lastValidName = draft.name;

  final CategoryDraft draft;
  final TextEditingController nameController;
  final amountController = TextEditingController();
  String _lastValidName;

  /// 이름이 올바르면 저장 대상에 반영한다.
  void acceptName() {
    draft.name = nameController.text.trim();
    _lastValidName = draft.name;
  }

  /// 빈 이름·중복 이름으로 칸을 떠나면 마지막 올바른 이름으로 되돌린다.
  void revertName() {
    nameController.text = _lastValidName;
    draft.name = _lastValidName;
  }

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, this.onBack, this.onSkip});

  final int step;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    tooltip: '뒤로가기',
                    icon: Icon(Icons.chevron_left, color: c.textSecondary),
                  ),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < _stepCount; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= step ? c.accent : c.surface2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: onSkip == null
                ? null
                : TextButton(
                    onPressed: onSkip,
                    child: Text(
                      '건너뛰기',
                      style: TextStyle(fontSize: 13, color: c.textMuted),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.title, this.description);

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onRestore});

  /// 폰을 바꿨을 때: 백업 파일로 바로 시작한다.
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget feature(String icon, String text) => Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );

    return Column(
      children: [
        const SizedBox(height: 22),
        const Text('💰', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text(
          '가계부에 오신 걸 환영해요',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          '예산을 먼저 정하고, 그 안에서\n지출을 관리하는 가계부예요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.7, color: c.textSecondary),
        ),
        const SizedBox(height: 22),
        feature('🎯', '먼저 예산부터 정하고 지출을 관리해요'),
        feature('📊', '남은 예산을 한눈에 확인할 수 있어요'),
        feature('⚠️', '과소비하면 미리 알려줘요'),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onRestore,
          style: TextButton.styleFrom(foregroundColor: c.textSecondary),
          child: const Text(
            '백업 파일이 있나요? 백업에서 복원하기 ›',
            style: TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _ModeStep extends StatelessWidget {
  const _ModeStep({required this.mode, required this.onChanged});

  final BudgetMode mode;
  final ValueChanged<BudgetMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget card(BudgetMode m, String icon, String desc) {
      final selected = m == mode;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected ? c.accentBg : null,
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? c.accent : c.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 19)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          '예산을 어떻게 정할까요?',
          '두 가지 방식 중 편한 걸 선택하세요. 나중에 언제든 바꿀 수 있어요.',
        ),
        card(BudgetMode.total, '💵', '한 달에 쓸 총액만 정해요.'),
        card(BudgetMode.category, '🗂️', '카테고리마다 각각 예산을 정해요.'),
      ],
    );
  }
}

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({
    required this.categories,
    required this.errorOf,
    required this.onChanged,
    required this.onRemove,
    required this.onAdd,
  });

  final List<_EditableCategory> categories;
  final String? Function(_EditableCategory) errorOf;
  final VoidCallback onChanged;
  final ValueChanged<_EditableCategory> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          '카테고리를 확인해주세요',
          '기본으로 준비했어요. 필요 없으면 지우고, 더 필요하면 추가하세요.\n'
              '수입 카테고리(월급·용돈 등)는 나중에 설정에서 바꿀 수 있어요.',
        ),
        for (final cat in categories)
          _CategoryRow(
            key: ObjectKey(cat),
            category: cat,
            error: errorOf(cat),
            canRemove: categories.length > 1,
            onChanged: onChanged,
            onRemove: () => onRemove(cat),
          ),
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('카테고리 추가'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: c.borderStrong),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.category,
    required this.error,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _EditableCategory category;
  final String? error;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border.all(color: error != null ? c.danger : c.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color(category.draft.color).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category.draft.icon,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Focus(
                    onFocusChange: (focused) {
                      if (!focused && error != null) {
                        category.revertName();
                        onChanged();
                      }
                    },
                    child: TextField(
                      controller: category.nameController,
                      maxLength: categoryNameMaxLength,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        isDense: true,
                      ),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: canRemove ? '삭제' : '카테고리는 최소 1개 필요해요',
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: canRemove ? c.textMuted : c.border,
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
              child: Text(
                error!,
                style: TextStyle(fontSize: 11.5, color: c.danger),
              ),
            ),
        ],
      ),
    );
  }
}

class _AmountStep extends StatelessWidget {
  const _AmountStep({
    required this.mode,
    required this.categories,
    required this.totalController,
    required this.categorySum,
    required this.onChanged,
  });

  final BudgetMode mode;
  final List<_EditableCategory> categories;
  final TextEditingController totalController;
  final int categorySum;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (mode == BudgetMode.total) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle(
            '총 예산을 정해주세요',
            '한 달 동안 쓸 수 있는 전체 금액이에요. (나중에 설정해도 괜찮아요)',
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '한 달 총 예산',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    SizedBox(
                      width: 190,
                      child: AmountField(
                        controller: totalController,
                        onChanged: (_) => onChanged(),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '원',
                      style: TextStyle(fontSize: 18, color: c.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          '카테고리별 예산을 정해주세요',
          '각 카테고리마다 한 달 한도를 입력하세요. (나중에 설정해도 괜찮아요)',
        ),
        for (final cat in categories)
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    cat.draft.icon,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cat.draft.name,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface1,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AmountField(
                    controller: cat.amountController,
                    onChanged: (_) => onChanged(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                Text('원', style: TextStyle(fontSize: 11.5, color: c.textMuted)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 9, 4, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '총 예산',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
              Text(
                formatWon(categorySum),
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.mode,
    required this.total,
    required this.categories,
  });

  final BudgetMode mode;
  final int total;
  final List<_EditableCategory> categories;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muted = TextStyle(fontSize: 12, color: c.textMuted);
    const bold = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    Widget row(String left, String right, {TextStyle? leftStyle}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: leftStyle ?? muted),
          Text(right, style: bold),
        ],
      ),
    );

    return Column(
      children: [
        const SizedBox(height: 14),
        const Text('🎉', style: TextStyle(fontSize: 50)),
        const SizedBox(height: 10),
        const Text(
          '준비 완료!',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '아래 내용을 확인하고 시작해보세요',
          style: TextStyle(fontSize: 12.5, color: c.textSecondary),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row('예산 방식', mode.label),
              row('총 예산', formatWon(total)),
              Divider(color: c.border, height: 18),
              if (mode == BudgetMode.category) ...[
                Text('카테고리별 예산 확인', style: muted),
                for (final cat in categories)
                  row(
                    '${cat.draft.icon} ${cat.draft.name}',
                    formatWon(parseAmount(cat.amountController.text)),
                    leftStyle: const TextStyle(fontSize: 12),
                  ),
              ] else
                row(
                  '등록된 카테고리',
                  '${categories.length}개',
                  leftStyle: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
