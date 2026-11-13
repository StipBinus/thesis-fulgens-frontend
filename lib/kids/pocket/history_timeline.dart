import 'package:flutter/material.dart';

import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';

// One activity line in a history timeline
class HistoryEntry {
  const HistoryEntry(this.label, this.amount, this.time, this.incoming);

  final String label;
  final int amount;
  final String time;
  final bool incoming;
}

// Compact vertical timeline: today's rows, shadow trail fading into earlier days
class HistoryTimeline extends StatelessWidget {
  const HistoryTimeline({super.key, required this.entries});

  final List<HistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 14,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors:
                                  i == 0
                                      ? [
                                        logbookTrack.withValues(alpha: 0),
                                        logbookTrack,
                                      ]
                                      : [logbookTrack, logbookTrack],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              entries[i].incoming ? _income : logbookRed,
                        ),
                      ),
                      Expanded(
                        child:
                            i == entries.length - 1
                                ? const SizedBox()
                                : Container(width: 1.5, color: logbookTrack),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _row(entries[i])),
              ],
            ),
          ),
      ],
    );
  }

  // One tight line per day: label, time, amount
  Widget _row(HistoryEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: entry.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: logbookInk,
                ),
                children: [
                  TextSpan(
                    text: '  ·  ${entry.time}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: logbookFaint,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${entry.incoming ? '+' : '-'}${financeRupiah(entry.amount)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: entry.incoming ? _income : logbookRed,
            ),
          ),
        ],
      ),
    );
  }
}

const Color _income = Color(0xFF2E8B57);
