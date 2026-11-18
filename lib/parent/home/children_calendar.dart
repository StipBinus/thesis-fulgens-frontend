import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../kids/logbook/logbook_models.dart';
import '../ui/parent_ui.dart';
import 'home_page_provider.dart';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Month calendar with a dot on every logged day, plus the selected day's log.
///
/// Follows [selectedChildProvider], so tapping a different tab in the children
/// card swaps the calendar to that child with no extra wiring.
class ParentHomePageCalendar extends ConsumerStatefulWidget {
  const ParentHomePageCalendar({super.key});

  @override
  ConsumerState<ParentHomePageCalendar> createState() =>
      _ParentHomePageCalendarState();
}

class _ParentHomePageCalendarState
    extends ConsumerState<ParentHomePageCalendar> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    _selectedDay = now;
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider);
    if (child == null) return const SizedBox.shrink();

    final logs = ref.watch(
      childLogMonthProvider((
        childId: child.childId,
        year: _focusedDay.year,
        month: _focusedDay.month,
      )),
    );
    // `asData` is null while loading and after an error, so the dots and the
    // day panel simply have nothing to show.
    final days = logs.asData?.value ?? const <String, String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _calendarCard(days),
        if (logs.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Text(
              '${logs.error}',
              style: parentText(
                size: 12,
                weight: FontWeight.w500,
                color: ParentPalette.red,
              ),
            ),
          ),
        const SizedBox(height: 14),
        _dayPanel(days),
      ],
    );
  }

  Widget _calendarCard(Map<String, String> days) {
    return ParentCard(
      color: ParentPalette.raised,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: _focusedDay,
        currentDay: DateTime.now(),
        startingDayOfWeek: StartingDayOfWeek.sunday,
        // Only horizontal swipes change the month; vertical drags belong to
        // the page scroll.
        availableGestures: AvailableGestures.horizontalSwipe,
        rowHeight: 44,
        daysOfWeekHeight: 28,
        headerStyle: HeaderStyle(
          titleCentered: false,
          formatButtonVisible: false,
          headerPadding: const EdgeInsets.fromLTRB(6, 4, 4, 10),
          leftChevronIcon: const Icon(
            Icons.chevron_left_rounded,
            size: 20,
            color: ParentPalette.label,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: ParentPalette.label,
          ),
          titleTextStyle: parentText(size: 15, weight: FontWeight.w700),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: parentText(
            size: 11,
            weight: FontWeight.w500,
            color: ParentPalette.faint,
          ),
          weekendStyle: parentText(
            size: 11,
            weight: FontWeight.w500,
            color: ParentPalette.faint,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(4),
          defaultTextStyle: parentText(
            size: 12,
            weight: FontWeight.w500,
            color: ParentPalette.label,
          ),
          weekendTextStyle: parentText(
            size: 12,
            weight: FontWeight.w500,
            color: ParentPalette.label,
          ),
          todayDecoration: BoxDecoration(
            color: ParentPalette.accent.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          todayTextStyle: parentText(
            size: 12,
            weight: FontWeight.w600,
            color: ParentPalette.accentDeep,
          ),
          selectedDecoration: const BoxDecoration(
            color: ParentPalette.accent,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: parentText(
            size: 12,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        // Rebuilds so the dots for the newly visible month get fetched.
        // Assigning exactly the day the calendar reports means it stays put.
        onPageChanged: (focusedDay) =>
            setState(() => _focusedDay = focusedDay),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            if (!days.containsKey(logbookDateKey(day))) return null;

            return Positioned(
              bottom: 1,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      isSameDay(day, _selectedDay)
                          ? Colors.white
                          : ParentPalette.accent,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dayPanel(Map<String, String> days) {
    final summary = days[logbookDateKey(_selectedDay)] ?? '';
    final empty = summary.isEmpty;

    return ParentCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_ordinal(_selectedDay.day)} '
            '${_monthNames[_selectedDay.month - 1]}',
            style: parentText(
              size: 14,
              weight: FontWeight.w700,
              color: ParentPalette.accent,
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: ParentPalette.line),
          const SizedBox(height: 12),
          Text(
            empty ? 'Nothing logged for this day.' : summary,
            style: parentText(
              size: 13,
              weight: FontWeight.w500,
              height: 1.5,
              color:
                  empty ? ParentPalette.faint : const Color(0xFF3A2E20),
            ),
          ),
        ],
      ),
    );
  }
}

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';

  switch (day % 10) {
    case 1:
      return '${day}st';
    case 2:
      return '${day}nd';
    case 3:
      return '${day}rd';
    default:
      return '${day}th';
  }
}
