// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

/// Kind of reminder, used to pick default scheduling behavior.
enum ReminderType {
  /// "Time to move" after a period without steps.
  inactivity,

  /// Morning motivational nudge.
  morning,

  /// Nudge when the day's goal is still unmet.
  goal,

  /// Evening summary of the day.
  evening,

  /// User-created reminder at a custom time.
  custom,
}

/// A scheduled reminder. Times are stored as minutes since midnight so they
/// survive timezone/DST changes without drift.
class ReminderItem {
  final String id;
  final String title;
  final int minutesOfDay;
  final bool enabled;
  final ReminderType type;

  const ReminderItem({
    required this.id,
    required this.title,
    required this.minutesOfDay,
    this.enabled = true,
    this.type = ReminderType.custom,
  });

  int get hour => minutesOfDay ~/ 60;
  int get minute => minutesOfDay % 60;

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  ReminderItem copyWith({
    String? id,
    String? title,
    int? minutesOfDay,
    bool? enabled,
    ReminderType? type,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      minutesOfDay: minutesOfDay ?? this.minutesOfDay,
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'minutes_of_day': minutesOfDay,
      'enabled': enabled ? 1 : 0,
      'type': type.name,
    };
  }

  factory ReminderItem.fromMap(Map<String, Object?> map) {
    return ReminderItem(
      id: map['id']! as String,
      title: map['title']! as String,
      minutesOfDay: (map['minutes_of_day'] as num).toInt(),
      enabled: (map['enabled'] as num).toInt() == 1,
      type: ReminderType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'custom'),
        orElse: () => ReminderType.custom,
      ),
    );
  }

  /// Sensible defaults installed on first launch.
  static List<ReminderItem> defaults() {
    return const [
      ReminderItem(
        id: 'morning',
        title: 'Morning motivation',
        minutesOfDay: 8 * 60,
        type: ReminderType.morning,
      ),
      ReminderItem(
        id: 'goal',
        title: 'Goal reminder',
        minutesOfDay: 18 * 60,
        type: ReminderType.goal,
      ),
      ReminderItem(
        id: 'evening',
        title: 'Evening summary',
        minutesOfDay: 21 * 60,
        type: ReminderType.evening,
      ),
      ReminderItem(
        id: 'inactivity',
        title: 'Move reminder',
        minutesOfDay: 15 * 60,
        type: ReminderType.inactivity,
      ),
    ];
  }
}
