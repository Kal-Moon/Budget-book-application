import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/budget.dart';
import '../../domain/summary.dart';
import '../home/date_picker_sheet.dart';
import '../home/home_view.dart';
import '../home/home_widgets.dart';
import '../navigation.dart';
import '../theme.dart';
import 'input_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    setState(() => _searching = false);
  }

  void _openEntry(Entry entry) => openEntryEditor(context, entry);

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(homeViewProvider);
    final entries = ref.watch(monthEntriesProvider(view.monthKey));
    final budget = ref.watch(monthBudgetProvider(view.monthKey));
    final categories = ref.watch(categoryMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('가계부'),
        actions: [
          IconButton(
            tooltip: '검색',
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = true),
          ),
          _DatePill(view: view),
          const SizedBox(width: 12),
        ],
      ),
      body: switch ((entries, budget, categories)) {
        (
          AsyncData(value: final list),
          AsyncData(value: final b),
          AsyncData(value: final cats),
        ) =>
          _searching
              ? _SearchBody(
                  controller: _searchController,
                  categories: cats,
                  onClose: _closeSearch,
                  onOpenEntry: _openEntry,
                )
              : _MonthBody(
                  view: view,
                  entries: list,
                  budget: b,
                  categories: cats,
                  onOpenEntry: _openEntry,
                ),
        (AsyncError(:final error), _, _) ||
        (_, AsyncError(:final error), _) ||
        (
          _,
          _,
          AsyncError(:final error),
        ) => Center(child: Text('데이터를 읽지 못했어요\n$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// 상단의 날짜 버튼. 하루만 보고 있으면 강조된다.
class _DatePill extends StatelessWidget {
  const _DatePill({required this.view});

  final HomeView view;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filtered = view.selectedDate != null;
    final month = monthStartOf(view.monthKey);
    final label = filtered
        ? dayLabel(view.selectedDate!)
        : '${month.year}년 ${month.month}월';
    return Material(
      color: filtered ? c.accentBg : c.surface0,
      shape: StadiumBorder(
        side: BorderSide(color: filtered ? c.accent : c.borderStrong),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => showHomeDatePicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: filtered ? c.accent : c.textPrimary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: filtered ? c.accent : c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 보고 있는 달(또는 하루)의 요약·필터·내역 목록.
class _MonthBody extends ConsumerWidget {
  const _MonthBody({
    required this.view,
    required this.entries,
    required this.budget,
    required this.categories,
    required this.onOpenEntry,
  });

  final HomeView view;
  final List<Entry> entries;
  final MonthBudget budget;
  final Map<int, Category> categories;
  final ValueChanged<Entry> onOpenEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final today = ref.watch(todayProvider);
    final notifier = ref.read(homeViewProvider.notifier);
    final month = monthStartOf(view.monthKey).month;
    final isCurrentMonth = view.monthKey == monthKeyOf(today);

    final monthTotals = EntryTotals(entries);
    final dayEntries = view.selectedDate == null
        ? entries
        : entries.where((e) => e.date == view.selectedDate).toList();
    final shown = [
      for (final e in dayEntries)
        if (switch (view.type) {
              HomeTypeFilter.all => true,
              HomeTypeFilter.expense => e.kind == EntryKind.expense,
              HomeTypeFilter.income => e.kind == EntryKind.income,
            } &&
            (view.categoryId == null || e.categoryId == view.categoryId))
          e,
    ];
    final groups = groupByDate(shown);

    final expenseCats = _ofKind(EntryKind.expense);
    final filterCats = _ofKind(view.categoryKind);

    bool overFor(Entry e) =>
        e.kind == EntryKind.expense &&
        budget.mode == BudgetMode.category &&
        isOverBudget(
          monthTotals.spentIn(e.categoryId),
          budget.categoryBudget(e.categoryId),
          settings.budgetThreshold,
        );

    String headerLabel(String date) {
      final label = dayLabel(date);
      if (date == dateKeyOf(today)) return '오늘 · $label';
      if (date == dateKeyOf(today.subtract(const Duration(days: 1)))) {
        return '어제 · $label';
      }
      return label;
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isCurrentMonth && budget.totalBudget == 0)
                const SetupBanner(),
              SummaryCard(
                spentLabel: view.selectedDate == null
                    ? '$month월 지출'
                    : '선택한 날 지출',
                spentShown: view.selectedDate == null
                    ? monthTotals.expense
                    : EntryTotals(dayEntries).expense,
                monthSpent: monthTotals.expense,
                budget: budget.totalBudget,
                threshold: settings.budgetThreshold,
              ),
              if (settings.showHomeIncome)
                IncomeStrip(month: month, totals: monthTotals),
              if (view.selectedDate case final date?)
                DayFilterBanner(
                  text: '${dayLabel(date)}만 보는 중',
                  actionLabel: '$month월 전체 보기',
                  onAction: notifier.clearDay,
                ),
              SpendingBreakdown(
                categories: expenseCats,
                totals: monthTotals,
                budget: budget,
                threshold: settings.budgetThreshold,
                onTap: () =>
                    ref.read(appTabProvider.notifier).select(AppTab.analysis),
              ),
              Container(
                color: c.surface2,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(
                  children: [
                    ChoiceChipRow<HomeTypeFilter>(
                      items: HomeTypeFilter.values,
                      selected: view.type,
                      expand: true,
                      labelOf: (t) => switch (t) {
                        HomeTypeFilter.all => '전체',
                        HomeTypeFilter.expense => '지출',
                        HomeTypeFilter.income => '수입',
                      },
                      onSelected: notifier.setType,
                    ),
                    const SizedBox(height: 8),
                    ChoiceChipRow<int?>(
                      items: [null, ...filterCats.map((c) => c.id)],
                      selected: view.categoryId,
                      labelOf: (id) => id == null
                          ? '전체'
                          : '${categories[id]!.icon} ${categories[id]!.name}',
                      onSelected: notifier.setCategory,
                    ),
                  ],
                ),
              ),
              Divider(height: 0.5, thickness: 0.5, color: c.border),
            ],
          ),
        ),
        if (groups.isEmpty)
          SliverToBoxAdapter(
            child: EmptyMessage(
              view.selectedDate != null
                  ? '이 날의 내역이 없어요 🙂'
                  : entries.isEmpty
                  ? '아직 $month월 내역이 없어요 🙂'
                  : '조건에 맞는 내역이 없어요 🙂',
              hint: '하단 입력 탭에서 추가해보세요',
            ),
          )
        else
          SliverList.list(
            children: [
              for (final g in groups) ...[
                DayHeader(label: headerLabel(g.date), net: g.net),
                for (final e in g.entries)
                  EntryTile(
                    entry: e,
                    category: categories[e.categoryId],
                    overBudget: overFor(e),
                    onTap: () => onOpenEntry(e),
                  ),
              ],
              const SizedBox(height: 24),
            ],
          ),
      ],
    );
  }

  List<Category> _ofKind(EntryKind kind) {
    final list = categories.values.where((c) => c.kind == kind).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }
}

/// 전체 기간 검색.
class _SearchBody extends ConsumerStatefulWidget {
  const _SearchBody({
    required this.controller,
    required this.categories,
    required this.onClose,
    required this.onOpenEntry,
  });

  final TextEditingController controller;
  final Map<int, Category> categories;
  final VoidCallback onClose;
  final ValueChanged<Entry> onOpenEntry;

  @override
  ConsumerState<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends ConsumerState<_SearchBody> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = ref.watch(allEntriesProvider).value ?? const [];
    final query = widget.controller.text;
    final results = searchEntries(all, widget.categories, query);
    final groups = groupByDate(results);

    return Column(
      children: [
        Container(
          color: c.surface2,
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '구매처·내역·메모·카테고리로 검색 (전체 기간)',
                    hintStyle: TextStyle(fontSize: 13, color: c.textMuted),
                    isDense: true,
                    filled: true,
                    fillColor: c.surface0,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: c.borderStrong),
                    ),
                  ),
                ),
              ),
              TextButton(onPressed: widget.onClose, child: const Text('취소')),
            ],
          ),
        ),
        Expanded(
          child: query.trim().isEmpty
              ? const EmptyMessage('찾고 싶은 내역을 입력해보세요 🔍')
              : groups.isEmpty
              ? EmptyMessage('"${query.trim()}"에 대한 검색 결과가 없어요 🙂')
              : ListView(
                  children: [
                    for (final g in groups) ...[
                      DayHeader(
                        label: '${g.date.substring(0, 4)}년 ${dayLabel(g.date)}',
                      ),
                      for (final e in g.entries)
                        EntryTile(
                          entry: e,
                          category: widget.categories[e.categoryId],
                          onTap: () => widget.onOpenEntry(e),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ],
    );
  }
}
