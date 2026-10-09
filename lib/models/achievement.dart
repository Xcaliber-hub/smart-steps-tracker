// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

/// What an achievement measures.
enum AchievementMetric {
  /// Steps recorded in a single day.
  singleDaySteps,

  /// Consecutive days hitting the daily goal.
  streakDays,

  /// Distance walked in a single day, in meters.
  singleDayDistanceMeters,

  /// Total steps across all recorded days.
  lifetimeSteps,
}

/// A badge the user can unlock. Static catalog entries are defined in
/// [AchievementCatalog]; unlock state is persisted in the database.
class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementMetric metric;

  /// Threshold that unlocks the badge (steps, days, or meters by [metric]).
  final int targetValue;

  /// When the badge was unlocked, or null while locked.
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.targetValue,
    this.unlockedAt,
  });

  bool get unlocked => unlockedAt != null;

  Achievement copyWith({DateTime? unlockedAt}) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      metric: metric,
      targetValue: targetValue,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'unlocked_at': unlockedAt?.toIso8601String(),
    };
  }
}

/// The fixed badge catalog shipped with the app.
class AchievementCatalog {
  AchievementCatalog._();

  static const List<Achievement> all = [
    Achievement(
      id: 'first_walk',
      title: 'First Walk',
      description: 'Record your very first steps.',
      metric: AchievementMetric.lifetimeSteps,
      targetValue: 1,
    ),
    Achievement(
      id: 'steps_5k',
      title: '5K Steps',
      description: 'Walk 5,000 steps in a single day.',
      metric: AchievementMetric.singleDaySteps,
      targetValue: 5000,
    ),
    Achievement(
      id: 'steps_10k',
      title: '10K Steps',
      description: 'Walk 10,000 steps in a single day.',
      metric: AchievementMetric.singleDaySteps,
      targetValue: 10000,
    ),
    Achievement(
      id: 'steps_20k',
      title: '20K Steps',
      description: 'Walk 20,000 steps in a single day.',
      metric: AchievementMetric.singleDaySteps,
      targetValue: 20000,
    ),
    Achievement(
      id: 'streak_7',
      title: '7-Day Streak',
      description: 'Hit your daily goal 7 days in a row.',
      metric: AchievementMetric.streakDays,
      targetValue: 7,
    ),
    Achievement(
      id: 'streak_30',
      title: '30-Day Streak',
      description: 'Hit your daily goal 30 days in a row.',
      metric: AchievementMetric.streakDays,
      targetValue: 30,
    ),
    Achievement(
      id: 'streak_100',
      title: '100-Day Streak',
      description: 'Hit your daily goal 100 days in a row.',
      metric: AchievementMetric.streakDays,
      targetValue: 100,
    ),
    Achievement(
      id: 'marathon',
      title: 'Marathon Distance',
      description: 'Walk 42.2 km in a single day.',
      metric: AchievementMetric.singleDayDistanceMeters,
      targetValue: 42195,
    ),
    Achievement(
      id: 'million_steps',
      title: 'Million Steps',
      description: 'Reach 1,000,000 lifetime steps.',
      metric: AchievementMetric.lifetimeSteps,
      targetValue: 1000000,
    ),
  ];
}
