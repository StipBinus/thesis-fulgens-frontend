import 'package:flutter/material.dart';

import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';

// One activity line, bucketed by the day it happened
class PocketHistoryEntry {
  const PocketHistoryEntry({
    required this.day,
    required this.time,
    required this.label,
    required this.amount,
    required this.incoming,
  });

  final String day;
  final String time;
  final String label;
  final int amount;
  final bool incoming;
}

// Placeholder activity, newest first
const List<PocketHistoryEntry> pocketDemoHistory = <PocketHistoryEntry>[
  PocketHistoryEntry(
    day: 'Today',
    time: '9:41 AM',
    label: 'Added money',
    amount: 25000,
    incoming: true,
  ),
  PocketHistoryEntry(
    day: 'Today',
    time: '8:12 AM',
    label: 'Spent',
    amount: 8000,
    incoming: false,
  ),
  PocketHistoryEntry(
    day: 'Yesterday',
    time: '6:20 PM',
    label: 'Added money',
    amount: 15000,
    incoming: true,
  ),
  PocketHistoryEntry(
    day: 'Yesterday',
    time: '1:05 PM',
    label: 'Spent',
    amount: 4000,
    incoming: false,
  ),
  PocketHistoryEntry(
    day: 'Monday',
    time: '7:10 PM',
    label: 'Added money',
    amount: 20000,
    incoming: true,
  ),
  PocketHistoryEntry(
    day: 'Monday',
    time: '8:45 AM',
    label: 'Spent',
    amount: 6500,
    incoming: false,
  ),
  PocketHistoryEntry(
    day: 'Sunday',
    time: '6:30 PM',
    label: 'Added money',
    amount: 12000,
    incoming: true,
  ),
  PocketHistoryEntry(
    day: 'Sunday',
    time: '12:20 PM',
    label: 'Spent',
    amount: 3000,
    incoming: false,
  ),
  PocketHistoryEntry(
    day: 'Saturday',
    time: '4:05 PM',
    label: 'Spent',
    amount: 2500,
    incoming: false,
  ),
  PocketHistoryEntry(
    day: 'Saturday',
    time: '9:15 AM',
    label: 'Added money',
    amount: 9000,
    incoming: true,
  ),
  PocketHistoryEntry(
    day: 'Friday',
    time: '7:40 PM',
    label: 'Added money',
    amount: 18000,
    incoming: true,
  ),
  PocketHistoryEntry(
    day: 'Friday',
    time: '8:05 AM',
    label: 'Spent',
    amount: 5000,
    incoming: false,
  ),
];

// Day-grouped activity, collapsed until the user asks for more
class PocketDaysHistory extends StatefulWidget {
  const PocketDaysHistory({
    super.key,
    required this.entries,
    this.collapsedRows = 6,
  });

  final List<PocketHistoryEntry> entries;
  final int collapsedRows;

  @override
  State<PocketDaysHistory> createState() => _PocketDaysHistoryState();
}

class _PocketDaysHistoryState extends State<PocketDaysHistory> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final List<_DayBucket> all = _bucket(widget.entries);
    final List<_DayBucket> shown =
        _expanded ? all : _limit(all, widget.collapsedRows);
    final int hidden = widget.entries.length - _count(shown);
    final bool collapsible = widget.entries.length > widget.collapsedRows;

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          _blocks(shown),
          if (collapsible) _toggle(hidden),
        ],
      ),
    );
  }

  // Each day framed in its own hairline block
  Widget _blocks(List<_DayBucket> buckets) {
    return Column(
      children: [
        for (var i = 0; i < buckets.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 4),
            decoration: BoxDecoration(
              border: Border.all(color: logbookLine),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _header(buckets[i], indent: 2),
                const SizedBox(height: 6),
                ..._rows(buckets[i]),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _header(_DayBucket bucket, {double indent = 0}) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(
        children: [
          Text(
            bucket.day.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: logbookInk,
            ),
          ),
          const Spacer(),
          Text(
            '${bucket.net >= 0 ? '+' : '−'}${financeRupiah(bucket.net.abs())}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: bucket.net >= 0 ? logbookGreen : logbookMuted,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(_DayBucket bucket) {
    final List<Widget> out = <Widget>[];
    for (var j = 0; j < bucket.entries.length; j++) {
      out.add(
        _DayRow(
          entry: bucket.entries[j],
          first: j == 0,
          last: j == bucket.entries.length - 1,
        ),
      );
    }
    return out;
  }

  Widget _toggle(int hidden) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _expanded ? 'Show less' : 'Show $hidden more',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: logbookMuted,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: logbookMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBucket {
  _DayBucket(this.day);

  final String day;
  final List<PocketHistoryEntry> entries = <PocketHistoryEntry>[];

  int get net {
    var total = 0;
    for (final entry in entries) {
      total += entry.incoming ? entry.amount : -entry.amount;
    }
    return total;
  }
}

List<_DayBucket> _bucket(List<PocketHistoryEntry> entries) {
  final List<_DayBucket> buckets = <_DayBucket>[];
  for (final entry in entries) {
    if (buckets.isEmpty || buckets.last.day != entry.day) {
      buckets.add(_DayBucket(entry.day));
    }
    buckets.last.entries.add(entry);
  }
  return buckets;
}

List<_DayBucket> _limit(List<_DayBucket> buckets, int maxRows) {
  final List<_DayBucket> out = <_DayBucket>[];
  var rows = 0;
  for (final bucket in buckets) {
    if (rows >= maxRows) break;
    final int take = maxRows - rows;
    final _DayBucket head = _DayBucket(bucket.day);
    head.entries.addAll(bucket.entries.take(take));
    out.add(head);
    rows += head.entries.length;
  }
  return out;
}

int _count(List<_DayBucket> buckets) {
  var total = 0;
  for (final bucket in buckets) {
    total += bucket.entries.length;
  }
  return total;
}

// Dot on a shared vertical rail, the thread through every line
class _Rail extends StatelessWidget {
  const _Rail({
    required this.first,
    required this.last,
    this.dotColor,
  });

  final bool first;
  final bool last;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 1.5,
              color: first ? Colors.transparent : logbookTrack,
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor ?? Colors.transparent,
            ),
          ),
          Expanded(
            child: Container(
              width: 1.5,
              color: last ? Colors.transparent : logbookTrack,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.entry,
    required this.first,
    required this.last,
  });

  final PocketHistoryEntry entry;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(
            first: first,
            last: last,
            dotColor: entry.incoming ? logbookGreen : logbookRed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: logbookInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.time,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: logbookFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _signed(entry.amount, entry.incoming),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: entry.incoming ? logbookGreen : logbookInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _signed(int amount, bool incoming) {
  return '${incoming ? '+' : '−'}${financeRupiah(amount)}';
}
