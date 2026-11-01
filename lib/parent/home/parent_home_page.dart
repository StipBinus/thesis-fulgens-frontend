import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../kids/logbook/logbook_models.dart';
import '../../kids/logbook/logbook_provider.dart';

// Parent home
class ParentHomePage extends ConsumerWidget {
  const ParentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logbook = ref.watch(logbookProvider);
    final recent = _recent(logbook);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Parent overview',
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/select'),
                  child: const Text('Switch profile'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Watch how the week is going. This view is read-only.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF8A8378),
              ),
            ),
            const SizedBox(height: 20),
            _SummaryCard(logbook: logbook),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/child-register'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Add child account',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent entries',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              const _EmptyRow()
            else
              ...recent.map((entry) => _EntryRow(entry: entry)),
          ],
        ),
      ),
    );
  }

  // Recent six entries
  List<LogbookEntry> _recent(LogbookState state) {
    final keys = state.days.keys.toList()..sort((a, b) => b.compareTo(a));
    final out = <LogbookEntry>[];
    for (final key in keys) {
      final entries = state.dayFor(key).entries;
      for (final entry in entries.reversed) {
        out.add(entry);
        if (out.length == 6) return out;
      }
    }
    return out;
  }
}

// Summary card
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.logbook});

  final LogbookState logbook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1A1A1A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Child balance',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8A8378),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _rupiah(logbook.pockets.total),
            style: const TextStyle(
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '${logbook.streak}',
                  label: logbook.streak == 1 ? 'day streak' : 'day streak',
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '${logbook.todayEntryCount}',
                  label: 'today',
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '${logbook.berries}',
                  label: 'berries',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// One stat
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A8378)),
        ),
      ],
    );
  }
}

// Entry row
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final LogbookEntry entry;

  @override
  Widget build(BuildContext context) {
    final expense = entry.isExpense;
    final color = expense ? const Color(0xFFB3402F) : const Color(0xFF1F7A45);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title.isEmpty ? entry.category.label : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.pocket.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8378),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${expense ? '\u2212' : '+'}${_rupiah(entry.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Empty state
class _EmptyRow extends StatelessWidget {
  const _EmptyRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Nothing logged yet.',
        style: TextStyle(fontSize: 13.5, color: Color(0xFF8A8378)),
      ),
    );
  }
}

// Rupiah format
String _rupiah(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return 'Rp ${value < 0 ? '-' : ''}$buffer';
}
