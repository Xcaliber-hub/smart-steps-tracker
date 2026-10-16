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
  // after the first frame so runtime permission dialogs have a visible activity.
  runApp(
    UncontrolledProviderScope(container: container, child: const StrideApp()),
  );
}

/// Splash shown while services boot, then hands off to the real UI.
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

  Future<void> _attempt(String status, Future<void> Function() action) async {
    _setStatus(status);
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('$status failed: $error\n$stackTrace');
    }
  }

  Future<void> _boot() async {
    final notifications = ref.read(notificationServiceProvider);
    final tracker = ref.read(stepTrackerServiceProvider);
    final repository = ref.read(stepRepositoryProvider);

    await _attempt('Checking account setup…', () async {
      await ref.read(firebaseAvailableProvider.future);
    });
    await _attempt('Setting up notifications…', notifications.init);
    await _attempt('Scheduling background tasks…', () async {
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
    });
    await _attempt('Requesting permissions…', () async {
      await tracker.ensurePermission();
      await notifications.requestPermission();
    });
    await _attempt('Loading your data…', repository.initialize);
    // Kept separate from all previous initialization: a database, reminder,
    // or notification failure must not silently skip tracker.start().
    await _attempt('Starting step tracking…', tracker.start);
    await _attempt('Finishing setup…', () async {
      final db = ref.read(databaseServiceProvider);
      if ((await db.getReminders()).isEmpty) {
        for (final reminder in ReminderItem.defaults()) {
          await db.upsertReminder(reminder);
        }
      }
      final profile = await ref.read(settingsServiceProvider).loadProfile();
      await notifications.rescheduleAll(
        profile: profile,
        reminders: await db.getReminders(),
      );
    });

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
    final profile = ref.watch(profileProvider);
    final seedColor = Color(profile.accentColor);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        title: 'Stride',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(
          seedColor: seedColor,
          dynamicScheme: profile.dynamicColor ? lightDynamic : null,
          showNavigationLabels: profile.showNavigationLabels,
        ),
        darkTheme: AppTheme.dark(
          seedColor: seedColor,
          dynamicScheme: profile.dynamicColor ? darkDynamic : null,
          amoledBlack: profile.amoledBlack,
          showNavigationLabels: profile.showNavigationLabels,
        ),
        themeMode: profile.themeMode,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final systemScale = media.textScaler.scale(1);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(systemScale * profile.fontScale),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const BootScreen(),
      ),
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const MainScaffold(),
      data: (isDone) =>
          isDone ? const MainScaffold() : const OnboardingScreen(),
    );
  }
}
