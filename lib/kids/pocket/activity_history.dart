import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../finance/finance_models.dart';
import '../finance/finance_repository.dart';
import '../logbook/logbook_tokens.dart';
import 'history_timeline.dart';
import 'pocket_history.dart';

const List<String> _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// Day label: Today, Yesterday, weekday this week, else "3 Nov"
String activityDay(DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return _weekdays[at.weekday - 1];
  return '${at.day} ${_months[at.month - 1]}';
}

// Clock label: 9:41 AM
String activityTime(DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}';
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'No activity yet',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: logbookFaint,
        ),
      ),
    );
  }
}

// Compact timeline of the latest real moves
class ActivityTimeline extends ConsumerWidget {
  const ActivityTimeline({super.key, required this.targetId, this.limit = 2});

  final String targetId;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(moneyActivityProvider(targetId)).value ??
        const <MoneyActivity>[];
    if (items.isEmpty) return const _EmptyActivity();
    return HistoryTimeline(
      entries: [
        for (final item in items.take(limit))
          HistoryEntry(
            item.label,
            item.amount,
            activityDay(item.createdAt),
            item.incoming,
          ),
      ],
    );
  }
}

// Full day-grouped history
class ActivityDaysHistory extends ConsumerWidget {
  const ActivityDaysHistory({super.key, required this.targetId});

  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(moneyActivityProvider(targetId)).value ??
        const <MoneyActivity>[];
    if (items.isEmpty) return const _EmptyActivity();
    return PocketDaysHistory(
      entries: [
        for (final item in items)
          PocketHistoryEntry(
            day: activityDay(item.createdAt),
            time: activityTime(item.createdAt),
            label: item.label,
            amount: item.amount,
            incoming: item.incoming,
          ),
      ],
    );
  }
}
