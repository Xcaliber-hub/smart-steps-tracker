// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/day_record.dart';
import '../models/user_profile.dart';

/// Result of parsing an imported backup file.
class BackupImport {
  final List<DayRecord> days;
  final UserProfile? profile;

  const BackupImport({required this.days, this.profile});
}

/// CSV / JSON export and import of the user's data.
///
/// CSV columns: `date,steps,distance_m,calories,active_min,floors`.
/// JSON shape: `{version, exported_at, profile, days:[...]}`.
class BackupService {
  static const _csvHeader = [
    'date',
    'steps',
    'distance_m',
    'calories',
    'active_min',
    'floors'
  ];

  Future<Directory> _exportDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'smart_steps_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _fileName(String ext) {
    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'smart_steps_$stamp.$ext';
  }

  /// Writes all [days] as CSV, returns the file path.
  Future<String> exportCsv(List<DayRecord> days) async {
    final rows = <List<Object>>[
      _csvHeader,
      for (final d in days)
        [
          d.dateKey,
          d.steps,
          d.distanceMeters,
          d.calories,
          d.activeMinutes,
          d.floors,
        ],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final file = File(p.join((await _exportDir()).path, _fileName('csv')));
    await file.writeAsString(csv);
    return file.path;
  }

  /// Writes [days] plus [profile] as JSON, returns the file path.
  Future<String> exportJson(List<DayRecord> days, UserProfile profile) async {
    final payload = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'profile': profile.toJson(),
      'days': [for (final d in days) d.toMap()],
    };
    final file = File(p.join((await _exportDir()).path, _fileName('json')));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file.path;
  }

  /// Opens the platform share sheet for a previously exported file.
  Future<void> shareFile(String path, String subject) async {
    await Share.shareXFiles([XFile(path)], subject: subject);
  }

  /// Lets the user pick a `.csv` or `.json` backup and parses it.
  /// Returns null when the picker is cancelled.
  Future<BackupImport?> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes ??
        await File(file.path!).readAsBytes(); // path set when bytes null
    final name = file.name.toLowerCase();
    if (name.endsWith('.json')) {
      return _parseJson(utf8.decode(bytes));
    }
    return BackupImport(days: _parseCsv(utf8.decode(bytes)));
  }

  List<DayRecord> _parseCsv(String content) {
    final rows = const CsvToListConverter().convert(content);
    if (rows.isEmpty) return const [];
    final header = rows.first.map((e) => e.toString().trim()).toList();
    final idx = {for (var i = 0; i < header.length; i++) header[i]: i};
    final days = <DayRecord>[];
    for (final row in rows.skip(1)) {
      try {
        final dateStr = row[idx['date'] ?? 0].toString();
        days.add(DayRecord(
          date: DayRecord.dateFromKey(dateStr),
          steps: _toInt(row, idx, 'steps'),
          distanceMeters: _toDouble(row, idx, 'distance_m'),
          calories: _toDouble(row, idx, 'calories'),
          activeMinutes: _toInt(row, idx, 'active_min'),
          floors: _toInt(row, idx, 'floors'),
        ));
      } catch (_) {
        // Skip malformed rows rather than failing the whole import.
      }
    }
    return days;
  }

  int _toInt(List row, Map<String, int> idx, String col) {
    final i = idx[col];
    if (i == null || i >= row.length) return 0;
    return (num.tryParse(row[i].toString()) ?? 0).toInt();
  }

  double _toDouble(List row, Map<String, int> idx, String col) {
    final i = idx[col];
    if (i == null || i >= row.length) return 0;
    return (num.tryParse(row[i].toString()) ?? 0).toDouble();
  }

  BackupImport _parseJson(String content) {
    final payload = jsonDecode(content) as Map<String, dynamic>;
    final daysJson = (payload['days'] as List?) ?? const [];
    final days = <DayRecord>[];
    for (final item in daysJson) {
      try {
        days.add(
          DayRecord.fromMap(Map<String, Object?>.from(item as Map)),
        );
      } catch (_) {
        // Skip malformed entries.
      }
    }
    UserProfile? profile;
    final profileJson = payload['profile'];
    if (profileJson is Map) {
      try {
        profile = UserProfile.fromJson(
          Map<String, Object?>.from(profileJson),
        );
      } catch (_) {
        profile = null;
      }
    }
    return BackupImport(days: days, profile: profile);
  }
}
