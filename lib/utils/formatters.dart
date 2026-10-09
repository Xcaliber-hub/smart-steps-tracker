// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:intl/intl.dart';

import '../models/user_profile.dart';

/// Display formatting that honors the user's unit system and locale.
class Formatters {
  Formatters._();

  static final _intFormat = NumberFormat.decimalPattern();
  static final _oneDecimal = NumberFormat('0.0');
  static final _dateFormat = DateFormat('EEE, MMM d');
  static final _shortDate = DateFormat('MMM d');

  static String steps(int steps) => _intFormat.format(steps);

  /// Distance: km (metric) or miles (imperial), one decimal.
  static String distance(double meters, UnitSystem units) {
    if (units == UnitSystem.imperial) {
      final miles = meters / 1609.344;
      return '${_oneDecimal.format(miles)} mi';
    }
    return '${_oneDecimal.format(meters / 1000)} km';
  }

  /// Raw distance value in the user's unit system (for charts/compact UI).
  static double distanceValue(double meters, UnitSystem units) {
    return units == UnitSystem.imperial ? meters / 1609.344 : meters / 1000;
  }

  static String distanceUnit(UnitSystem units) =>
      units == UnitSystem.imperial ? 'mi' : 'km';

  static String calories(double kcal) => '${kcal.round()} kcal';

  static String minutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static String percent(double value) => '${(value * 100).round()}%';

  static String date(DateTime date) => _dateFormat.format(date);

  static String shortDate(DateTime date) => _shortDate.format(date);

  static String timeOfDay(int minutesOfDay) {
    final h = (minutesOfDay ~/ 60).toString().padLeft(2, '0');
    final m = (minutesOfDay % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
