// Derived money manager. Every number here is rebuilt from entries; nothing is stored.

import '../logbook/logbook_models.dart';
import 'finance_models.dart';

// Income minus expense for one set of entries.
int moneyNet(Iterable<LogbookEntry> entries) {
  var net = 0;
  for (final entry in entries) {
    net += entry.isExpense ? -entry.amount : entry.amount;
  }
  return net;
}

// Balance across every day: the sum of each day's net.
int moneyBalance(Iterable<LogbookDay> days) {
  var total = 0;
  for (final day in days) {
    total += moneyNet(day.entries);
  }
  return total;
}

// Money already set aside in pockets and goals, optionally skipping one row.
int moneyAllocated({
  Iterable<ChildPocket> pockets = const [],
  Iterable<ChildGoal> goals = const [],
  int? excludePocketId,
  int? excludeGoalId,
}) {
  var allocated = 0;
  for (final pocket in pockets) {
    if (pocket.pocketId == excludePocketId) continue;
    allocated += pocket.allocatedBalance;
  }
  for (final goal in goals) {
    if (goal.goalId == excludeGoalId) continue;
    allocated += goal.allocatedBalance;
  }
  return allocated;
}

// Cash left once every pocket and goal has claimed its share.
int moneyAvailable({
  required int balance,
  Iterable<ChildPocket> pockets = const [],
  Iterable<ChildGoal> goals = const [],
  int? excludePocketId,
  int? excludeGoalId,
}) {
  final left =
      balance -
      moneyAllocated(
        pockets: pockets,
        goals: goals,
        excludePocketId: excludePocketId,
        excludeGoalId: excludeGoalId,
      );
  return left < 0 ? 0 : left;
}

// Level cap used by the profile header.
int moneyLevelCap(int level) => level <= 0 ? 0 : level * 10;

// Money kept after a period, never below zero.
int moneySavings(int income, int expense) {
  final left = income - expense;
  return left < 0 ? 0 : left;
}

// One slice of the expense chart.
class MoneyCategorySlice {
  const MoneyCategorySlice({
    required this.category,
    required this.amount,
    required this.percent,
  });

  final LogbookCategory category;
  final int amount;

  /// 0-100, share of the total expense.
  final double percent;
}

// Expenses grouped by category, largest first. Income is ignored.
List<MoneyCategorySlice> moneyExpenseByCategory(
  Iterable<LogbookEntry> entries,
) {
  final amounts = <LogbookCategory, int>{};
  var total = 0;

  for (final entry in entries) {
    if (!entry.isExpense || entry.amount <= 0) continue;
    amounts[entry.category] = (amounts[entry.category] ?? 0) + entry.amount;
    total += entry.amount;
  }

  final slices = <MoneyCategorySlice>[
    for (final item in amounts.entries)
      MoneyCategorySlice(
        category: item.key,
        amount: item.value,
        percent: total == 0 ? 0 : item.value * 100 / total,
      ),
  ];
  slices.sort((a, b) => b.amount.compareTo(a.amount));
  return slices;
}
