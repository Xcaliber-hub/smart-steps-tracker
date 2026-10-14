# stride

A privacy-friendly, open-source step counter for Android — tracks your daily steps, goals, stats, and achievements entirely on-device.

![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)

## Features

**Tracking**
- Automatic step counting via the device sensor (`StepTrackerService` + Android foreground service)
- Daily records with goals, achievements, and streak logic
- Calorie and distance estimates derived from your height and weight

**Appearance**
- System/light/dark themes, AMOLED black, optional wallpaper-based dynamic colors
- Eight accent colors, adjustable text size, and optional navigation labels

**Goals**
- Custom daily step goals
- Progress ring and live updates on the home screen

**Stats**
- Weekly/monthly aggregates, streaks (current & longest), personal bests
- Charts for trends over time

**History**
- Calendar view of past days (`table_calendar`)
- Per-day detail: steps, goal progress, calories, distance

**Achievements**
- Milestones (10k steps, 7-day streak, etc.)
- Confetti celebration on unlock 🎉

**Reminders**
- Optional goal reminders and streak nudges
- Scheduled with inexact alarms (no exact-alarm permission requested)

**Health**
- Estimates only: stride length, calories, distance, active minutes — **not medical data**

**Backup**
- Export daily history to CSV
- Import/export database files via file picker

## Screenshots

*Screenshots coming soon — add screenshots here.*

## Architecture

MVVM with Riverpod 2.x for state management:

```
UI (screens/widgets)
   │
   ▼
ViewModels (Riverpod providers)
   │
   ▼
Repositories (sensor-delta → DayRecord, StatsCalculator)
   │
   ▼
Services (StepTrackerService, DatabaseService, NotificationService, SettingsService, BackupService)
   │
   ▼
Storage/Sensors (SQLite via sqflite, SharedPreferences, pedometer, WorkManager)
```

Key classes:

| Class | Responsibility |
|---|---|
| `StepTrackerService` | pedometer stream and native Android foreground-service lifecycle |
| `StepRepository` | converts sensor deltas into `DayRecord`s |
| `DatabaseService` | sqflite persistence |
| `SettingsService` | SharedPreferences (goals, weight, height, preferences) |
| `NotificationService` | local reminders |
| `BackupService` | CSV export/import |
| `HealthCalculations` | stride ≈ height × 0.415 (walking) / 0.413 (running); calories ≈ steps × 0.04 × weight / 70; activeMin ≈ steps / 100 |
| `StatsCalculator` | streaks, aggregates, bests |

## Getting started

**Prerequisites**
- Flutter stable SDK
- Android SDK (Android only — no iOS setup in this repo)

```bash
flutter pub get
flutter run
```

**Build APK**

```bash
flutter build apk --debug
```

See `android/app/build.gradle.kts` for the configured minSdk.

## Verification

Verified with **Flutter 3.47.7** (Dart 3.13.5):

```bash
flutter pub get   # resolves cleanly
flutter analyze   # No issues found!
flutter test      # All tests passed!
```

Dependency notes:
- `pedometer` must be **^4.2.0** — the 2.x line predates Dart null safety
  (`sdk: >=2.7.0 <3.0.0`) and cannot resolve on modern toolchains.
- Other pins (`fl_chart` 0.69.x, `flutter_local_notifications` 18.x,
  `workmanager` 0.5.x, `table_calendar` 3.1.x) are the newest releases
  compatible with the APIs used here; `dart pub outdated` lists newer
  majors that would need code migration.

## Permissions explained (Android)

| Permission | Why |
|---|---|
| `ACTIVITY_RECOGNITION` | required to read the step-counter sensor |
| `POST_NOTIFICATIONS` | reminders and achievement notifications |
| `RECEIVE_BOOT_COMPLETED` | lets scheduled background work resume after a reboot |
| `SCHEDULE_EXACT_ALARM` | declared; the app uses inexact alarms, so exact alarms are never requested |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_HEALTH` | persistent step tracking with an ongoing notification |

## Background behavior & limitations

- **Background capture.** An Android health foreground service keeps the step-counter sensor listener active while the Flutter UI is closed, stores the latest hardware reading, and restarts after process reclamation. WorkManager reconciles durable readings into daily records and reminders; tracking is also restored after reboot when permission remains granted. The service shows an ongoing notification. Android's force-stop action, revoked permission, missing step-counter hardware, or manufacturer battery restrictions can still stop collection.
- **Midnight handling.** At the first reading for a new calendar day, the previous sensor reading is used as the day boundary so steps after midnight are not discarded. A reading that is lower than the previous one is only accepted as a device reboot when it is small enough to be steps walked since boot; otherwise it is treated as a stale reading and ignored, so the daily total can never jump to the "steps since boot" figure. After a real reboot today's earlier steps are carried forward.
- **Floors are always 0** — the pedometer plugin exposes no floor data.
- **Estimates, not medical data.** Calorie, distance, and active-minute values are rough calculations, not medical advice.
- **Inexact reminders.** The exact-alarm permission is not requested; reminders may arrive a few minutes early or late.
- **Android only.** This repo has no iOS setup.

## Project structure

```
smart-steps-tracker/
├── lib/
│   ├── main.dart
│   ├── models/        # DayRecord, achievement models, etc.
│   ├── services/      # step tracking, database, notifications, settings, backup, WorkManager callback
│   ├── repositories/  # sensor-delta → DayRecord, stats aggregation
│   ├── viewmodels/    # Riverpod providers
│   ├── screens/       # home, stats, history, achievements, settings
│   ├── widgets/       # reusable UI components
│   ├── utils/         # helpers, formatters
│   └── themes/        # Material 3 theme, dynamic color support
├── assets/
├── android/
└── pubspec.yaml
```

## Tech stack

| Area | Package / detail |
|---|---|
| State management | `flutter_riverpod` 2.x (MVVM) |
| UI | Flutter, Material 3, `dynamic_color` (dynamic colors on Android 12+) |
| Charts | `fl_chart` |
| Steps | `pedometer` |
| Background | `workmanager` |
| Permissions | `permission_handler` |
| Database | `sqflite` |
| Preferences | `shared_preferences` |
| Notifications | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Backup | `csv`, `share_plus`, `file_picker`, `path_provider` |
| Misc UI | `intl`, `confetti`, `table_calendar` |

Package: `smart_steps_tracker` · Version: 1.2.0+3

## Contributing

Pull requests welcome. This is a GPL-3.0 project — by contributing, you agree your changes will be released under the same license.

## License

GPL-3.0 — see the `LICENSE` file for details.
