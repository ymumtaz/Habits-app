# Habits App — skeleton

A Flutter app for tracking daily/weekly habits with streaks. Data is stored
locally on-device (SQLite via `sqflite`) — no backend, works offline.

## What's here

- **Habits & streaks** (built): create habits (daily, or "X times/week"),
  mark them done for today, see current streak / best streak / a combined
  "streak score" per habit, and a history list. A monthly calendar on the
  habit detail screen lets you tap any past day to log or undo it — useful
  for backfilling real history and for testing the streak logic without
  waiting for real days to pass.
- **Projects & time tracking** (built): create projects, start/stop a timer
  per project (only one timer runs app-wide at a time — starting one stops
  whatever else was running), see total time tracked (down to the second)
  and a session history per project. You can also log a past session by
  hand (a date/time + a duration) instead of using the live timer, and
  delete a session if you log something wrong. This is the start of the
  "archive of work done" from the brief; see Suggested next steps for where
  to take it further.
- Bottom navigation switches between the two (`lib/screens/root_nav_screen.dart`).

## Project layout

```
lib/
  models/
    habit.dart, habit_log.dart      Habit domain — plain data classes + SQLite (de)serialization
    project.dart, time_entry.dart   Project/time-tracking domain
  data/
    database.dart            sqflite connection + schema (onCreate)
    habit_repository.dart    CRUD for habits/logs
    habit_provider.dart      ChangeNotifier — habit state the UI listens to
    project_repository.dart  CRUD for projects/time entries, start/stop timer
    project_provider.dart    ChangeNotifier — project state + live timer tick
  services/
    streak_calculator.dart   Turns raw logs into current/best streak + score
  utils/
    duration_format.dart     "2h 14m 5s" / "03:45" formatting for tracked time
  screens/
    root_nav_screen.dart           Bottom nav shell (Habits / Projects)
    home_screen.dart               Habit list, mark-done, empty state
    add_edit_habit_screen.dart     Create/edit a habit
    habit_detail_screen.dart       Streak stats, monthly calendar, history
    projects_screen.dart           Project list, start/stop timer, empty state
    add_edit_project_screen.dart   Create/edit a project
    project_detail_screen.dart     Total time, timer control, session history
  widgets/
    habit_card.dart, streak_badge.dart, project_card.dart
    monthly_habit_calendar.dart    Tap-a-day calendar (log/undo past days)
    add_manual_entry_dialog.dart   "Add a past session" dialog for projects
  theme/app_theme.dart
  app.dart, main.dart
```

**Streak logic** (`lib/services/streak_calculator.dart`): daily habits streak
on consecutive calendar days; weekly habits ("3x/week") streak on consecutive
calendar weeks that hit the target count. Today doesn't break a streak until
the day is over. This is the piece most worth reading/tweaking first since it
defines what "streak score" means for the app.

## Running it

This was written in an environment without network access to the Dart/Flutter
package servers, so it hasn't been run or `flutter analyze`'d yet — do that
first thing on your machine:

1. Install Flutter (https://docs.flutter.dev/get-started/install) if you
   haven't already, and make sure `flutter doctor` is happy for Android
   (Android Studio + an SDK + a device or emulator).
2. From this folder:
   ```
   flutter pub get
   flutter create . --platforms=android
   ```
   The second command backfills the `android/` (and any other platform)
   folder Flutter projects need — it won't touch `lib/` or `pubspec.yaml`.
3. Run it:
   ```
   flutter run
   ```
4. Sanity check:
   ```
   flutter analyze
   ```
   in case anything needs a small fix for the exact Flutter/Dart version on
   your machine (dependency versions in `pubspec.yaml` are pinned to
   reasonably recent stable releases as of writing, but that can drift).

## Testing

For a first mobile app, it's worth knowing there are really three different
kinds of "testing" here, and they catch different kinds of bugs:

1. **Manual testing on an emulator/device** — the one you already know how
   to do: `flutter run`, click around. This is how you'll judge whether the
   app *feels* right (layout, colors, whether marking a habit done feels
   responsive). Things worth clicking through by hand:
   - Add a daily habit, mark it done, un-mark it (tap the checkmark again),
     confirm the streak badge updates instantly.
   - Add a "3x/week" habit, mark it done 3 times, confirm the week counter
     hits 3/3.
   - Force-close the app (or restart the emulator) and reopen it — data
     should still be there, since it's in SQLite, not memory.
   - Edit a habit's name/icon/color and confirm it updates on the home
     screen.
   - Delete a habit and confirm it disappears (and doesn't crash).
   - To test streak-breaking without waiting real days: change your
     emulator's/phone's system date forward a day or two (Settings → Date &
     time on the device), reopen the app, and check the streak behaves as
     expected (still counted if you completed "yesterday", broken if you
     skipped further back). Set the date back when done.

2. **Automated unit tests** — ordinary Dart tests for pure logic, no UI or
   device needed. This is the highest-value kind of test here because the
   streak math (`lib/services/streak_calculator.dart`) has real edge cases
   (gaps, week boundaries, "today not done yet") that are easy to get wrong
   and tedious to re-check by hand every time you touch that file. I added
   `test/streak_calculator_test.dart` with a first set of cases — run it
   with:
   ```
   flutter test test/streak_calculator_test.dart
   ```
   or all tests at once:
   ```
   flutter test
   ```
   As you add features (e.g. changing what "streak score" means), add a
   test case for the new behavior in that same file before or as you change
   the code — that's the habit worth building here, not just for this app.

3. **Widget tests** — check that a specific widget renders and responds to
   taps correctly, without a real device (`flutter_test` simulates one).
   `test/habit_card_test.dart` is an example, checking that `HabitCard`
   shows the habit's name/streak and that tapping the checkmark fires the
   right callback. Good for widgets with real logic in them (like
   `HabitCard`'s completed/not-completed states); not usually worth writing
   for very simple widgets.

There's a fourth kind — **integration tests** (full app flows on a real
emulator, driven by code instead of your thumb, via the `integration_test`
package) — which is worth adding later once there's more app to break, but
is overkill for a skeleton this size.

None of this has been run yet in the environment I built it in (see below),
so `flutter test` is worth running before `flutter run` — it's faster
feedback and doesn't need an emulator at all.

## Suggested next steps

- Editing an existing time entry (you can add a past session and delete one,
  but not fix one's date/duration after the fact — currently that means
  delete and re-add).
- Surface the `note` field on manual project entries in the UI — the dialog
  and repository/provider already support a `note` param, it's just not in
  the form yet.
- Notifications/reminders for habits (e.g. "you haven't logged water today").
- Aggregate views — e.g. total time across all projects this month, or a
  streak-score summary across all habits — now that per-habit/per-project
  monthly data exists. This is where "archive of work done over the years"
  really starts to pay off.
- Home screen widget (Android) showing today's habits — a good use of native
  Kotlin/Compose glue if you want a truly native-feeling widget later.
