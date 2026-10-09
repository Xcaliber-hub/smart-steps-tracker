// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/day_record.dart';
import '../utils/formatters.dart';

/// Bar chart of daily step counts with a dashed line marking the goal.
///
/// Bars reaching [goal] use the primary color; the rest are dimmed.
/// Tapping a bar shows a tooltip with the formatted step count.
/// Shows "No data yet" when [days] is empty.
class StepsBarChart extends StatelessWidget {
  /// Creates a bar chart for [days] against [goal].
  const StepsBarChart({super.key, required this.days, required this.goal});

  /// Day records in chronological order, one bar per entry.
  final List<DayRecord> days;

  /// Daily step goal drawn as a horizontal line.
  final int goal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (days.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No data yet')),
      );
    }

    final maxSteps = days.fold<int>(
      0,
      (max, day) => max > day.steps ? max : day.steps,
    );
    final maxY = max(maxSteps, goal) * 1.15;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: days[i].steps.toDouble(),
                    color: days[i].steps >= goal
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.35),
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = days[group.x.toInt()];
                return BarTooltipItem(
                  '${Formatters.shortDate(day.date)}\n'
                  '${Formatters.steps(day.steps)} steps',
                  TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: goal.toDouble(),
                color: colorScheme.tertiary,
                strokeWidth: 1.5,
                dashArray: const [6, 4],
              ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  final weekday =
                      DateFormat.E().format(days[index].date)[0];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      weekday,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
