import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_fulgens_mobile/kids/finance/finance_models.dart';
import 'package:thesis_fulgens_mobile/kids/finance/money_manager.dart';
import 'package:thesis_fulgens_mobile/kids/logbook/logbook_models.dart';

LogbookEntry entry(
  LogbookEntryType type,
  int amount, {
  LogbookCategory category = LogbookCategory.other,
}) {
  return LogbookEntry(
    id: 'e-$type-$amount',
    type: type,
    amount: amount,
    category: category,
  );
}

ChildPocket pocket(int id, int allocated) {
  return ChildPocket(
    pocketId: id,
    childId: 'child',
    pocketName: 'pocket-$id',
    userBalance: 0,
    allocatedBalance: allocated,
  );
}

ChildGoal goal(int id, int allocated) {
  return ChildGoal(
    goalId: id,
    childId: 'child',
    goalsName: 'goal-$id',
    userBalance: 0,
    allocatedBalance: allocated,
    goalPrice: 100000,
  );
}

void main() {
  group('moneyNet', () {
    test('is zero for no entries', () {
      expect(moneyNet(const []), 0);
    });

    test('adds income and subtracts expense', () {
      expect(
        moneyNet([
          entry(LogbookEntryType.income, 50000),
          entry(LogbookEntryType.expense, 20000),
        ]),
        30000,
      );
    });

    test('goes negative when expenses win', () {
      expect(moneyNet([entry(LogbookEntryType.expense, 75000)]), -75000);
    });
  });

  group('moneyBalance', () {
    test('sums the net of every day', () {
      final days = [
        LogbookDay(
          entries: [
            entry(LogbookEntryType.income, 100000),
            entry(LogbookEntryType.expense, 40000),
          ],
        ),
        LogbookDay(entries: [entry(LogbookEntryType.expense, 25000)]),
        LogbookDay(),
      ];
      expect(moneyBalance(days), 35000);
    });

    test('is zero for an empty logbook', () {
      expect(moneyBalance(const []), 0);
    });
  });

  group('moneyAllocated', () {
    test('adds pockets and goals', () {
      expect(
        moneyAllocated(
          pockets: [pocket(1, 20000), pocket(2, 30000)],
          goals: [goal(1, 50000)],
        ),
        100000,
      );
    });

    test('skips the excluded pocket', () {
      expect(
        moneyAllocated(
          pockets: [pocket(1, 20000), pocket(2, 30000)],
          excludePocketId: 1,
        ),
        30000,
      );
    });

    test('skips the excluded goal', () {
      expect(
        moneyAllocated(
          goals: [goal(1, 50000), goal(2, 10000)],
          excludeGoalId: 2,
        ),
        50000,
      );
    });
  });

  group('moneyAvailable', () {
    test('subtracts every allocation from the balance', () {
      expect(
        moneyAvailable(
          balance: 150000,
          pockets: [pocket(1, 40000)],
          goals: [goal(1, 10000)],
        ),
        100000,
      );
    });

    test('never goes below zero', () {
      expect(moneyAvailable(balance: 10000, pockets: [pocket(1, 40000)]), 0);
    });

    test('ignores the row being edited', () {
      expect(
        moneyAvailable(
          balance: 100000,
          pockets: [pocket(1, 40000), pocket(2, 30000)],
          excludePocketId: 1,
        ),
        70000,
      );
    });
  });

  test('moneyLevelCap multiplies the level by ten', () {
    expect(moneyLevelCap(3), 30);
    expect(moneyLevelCap(0), 0);
  });

  test('moneySavings clamps at zero', () {
    expect(moneySavings(100000, 30000), 70000);
    expect(moneySavings(10000, 50000), 0);
  });

  group('moneyExpenseByCategory', () {
    test('groups expenses and ignores income', () {
      final slices = moneyExpenseByCategory([
        entry(
          LogbookEntryType.expense,
          30000,
          category: LogbookCategory.foodAndBeverage,
        ),
        entry(
          LogbookEntryType.expense,
          10000,
          category: LogbookCategory.foodAndBeverage,
        ),
        entry(
          LogbookEntryType.expense,
          20000,
          category: LogbookCategory.transport,
        ),
        entry(
          LogbookEntryType.income,
          500000,
          category: LogbookCategory.allowance,
        ),
      ]);

      expect(slices.length, 2);
      expect(slices.first.category, LogbookCategory.foodAndBeverage);
      expect(slices.first.amount, 40000);
      expect(slices.first.percent, closeTo(66.67, 0.01));
      expect(slices.last.category, LogbookCategory.transport);
      expect(slices.last.percent, closeTo(33.33, 0.01));
    });

    test('is empty when nothing was spent', () {
      expect(
        moneyExpenseByCategory([entry(LogbookEntryType.income, 10000)]),
        isEmpty,
      );
    });
  });
}
