// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/day_record.dart';
import '../utils/formatters.dart';
import '../viewmodels/providers.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';

/// History tab: calendar with per-day activity and a detail card.
class HistoryScreen extends ConsumerStatefulWidget {
  /// Creates the history tab.
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final allDays = ref.watch(allDaysProvider);
    final profile = ref.watch(profileProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return allDays.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load history: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (days) {
        final events = <String, DayRecord>{
          for (final d in days) d.dateKey: d,
        };
        final selectedRecord =
            events[DayRecord.dateKeyFor(_selected)];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Semantics(
                    label: 'Activity calendar',
                    child: TableCalendar<DayRecord>(
                      firstDay: DateTime(2020),
                      lastDay: DateTime.now(),
                      focusedDay: _focused,
                      selectedDayPredicate: (day) => isSameDay(day, _selected),
                      onDaySelected: (selected, focused) => setState(() {
                        _selected = selected;
                        _focused = focused;
                      }),
                      onPageChanged: (focused) =>
                          setState(() => _focused = focused),
                      eventLoader: (day) {
                        final record =
                            events[DayRecord.dateKeyFor(day)];
                        return record == null ? const [] : [record];
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, dayEvents) {
                          if (dayEvents.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final record = dayEvents.first;
                          if (record.steps <= 0) {
                            return const SizedBox.shrink();
                          }
                          final progress =
                              (record.steps / profile.dailyGoal)
                                  .clamp(0.0, 1.0);
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              height: 4,
                              width: 16 * progress + 2,
                              decoration: BoxDecoration(
                                color: progress >= 1.0
                                    ? Colors.green
                                    : colorScheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(
                title: Formatters.date(_selected),
              ),
              if (selectedRecord == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 40,
                          color: colorScheme.onSurfaceVariant,
                          semanticLabel: 'No data',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No step data recorded for this day.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    StatCard(
                      label: 'Steps',
                      value: Formatters.steps(selectedRecord.steps),
                      icon: Icons.directions_walk,
                    ),
                    StatCard(
                      label: 'Distance',
                      value: Formatters.distance(
                        selectedRecord.distanceMeters,
                        profile.unitSystem,
                      ),
                      icon: Icons.route,
                    ),
                    StatCard(
                      label: 'Calories',
                      value: Formatters.calories(selectedRecord.calories),
                      icon: Icons.local_fire_department,
                    ),
                    StatCard(
                      label: 'Active time',
                      value:
                          Formatters.minutes(selectedRecord.activeMinutes),
                      icon: Icons.timer,
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
