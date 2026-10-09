// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'models/reminder.dart';
import 'screens/main_scaffold.dart';
import 'screens/onboarding_screen.dart';
import 'services/workmanager_callback.dart';
import 'themes/app_theme.dart';
import 'utils/constants.dart';
import 'viewmodels/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Notifications first: channels must exist before anything posts.
  final notifications = container.read(notificationServiceProvider);
  await notifications.init();

  // Background maintenance tasks (survive reboots via WorkManager).
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  await Workmanager().registerPeriodicTask(
    AppConstants.wmUniqueSync,
    AppConstants.wmTaskSyncSteps,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.not_required),
  );
  await Workmanager().registerPeriodicTask(
    AppConstants.wmUniqueReminders,
    AppConstants.wmTaskCheckReminders,
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.not_required),
  );

  // Runtime permissions (best effort here; screens re-ask with rationale).
  final tracker = container.read(stepTrackerServiceProvider);
  await tracker.ensurePermission();
  await notifications.requestPermission();

  // Step pipeline.
  final repository = container.read(stepRepositoryProvider);
  await repository.initialize();
  await tracker.start();

  // Seed default reminders on first launch.
  final db = container.read(databaseServiceProvider);
  if ((await db.getReminders()).isEmpty) {
    for (final reminder in ReminderItem.defaults()) {
      await db.upsertReminder(reminder);
    }
  }
  final profile =
      await container.read(settingsServiceProvider).loadProfile();
  await notifications.rescheduleAll(
    profile: profile,
    reminders: await db.getReminders(),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SmartStepsApp(),
    ),
  );
}

class SmartStepsApp extends ConsumerWidget {
  const SmartStepsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(profileProvider.select((p) => p.themeMode));

    // Dynamic (wallpaper) colors on Android 12+; seed fallback otherwise.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final light = AppTheme.light;
        final dark = AppTheme.dark;
        return MaterialApp(
          title: 'Smart Steps Tracker',
          debugShowCheckedModeBanner: false,
          theme: light.copyWith(
            colorScheme: lightDynamic ?? light.colorScheme,
          ),
          darkTheme: dark.copyWith(
            colorScheme: darkDynamic ?? dark.colorScheme,
          ),
          themeMode: themeMode,
          home: const RootScreen(),
        );
      },
    );
  }
}

/// Shows onboarding on first launch, the main app afterwards.
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(onboardingDoneProvider);
    return done.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const MainScaffold(),
      data: (isDone) =>
          isDone ? const MainScaffold() : const OnboardingScreen(),
    );
  }
}
