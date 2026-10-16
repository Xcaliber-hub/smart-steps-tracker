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
- Animated glow beam riding around the floating navigation dock
- Soft accent-coloured light glow behind the motivation, stat, and history cards

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

**Friends & groups**
- Email/password Firebase Authentication
- Private groups with high-entropy invite codes that expire after 7 days
- Settings name is shown to private-group members; step sharing remains opt-in
- Optional sharing of only today's step total and its last-updated time
- Age, height, weight, gender, step history, distance, calories, and goals stay local

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
Services (StepTrackerService, DatabaseService, FirebaseService, GroupService, NotificationService, SettingsService, BackupService)
   │
   ▼
Storage/Sensors (SQLite via sqflite, Firestore groups, SharedPreferences, pedometer, WorkManager)
```

Key classes:

| Class | Responsibility |
|---|---|
| `StepTrackerService` | pedometer stream and native Android foreground-service lifecycle |
| `StepRepository` | converts sensor deltas into `DayRecord`s |
| `DatabaseService` | sqflite persistence |
| `FirebaseService` / `AuthService` | optional Firebase bootstrap and email/password authentication |
| `GroupService` | private group membership, invite codes, and opt-in current-day step totals |
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

### Firebase setup (optional; local tracking works without it)

1. Create a Firebase project and register an Android app with application ID
   `com.smartsteps.smart_steps_tracker`.
2. Enable **Email/Password** under Firebase Authentication → Sign-in method.
3. Create a Cloud Firestore database and deploy the included security rules:
   `firebase deploy --only firestore:rules` (select your Firebase project in the
   Firebase CLI first).
4. Place the Android client config at `android/app/google-services.json` (the
   supplied source archive includes it). The Google Services Gradle plugin
   processes it, and the app initializes Firebase from the generated Android
   resources by default. These client identifiers are not service-account
   credentials; never include service-account keys in the app. For an explicit
   build-time override, provide all four Dart options:

   ```bash
   flutter run \
     --dart-define=FIREBASE_API_KEY=YOUR_API_KEY \
     --dart-define=FIREBASE_APP_ID=YOUR_ANDROID_APP_ID \
     --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID \
     --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
   ```

   Supply the same `--dart-define` values to release builds when overriding the
   Android config. Without a usable native config or all four Dart options, the
   app stays in local-only mode and tracking remains available.
5. In **Friends & groups**, create an account or sign in, then create a group
   or join with an invite code. Your Settings name is used as your group
   display name and updates your roster entries when changed; until a Settings
   name is set, the registration name is used. Group members see this name
   whether or not step sharing is enabled. Sharing starts **off**. When enabled, Stride
   writes only `steps` and `updatedAt` to each group; turning it off deletes
   those documents. Foreground sensor changes sync immediately, and Android
   WorkManager refreshes an opted-in total about every 15 minutes. A value
   updated on a previous local calendar day appears as “Not shared today.”

`firestore.rules` restricts group data to members, requires a valid invite for
joining, prevents invite enumeration, and limits shared step documents to the
count and server timestamp. Never deploy with Firestore in test mode.

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
| `INTERNET` | Firebase Authentication and Cloud Firestore when configured |
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
│   ├── services/      # step tracking, Firebase auth/groups, database, notifications, settings, backup
│   ├── repositories/  # sensor-delta → DayRecord, stats aggregation
│   ├── viewmodels/    # Riverpod providers
│   ├── screens/       # home, stats, history, achievements, groups, settings
│   ├── widgets/       # reusable UI components
│   ├── utils/         # helpers, formatters
│   └── themes/        # Material 3 theme, dynamic color support
├── assets/
├── android/
├── firebase.json
├── firestore.rules
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
| Database | `sqflite` (local), `cloud_firestore` (private groups only) |
| Authentication | `firebase_auth` (email/password) |
| Preferences | `shared_preferences` |
| Notifications | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Backup | `csv`, `share_plus`, `file_picker`, `path_provider` |
| Misc UI | `intl`, `confetti`, `table_calendar` |

Package: `smart_steps_tracker` · Version: 1.2.0+3

## Contributing

Pull requests welcome. This is a GPL-3.0 project — by contributing, you agree your changes will be released under the same license.

## License

GPL-3.0 — see the `LICENSE` file for details.
