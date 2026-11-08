import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../../domain/budget.dart';
import '../theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthKey = ref.watch(currentMonthKeyProvider);
    final entries = ref.watch(monthEntriesProvider(monthKey));
    final budget = ref.watch(monthBudgetProvider(monthKey));
    final threshold = ref.watch(
      settingsProvider.select((s) => s.budgetThreshold),
    );
    final month = monthStartOf(monthKey).month;

    return Scaffold(
      appBar: AppBar(title: const Text('가계부')),
      body: switch ((entries, budget)) {
        (AsyncData(value: final list), AsyncData(value: final b)) => Column(
          children: [
            _Summary(
              month: month,
              spent: list
                  .where((e) => e.kind == EntryKind.expense)
                  .fold(0, (s, e) => s + e.amount),
              budget: b.totalBudget,
              threshold: threshold,
            ),
            Expanded(child: _EntryList(entries: list)),
          ],
        ),
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
          Center(child: Text('데이터를 읽지 못했어요\n$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// 이번 달 지출 / 남은 예산 + 진행바.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.month,
    required this.spent,
    required this.budget,
    required this.threshold,
  });

  final int month;
  final int spent;
  final int budget;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final over = isOverBudget(spent, budget, threshold);
    final exceeded = budget > 0 && spent > budget;
    final ratio = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final labelStyle = TextStyle(fontSize: 11.5, color: c.textMuted);
    const valueStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

    return Container(
      color: c.surface2,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$month월 지출', style: labelStyle),
                    const SizedBox(height: 4),
                    Text(formatWon(spent), style: valueStyle),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('남은 예산', style: labelStyle),
                    const SizedBox(height: 4),
                    Text(
                      exceeded
                          ? '${formatWon(spent - budget)} 초과'
                          : formatWon(budget - spent),
                      style: valueStyle.copyWith(
                        color: exceeded ? c.danger : c.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: c.surface0,
              color: over ? c.danger : c.accent,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '사용 ${budget > 0 ? (spent * 100 ~/ budget) : 0}%',
                style: labelStyle,
              ),
              Text('총 ${formatWon(budget)}', style: labelStyle),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (entries.isEmpty) {
      return Center(
        child: Text(
          '아직 이번 달 내역이 없어요 🙂\n입력 화면은 다음 단계에서 옮겨올 예정이에요',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textMuted, height: 1.9),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final income = e.kind == EntryKind.income;
        return ListTile(
          title: Text(e.description.isEmpty ? '(내역 없음)' : e.description),
          subtitle: Text('${e.date} ${e.time}'),
          trailing: Text(
            '${income ? '+' : ''}${formatWon(e.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: income ? c.income : c.textPrimary,
            ),
          ),
        );
      },
    );
  }
}
