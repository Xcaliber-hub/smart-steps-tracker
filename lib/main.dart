// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:dynamic_color/dynamic_color.dart';
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

  // Show the UI immediately. All service initialization happens in BootScreen
  // AFTER the first frame: requesting runtime permissions before runApp()
  // can leave the startup hanging on some devices because the permission
  // dialog has no resumed activity to attach to.
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StrideApp(),
    ),
  );
}

/// Splash shown while services boot, then hands off to the real UI.
///
/// Initialization used to happen in [main] before [runApp], which left the
/// app stuck on the native splash on devices where the early permission
/// request never resolved. Doing it here (after the first frame) lets the
/// system permission dialogs appear normally. Any single failure is
/// contained: the app always reaches its UI, possibly with degraded
/// services, instead of hanging forever.
class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen> {
  bool _ready = false;
  String _status = 'Starting up…';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _setStatus(String status) {
    if (mounted) setState(() => _status = status);
  }

  Future<void> _boot() async {
    try {
      // Notifications first: channels must exist before anything posts.
      _setStatus('Setting up notifications…');
      final notifications = ref.read(notificationServiceProvider);
      await notifications.init();

      // Background maintenance tasks (survive reboots via WorkManager).
      _setStatus('Scheduling background tasks…');
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        AppConstants.wmUniqueSync,
        AppConstants.wmTaskSyncSteps,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
      await Workmanager().registerPeriodicTask(
        AppConstants.wmUniqueReminders,
        AppConstants.wmTaskCheckReminders,
        frequency: const Duration(hours: 1),
        constraints: Constraints(networkType: NetworkType.notRequired),
      );

      // Runtime permissions (the dialogs need a visible activity).
      _setStatus('Requesting permissions…');
      final tracker = ref.read(stepTrackerServiceProvider);
      await tracker.ensurePermission();
      await notifications.requestPermission();

      // Step pipeline.
      _setStatus('Loading your data…');
      final repository = ref.read(stepRepositoryProvider);
      await repository.initialize();
      await tracker.start();

      // Seed default reminders on first launch.
      final db = ref.read(databaseServiceProvider);
      if ((await db.getReminders()).isEmpty) {
        for (final reminder in ReminderItem.defaults()) {
          await db.upsertReminder(reminder);
        }
      }
      final profile =
          await ref.read(settingsServiceProvider).loadProfile();
      await notifications.rescheduleAll(
        profile: profile,
        reminders: await db.getReminders(),
      );
    } catch (e) {
      // Never trap the user on this screen: continue with whatever
      // initialized successfully.
      debugPrint('Boot failed: $e');
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const RootScreen();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status),
          ],
        ),
      ),
    );
  }
}

class StrideApp extends ConsumerWidget {
  const StrideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(profileProvider.select((p) => p.themeMode));

    // Dynamic (wallpaper) colors on Android 12+; seed fallback otherwise.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final light = AppTheme.light;
        final dark = AppTheme.dark;
        return MaterialApp(
          title: 'Stride',
          debugShowCheckedModeBanner: false,
          theme: light.copyWith(
            colorScheme: lightDynamic ?? light.colorScheme,
          ),
          darkTheme: dark.copyWith(
            colorScheme: darkDynamic ?? dark.colorScheme,
          ),
          themeMode: themeMode,
          home: const BootScreen(),
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
