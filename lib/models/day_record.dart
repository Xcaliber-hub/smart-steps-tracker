// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

/// Aggregated fitness metrics for a single calendar day.
///
/// All values are derived from the step count plus the user's profile
/// (see [HealthCalculations]). Dates are stored as `yyyy-MM-dd` keys in
/// the local timezone.
class DayRecord {
  /// The calendar day this record belongs to (time component is ignored).
  final DateTime date;

  /// Total steps recorded for the day.
  final int steps;

  /// Distance in meters, estimated from steps and stride length.
  final double distanceMeters;

  /// Estimated kilocalories burned from walking.
  final double calories;

  /// Estimated active walking minutes.
  final int activeMinutes;

  /// Floors climbed (0 when the device has no floor/barometer support).
  final int floors;

  const DayRecord({
    required this.date,
    this.steps = 0,
    this.distanceMeters = 0,
    this.calories = 0,
    this.activeMinutes = 0,
    this.floors = 0,
  });

  /// `yyyy-MM-dd` key used as the primary key in the database.
  String get dateKey => DayRecord.dateKeyFor(date);

  static String dateKeyFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static DateTime dateFromKey(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  DayRecord copyWith({
    DateTime? date,
    int? steps,
    double? distanceMeters,
    double? calories,
    int? activeMinutes,
    int? floors,
  }) {
    return DayRecord(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      calories: calories ?? this.calories,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      floors: floors ?? this.floors,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'date': dateKey,
      'steps': steps,
      'distance_m': distanceMeters,
      'calories': calories,
      'active_min': activeMinutes,
      'floors': floors,
    };
  }

  factory DayRecord.fromMap(Map<String, Object?> map) {
    return DayRecord(
      date: dateFromKey(map['date']! as String),
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      distanceMeters: (map['distance_m'] as num?)?.toDouble() ?? 0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0,
      activeMinutes: (map['active_min'] as num?)?.toInt() ?? 0,
      floors: (map['floors'] as num?)?.toInt() ?? 0,
    );
  }
}
