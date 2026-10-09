// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/day_record.dart';
import '../utils/formatters.dart';

/// Curved line chart of daily step counts with a dashed goal line.
///
/// Spots map the day index to the step count; the area under the curve
/// is filled with a primary gradient. Touching the chart shows a tooltip
/// with the formatted step count. Shows "No data yet" when [days] is
/// empty.
class StepsLineChart extends StatelessWidget {
  /// Creates a line chart for [days] against [goal].
  const StepsLineChart({super.key, required this.days, required this.goal});

  /// Day records in chronological order, one spot per entry.
  final List<DayRecord> days;

  /// Daily step goal drawn as a dashed horizontal line.
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
    // Keep bottom labels readable: aim for ~7 labels across the chart.
    final labelEvery = max(1, (days.length / 7).ceil());

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          // Avoid a zero-width axis when there is only one day.
          maxX: max(1, days.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < days.length; i++)
                  FlSpot(i.toDouble(), days[i].steps.toDouble()),
              ],
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.35),
                    colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${Formatters.shortDate(days[spot.x.toInt()].date)}\n'
                    '${Formatters.steps(spot.y.toInt())} steps',
                    TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
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
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 ||
                      index >= days.length ||
                      index % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      Formatters.shortDate(days[index].date),
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
