// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reminder.dart';
import '../models/user_profile.dart';
import '../utils/formatters.dart';
import '../viewmodels/providers.dart';
import '../widgets/section_header.dart';

/// Settings tab: profile, appearance, notifications, reminders, backup, about.
class SettingsScreen extends ConsumerWidget {
  /// Creates the settings tab.
  const SettingsScreen({super.key});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveProfile(
    BuildContext context,
    WidgetRef ref,
    UserProfile updated, {
    String message = 'Saved',
  }) async {
    await ref.read(profileProvider.notifier).update(updated);
    HapticFeedback.mediumImpact();
    if (context.mounted) _snack(context, message);
  }

  /// Generic number-editing dialog. Returns the entered value, or null.
  Future<double?> _numberDialog(
    BuildContext context, {
    required String title,
    required String? initialValue,
    required String unit,
  }) {
    final controller = TextEditingController(text: initialValue ?? '');
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: unit,
            hintText: 'Enter a value',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.of(context).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editAge(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    final value = await _numberDialog(
      context,
      title: 'Age',
      initialValue: profile.age?.toString(),
      unit: 'years',
    );
    if (value == null || !context.mounted) return;
    final age = value.round();
    if (age < 1 || age > 130) {
      _snack(context, 'Please enter an age between 1 and 130.');
      return;
    }
    await _saveProfile(context, ref, profile.copyWith(age: age));
  }

  Future<void> _editHeight(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    final imperial = profile.unitSystem == UnitSystem.imperial;
    final displayed = profile.heightCm == null
        ? null
        : imperial
            ? (profile.heightCm! / 30.48).toStringAsFixed(2)
            : profile.heightCm!.toStringAsFixed(1);
    final value = await _numberDialog(
      context,
      title: 'Height',
      initialValue: displayed,
      unit: imperial ? 'ft' : 'cm',
    );
    if (value == null || !context.mounted) return;
    final cm = imperial ? value * 30.48 : value;
    if (cm < 50 || cm > 300) {
      _snack(context, 'Please enter a realistic height.');
      return;
    }
    await _saveProfile(context, ref, profile.copyWith(heightCm: cm));
  }

  Future<void> _editWeight(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    final imperial = profile.unitSystem == UnitSystem.imperial;
    final displayed = profile.weightKg == null
        ? null
        : imperial
            ? (profile.weightKg! * 2.20462).toStringAsFixed(1)
            : profile.weightKg!.toStringAsFixed(1);
    final value = await _numberDialog(
      context,
      title: 'Weight',
      initialValue: displayed,
      unit: imperial ? 'lb' : 'kg',
    );
    if (value == null || !context.mounted) return;
    final kg = imperial ? value / 2.20462 : value;
    if (kg < 20 || kg > 500) {
      _snack(context, 'Please enter a realistic weight.');
      return;
    }
    await _saveProfile(context, ref, profile.copyWith(weightKg: kg));
  }

  Future<void> _editDailyGoal(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    final value = await _numberDialog(
      context,
      title: 'Daily step goal',
      initialValue: profile.dailyGoal.toString(),
      unit: 'steps',
    );
    if (value == null || !context.mounted) return;
    final goal = value.round();
    if (goal < 500 || goal > 100000) {
      _snack(context, 'Please enter a goal between 500 and 100,000 steps.');
      return;
    }
    await _saveProfile(
      context,
      ref,
      profile.copyWith(dailyGoal: goal),
      message: 'Daily goal set to ${Formatters.steps(goal)} steps',
    );
  }

  Future<void> _pickGender(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    Gender? selected = profile.gender;
    bool confirmed = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Gender'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<Gender?>(
                groupValue: selected,
                onChanged: (v) => setDialogState(() => selected = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in [null, ...Gender.values])
                      RadioListTile<Gender?>(
                        title: Text(
                          option == null ? 'Prefer not to say' : option.name,
                        ),
                        value: option,
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                confirmed = true;
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (!confirmed || !context.mounted) return;
    await _saveProfile(context, ref, profile.copyWith(gender: selected));
  }

  String _genderLabel(Gender? gender) {
    if (gender == null) return 'Not set';
    return gender.name[0].toUpperCase() + gender.name.substring(1);
  }

  String _heightLabel(UserProfile profile) {
    if (profile.heightCm == null) return 'Not set';
    if (profile.unitSystem == UnitSystem.imperial) {
      return '${(profile.heightCm! / 2.54).toStringAsFixed(1)} in';
    }
    return '${profile.heightCm!.toStringAsFixed(1)} cm';
  }

  String _weightLabel(UserProfile profile) {
    if (profile.weightKg == null) return 'Not set';
    if (profile.unitSystem == UnitSystem.imperial) {
      return '${(profile.weightKg! * 2.20462).toStringAsFixed(1)} lb';
    }
    return '${profile.weightKg!.toStringAsFixed(1)} kg';
  }

  // --- Reminders --------------------------------------------------------

  Future<void> _pickReminderTime(
    BuildContext context,
    WidgetRef ref,
    ReminderItem reminder,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: reminder.hour,
        minute: reminder.minute,
      ),
    );
    if (picked == null || !context.mounted) return;
    final minutes = picked.hour * 60 + picked.minute;
    await ref.read(remindersProvider.notifier).updateTime(
          reminder.id,
          minutes,
        );
    if (!context.mounted) return;
    HapticFeedback.selectionClick();
    _snack(
      context,
      'Reminder time set to ${Formatters.timeOfDay(minutes)}',
    );
  }

  Future<void> _addReminder(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New reminder'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Reminder title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context)
                .pop(titleController.text.trim()),
            child: const Text('Next'),
          ),
        ],
      ),
    );
    if (title == null || !context.mounted) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null || !context.mounted) return;
    await ref.read(remindersProvider.notifier).add(
          ReminderItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title.isEmpty ? 'Reminder' : title,
            minutesOfDay: picked.hour * 60 + picked.minute,
            type: ReminderType.custom,
          ),
        );
    HapticFeedback.mediumImpact();
    if (context.mounted) _snack(context, 'Reminder added');
  }

  // --- Backup -------------------------------------------------------------

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final days = await ref.read(allDaysProvider.future);
      final backup = ref.read(backupServiceProvider);
      final path = await backup.exportCsv(days);
      await backup.shareFile(path, 'Stride CSV export');
      if (context.mounted) {
        _snack(context, 'CSV exported (${days.length} days)');
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Export failed: $e');
    }
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    try {
      final days = await ref.read(allDaysProvider.future);
      final profile = ref.read(profileProvider);
      final backup = ref.read(backupServiceProvider);
      final path = await backup.exportJson(days, profile);
      await backup.shareFile(path, 'Stride JSON backup');
      if (context.mounted) {
        _snack(context, 'JSON backup exported (${days.length} days)');
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Export failed: $e');
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    try {
      final backup = ref.read(backupServiceProvider);
      final result = await backup.pickAndParse();
      if (result == null || !context.mounted) return;
      final db = ref.read(databaseServiceProvider);
      for (final day in result.days) {
        await db.upsertDay(day);
      }
      if (result.profile != null) {
        await ref.read(profileProvider.notifier).update(result.profile!);
      }
      ref.invalidate(allDaysProvider);
      if (context.mounted) {
        _snack(context, 'Imported ${result.days.length} days');
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Import failed: $e');
    }
  }

  Future<void> _resetAllData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This permanently deletes all recorded step history, '
          'achievements and reminders. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(databaseServiceProvider).clearAll();
    ref.invalidate(allDaysProvider);
    ref.invalidate(statsProvider);
    HapticFeedback.heavyImpact();
    if (context.mounted) _snack(context, 'All data has been deleted');
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final reminders = ref.watch(remindersProvider);
    final masterOn = profile.notificationsEnabled;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Profile'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cake_outlined),
                  title: const Text('Age'),
                  subtitle:
                      Text(profile.age == null ? 'Not set' : '${profile.age}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editAge(context, ref),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.height_outlined),
                  title: const Text('Height'),
                  subtitle: Text(_heightLabel(profile)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editHeight(context, ref),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: const Text('Weight'),
                  subtitle: Text(_weightLabel(profile)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editWeight(context, ref),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Gender'),
                  subtitle: Text(_genderLabel(profile.gender)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickGender(context, ref),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Daily goal'),
                  subtitle:
                      Text('${Formatters.steps(profile.dailyGoal)} steps'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editDailyGoal(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Theme mode',
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.settings_suggest_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {profile.themeMode},
                      onSelectionChanged: (selected) => _saveProfile(
                        context,
                        ref,
                        profile.copyWith(themeMode: selected.first),
                        message: 'Theme updated',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Units',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Unit system',
                    child: SegmentedButton<UnitSystem>(
                      segments: const [
                        ButtonSegment(
                          value: UnitSystem.metric,
                          label: Text('Metric'),
                        ),
                        ButtonSegment(
                          value: UnitSystem.imperial,
                          label: Text('Imperial'),
                        ),
                      ],
                      selected: {profile.unitSystem},
                      onSelectionChanged: (selected) => _saveProfile(
                        context,
                        ref,
                        profile.copyWith(unitSystem: selected.first),
                        message: 'Units updated',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable notifications'),
                  subtitle: const Text('Master switch for all reminders'),
                  value: masterOn,
                  onChanged: (value) => _saveProfile(
                    context,
                    ref,
                    profile.copyWith(notificationsEnabled: value),
                    message: value
                        ? 'Notifications enabled'
                        : 'Notifications disabled',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _subSwitch(
                  context,
                  ref,
                  profile,
                  title: 'Morning motivation',
                  subtitle: 'Start your day with a nudge',
                  value: profile.morningMotivation,
                  enabled: masterOn,
                  apply: (p, v) => p.copyWith(morningMotivation: v),
                ),
                _subSwitch(
                  context,
                  ref,
                  profile,
                  title: 'Goal reached alert',
                  subtitle: 'Celebrate when you hit your daily goal',
                  value: profile.goalReachedAlert,
                  enabled: masterOn,
                  apply: (p, v) => p.copyWith(goalReachedAlert: v),
                ),
                _subSwitch(
                  context,
                  ref,
                  profile,
                  title: 'Halfway reminder',
                  subtitle: 'A push when you pass 50% of your goal',
                  value: profile.halfwayReminder,
                  enabled: masterOn,
                  apply: (p, v) => p.copyWith(halfwayReminder: v),
                ),
                _subSwitch(
                  context,
                  ref,
                  profile,
                  title: 'Inactivity alert',
                  subtitle: 'Reminds you to move after sitting too long',
                  value: profile.inactivityAlert,
                  enabled: masterOn,
                  apply: (p, v) => p.copyWith(inactivityAlert: v),
                ),
                _subSwitch(
                  context,
                  ref,
                  profile,
                  title: 'Evening summary',
                  subtitle: 'A recap of your day before bed',
                  value: profile.eveningSummary,
                  enabled: masterOn,
                  apply: (p, v) => p.copyWith(eveningSummary: v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Reminders',
            action: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              onPressed: () => _addReminder(context, ref),
            ),
          ),
          Card(
            child: reminders.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No reminders yet. Add one to get nudged at a '
                      'specific time.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < reminders.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                        _reminderTile(context, ref, reminders[i]),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Backup'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Export CSV'),
                  subtitle: const Text('Day-by-day step history'),
                  trailing: const Icon(Icons.share_outlined),
                  onTap: () => _exportCsv(context, ref),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.data_object_outlined),
                  title: const Text('Export JSON'),
                  subtitle: const Text('Full backup including profile'),
                  trailing: const Icon(Icons.share_outlined),
                  onTap: () => _exportJson(context, ref),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('Import backup'),
                  subtitle: const Text('Restore from a previous backup file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importBackup(context, ref),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Reset all data',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: const Text('Permanently delete everything'),
                  onTap: () => _resetAllData(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'About'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.directions_walk),
                  title: Text('Stride'),
                  subtitle: Text('Version 1.0.0'),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Made by Aditya Awasthi'),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.code_outlined),
                  title: Text('GPL-3.0 — free and open-source'),
                  subtitle: Text(
                    'Your data stays on your device. '
                    'Source code is freely available.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _subSwitch(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile, {
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required UserProfile Function(UserProfile, bool) apply,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value && enabled,
      onChanged: enabled
          ? (v) => _saveProfile(
                context,
                ref,
                apply(profile, v),
                message: '$title ${v ? 'on' : 'off'}',
              )
          : null,
    );
  }

  Widget _reminderTile(
    BuildContext context,
    WidgetRef ref,
    ReminderItem reminder,
  ) {
    return ListTile(
      leading: Icon(
        reminder.enabled ? Icons.alarm : Icons.alarm_off_outlined,
        semanticLabel: 'Reminder',
      ),
      title: Text(reminder.title),
      subtitle: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => _pickReminderTime(context, ref, reminder),
        child: Text(
          Formatters.timeOfDay(reminder.minutesOfDay),
          semanticsLabel:
              'Reminder time ${Formatters.timeOfDay(reminder.minutesOfDay)}, tap to change',
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Enable ${reminder.title}',
            child: Switch(
              value: reminder.enabled,
              onChanged: (value) => ref
                  .read(remindersProvider.notifier)
                  .toggle(reminder.id, value),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete reminder',
            onPressed: () {
              ref.read(remindersProvider.notifier).remove(reminder.id);
              HapticFeedback.mediumImpact();
              _snack(context, 'Reminder deleted');
            },
          ),
        ],
      ),
    );
  }
}
