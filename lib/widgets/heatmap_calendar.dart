// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/day_record.dart';
import '../utils/formatters.dart';

/// GitHub-style yearly activity heatmap grouped by month.
///
/// Each month renders a label plus a 7-column grid of day squares
/// (Sunday-first, padded with empty cells so weekdays line up). Square
/// color follows a 5-step scale from [ColorScheme.surfaceContainerHighest] (no
/// steps) to [ColorScheme.primary] (goal met). Tapping a day with data
/// calls [onDaySelected]. Empty [days] shows "No data yet".
class HeatmapCalendar extends StatelessWidget {
  /// Creates a heatmap for [days] against [goal].
  const HeatmapCalendar({
    super.key,
    required this.days,
    required this.goal,
    this.onDaySelected,
  });

  /// Day records; typically up to a year of data.
  final List<DayRecord> days;

  /// Daily step goal used for the color scale.
  final int goal;

  /// Called with the tapped day's record.
  final ValueChanged<DayRecord>? onDaySelected;

  static const _cellSize = 12.0;
  static const _cellSpacing = 3.0;

  Color _colorFor(int steps, ColorScheme colorScheme) {
    if (steps <= 0) return colorScheme.surfaceContainerHighest;
    final ratio = goal <= 0 ? 1.0 : (steps / goal).clamp(0.0, 1.0);
    final level = (ratio * 4).round();
    return Color.lerp(colorScheme.surfaceContainerHighest, colorScheme.primary,
        level / 4)!;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (days.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    final byKey = {for (final day in sorted) day.dateKey: day};

    // Group the covered months in chronological order.
    final months = <DateTime>[];
    var cursor = DateTime(sorted.first.date.year, sorted.first.date.month);
    final last = DateTime(sorted.last.date.year, sorted.last.date.month);
    while (!cursor.isAfter(last)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final month in months) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              DateFormat('MMMM yyyy').format(month),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: _cellSpacing,
            crossAxisSpacing: _cellSpacing,
            children: [
              // Pad so the 1st lands on the right weekday (Sunday-first).
              for (var i = 0;
                  i < DateTime(month.year, month.month).weekday % 7;
                  i++)
                const SizedBox(
                  width: _cellSize,
                  height: _cellSize,
                ),
              for (var day = 1;
                  day <= DateTime(month.year, month.month + 1, 0).day;
                  day++)
                _DayCell(
                  date: DateTime(month.year, month.month, day),
                  record: byKey[DayRecord.dateKeyFor(
                    DateTime(month.year, month.month, day),
                  )],
                  colorScheme: colorScheme,
                  colorFor: _colorFor,
                  onDaySelected: onDaySelected,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// One heatmap square for a calendar day.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.record,
    required this.colorScheme,
    required this.colorFor,
    required this.onDaySelected,
  });

  final DateTime date;
  final DayRecord? record;
  final ColorScheme colorScheme;
  final Color Function(int steps, ColorScheme colorScheme) colorFor;
  final ValueChanged<DayRecord>? onDaySelected;

  @override
  Widget build(BuildContext context) {
    final steps = record?.steps ?? 0;
    final tooltip =
        '${Formatters.shortDate(date)}: ${Formatters.steps(steps)} steps';
    final square = Container(
      width: HeatmapCalendar._cellSize,
      height: HeatmapCalendar._cellSize,
      decoration: BoxDecoration(
        color: colorFor(steps, colorScheme),
        borderRadius: BorderRadius.circular(3),
      ),
    );

    final cell = record != null && onDaySelected != null
        ? InkWell(
            borderRadius: BorderRadius.circular(3),
            onTap: () => onDaySelected!(record!),
            child: square,
          )
        : square;

    return Semantics(
      label: tooltip,
      button: record != null && onDaySelected != null,
      child: Tooltip(message: tooltip, child: cell),
    );
  }
}
