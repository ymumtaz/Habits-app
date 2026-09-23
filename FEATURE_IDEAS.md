# Feature ideas — Habits App

A brainstorm of everything this app could grow into, organized by area. Not
a commitment to build any of it — a menu to pick from as you go. Each idea
has a rough effort tag: **S** (an evening), **M** (a weekend), **L**
(multi-session project of its own).

---

## 1. Habit types & scheduling

Right now a habit is boolean (done/not done) or a count/duration tracked
against a daily target, either daily or weekly. Real habits are often
richer than that:

- ✅ **Counter/quantity habits (M)** — Done: "read 30 pages," "drink 8
  glasses of water" tracked as a running count against a daily target.
  Polished further this round: a count habit can carry its own unit word
  (e.g. "pages", "glasses", "reps" — set from the "Unit (optional)" field
  when creating one; blank falls back to a generic "x"), the name field's
  placeholder example changes per type instead of always showing the
  boolean-habit example, the default daily target is 10 (was a flat 8
  shared with duration), and the habit card on the Habits page now shows
  today's progress (e.g. "13/30 pages") with a small progress bar, not
  just a checkbox.
- ✅ **Duration habits (M)** — Done: "meditate 15 min," "read 20 min"
  tracked against a daily target in minutes (default 15), same progress
  display on the habit card as count habits. A live timer tied into a
  duration habit (rather than logging a number after the fact) isn't
  built — that would mean closer integration with the Projects side's
  timer mechanics; not started.
- **Specific days of the week (S)** — "gym on Mon/Wed/Fri" instead of only
  "daily" or "N times/week." More faithful to how people actually schedule
  habits than a flat weekly count.
- ✅ **Tolerance for weekly habits (S)** — Done: the monthly tolerance
  ("streak freeze") that daily habits already had now also applies to
  "X times/week" habits, always counted in the same unit — days per
  month. A daily habit spends the budget on a literal missed day; a
  weekly habit spends it on a week's shortfall (target minus what was
  actually done). E.g. missing 2 days this month stays 2 days no matter
  which habit it comes from — not a whole tolerated week's worth.
- ✅ **Clearer habit-form wording (S)** — Done: "X times / week" (both on
  the add/edit habit screen and the default-frequency setting) is now
  just "Weekly," paired cleanly with "Daily" — the actual number is set
  separately via the "Target per week" slider that appears once Weekly
  is picked, so the segmented button label didn't need to carry it. Also
  restyled the add/edit habit form: the title field (renamed from "Name"
  to "Title") uses a larger font than the notes field below it, matching
  how the two are actually used — one's the main thing, one's optional
  detail.
- **Custom interval habits (M)** — "every 3 days," "every other week"
  (e.g. watering a plant, deep-cleaning something).
- **Vacation/skip days (M)** — mark a day as excused so it doesn't count
  against the streak — important once streak-breaking actually stings and
  you don't want an illness or trip to nuke a 60-day streak.
- **Habit checklists (L)** — a habit that's actually a short sequence
  ("morning routine: stretch, water, journal") completed as a set.

## 2. Streaks, scoring & motivation

- **Streak-freeze tokens (M)** — Duolingo-style: earn a limited number of
  "skip a day for free" tokens (e.g. one per week) so streaks survive an
  occasional miss without being trivially easy to maintain.
- ✅ **Milestone badges (S)** — Done: 7/30/100/365-day badges on the
  habit detail screen, filled in once `bestStreak` reaches that
  threshold. Permanent once earned — a badge doesn't dim again if the
  current streak later breaks.
- **Configurable streak-score formula (S)** — expose the weighting in
  `StreakCalculator` as a setting instead of a hardcoded constant, so you
  can tune what "streak score" rewards (recent consistency vs. all-time
  best).
- ✅ **Daily/weekly recap notification (M)** — Done: toggles in Settings
  → Notifications, each with its own time (and the weekly one, day of
  week). "You completed 4/5 habits today" / a weekly completions
  summary. Content is fixed at schedule time (Android can't query the
  database when a notification fires), so it's refreshed — same time,
  fresh text — whenever the app starts or a recap setting changes,
  rather than truly live at the moment it fires. Uses
  `flutter_local_notifications`; the very first time you turn one on,
  Android will prompt for the notification permission.
- ✅ **Shareable streak card (M)** — Done: a "Share streak" icon on a
  habit's detail screen renders a small branded card (streak, best
  streak, score) to an image and opens the normal Android share sheet.
  Fixed a bug where the share button silently did nothing: the render
  target was wrapped in `Offstage`, which skips *painting* its child
  entirely (not just hiding it), so the `RepaintBoundary` behind it
  had no layer to capture and `toImage()` failed — with no visible
  error, since the tap handler wasn't awaited. Now positioned off
  the edge of the screen instead (still painted, just not visible),
  with a loading state on the button and an error snackbar if a
  share ever fails.

## 3. Analytics & the "archive" angle

This is where the brief's "archive of work done over the years" really
pays off — the data model already supports all of it, it's a matter of
building views on top:

- ✅ **Yearly heatmap per habit (M)** — Done: a rolling 53-week
  contribution-style grid from the habit detail screen ("View yearly
  heatmap"), most-recent-week-first. Deliberately not anchored to Jan 1 —
  a calendar-year grid would look mostly empty for months after you start
  a habit, so it's a rolling window instead, full from day one.
- ✅ **Weekday pattern chart for count/duration habits (S)** — Done: a
  "By day of the week" column chart on the habit detail screen (count
  and duration habits only — a boolean habit is just done/not-done, so
  there's no amount to average), showing the average logged amount per
  weekday across the habit's whole history — e.g. "I read more on
  Saturdays." Averaged only over days that actually have a log, so a
  freshly-started habit isn't skewed by phantom zeros on weekdays you
  simply haven't reached yet. Hand-rolled (no charting package added),
  matching the yearly heatmap's approach of a small custom widget
  colored with the habit's own color.
- ✅ **Cross-habit dashboard (M)** — Done: a new "Insights" tab (Habits
  sub-tab) shows this month's overall completion rate and every habit
  ranked best-to-worst. A compact summary card also sits at the top of
  the Habits screen linking into it.
- ✅ **Cross-project time dashboard (M)** — Done: the Insights tab's
  Projects sub-tab shows total tracked time for week/month/year (a
  toggle), broken down by project as a ranked bar list.
- **"Year in review" screen (L)** — once you're a year in, a Spotify-
  Wrapped-style summary: total hours tracked, best streaks, most-worked
  project, etc. High payoff, but only worth it once there's real history.
  Not started.
- **Data export (S–M)** — CSV or JSON export of habit logs / time entries,
  so the archive isn't trapped in the app if you ever want to analyze it
  elsewhere (a spreadsheet, a script for that physics thesis-writing
  habit of yours). Not started.

## 4. Projects & time tracking

- ✅ **Notes on manual/live entries (S)** — Done: entries carry an optional
  note, editable from the session list.
- ✅ **Edit an existing entry (S)** — Done: tap a past session to fix its
  date/time/duration/note.
- ✅ **Project tags/categories (M)** — Done, upgraded from the original
  free-text version: categories are now a user-managed list (Settings
  → project's "manage categories" pencil icon) instead of typed text,
  seeded with Course/Research/Side project/Personal/Work. Add, rename,
  or delete your own; deleting one just clears that tag off any
  project that had it. Picked from a dropdown when creating/editing a
  project, shown as a chip on the card and detail screen.
- ✅ **Project status (S)** — Done: Ongoing / On hold / Completed,
  independent of archiving — a finished project can stay status
  "Completed" and visible in the normal list until you separately
  choose to archive it. Set from a segmented control on the
  create/edit screen or directly on the detail screen; filterable via
  chips at the top of the Projects list (drag-to-reorder is disabled
  while a status filter is active, since the persisted order spans all
  projects, not just the filtered ones).
- ✅ **Parent/child projects (M)** — Done: a project can optionally nest
  under one parent (e.g. "Chapter 1" under "Master's thesis") via a
  dropdown on the create/edit screen, restricted to projects that
  wouldn't create a cycle. A project's detail screen shows a "Part of
  X" chip linking up to its parent, and a "Sub-projects" section
  listing its children with each one's tracked time. Single parent
  only (a tree, not a general graph) — simplest model that covers the
  common case.
- ✅ **Weekly time goals per project (M)** — Done: an optional weekly hour
  goal per project, with a progress bar on the detail screen. (Monthly
  goals weren't added — the schema only supports a weekly figure for now.)
- ✅ **Pause/resume sessions (S)** — Done (not originally on this list, but
  came up directly): a project session can now be begun, paused, resumed,
  and ended & recorded, instead of only start/stop. Paused time doesn't
  count toward the recorded duration.
- ✅ **Idle detection (L)** — Done, scoped down from the original idea:
  if a project timer is left running while the app sits in the
  background for 15+ minutes, returning to the app prompts "Still
  working?" with the option to trim that away-time off the recorded
  session (or keep it as-is). Pure Flutter app-lifecycle handling, no
  native platform code — doesn't require the phone to be unlocked or
  the app foregrounded to detect the gap, just backgrounded.
- ✅ **Sub-tasks within a project (L)** — Done, then generalized: an
  optional checklist under each project (add / check off / swipe to
  delete). It's organizational only — a task doesn't carry its own
  tracked time, time tracking stays at the project level.
- ✅ **Standalone to-do list (M)** — Done, relocated twice based on
  feedback: first shipped as its own "To-dos" bottom-nav tab, then folded
  directly into the Habits page below the summary card — which felt
  "intimidating" sitting there by default — and now lives behind a
  checklist icon in the Habits app bar instead, opening a dedicated
  To-dos page. The icon carries a small badge with the count of
  unchecked to-dos, so what's pending is visible without opening the
  page. Each to-do can optionally carry a due date (tap the calendar
  icon on a to-do; long-press it to clear the date); dated ones sort
  soonest-first, undated ones follow. A to-do due on a future date is
  tucked behind a collapsed "Tasks for later (N)" row instead of
  cluttering the main list — tap to expand and see what's coming up.
  Under the hood this is the same underlying `Task` as a project's
  checklist item, just with no project attached and an optional due
  date — one model, one widget (`TaskChecklist`), reused on this page,
  rather than a second parallel to-do system. The app-bar badge itself
  was refined further: it now counts only to-dos actually due *today*
  (not the full pending total), so an empty badge really does mean
  "nothing on for today," not just "nothing due-or-overdue."
- **Calendar view of tracked time (M)** — see which project you worked on
  each day, at a glance, across projects. Not started.
- ✅ **Visual parent/child indentation on the Projects list (S)** — Done:
  a child project now renders directly under its parent, indented, so
  the relationship reads at a glance instead of relying on a small "Part
  of X" caption. Applies to both the main reorderable list and any
  status-filtered view (a project whose parent got filtered out just
  falls back to top-level for display). Drag-to-reorder still works
  against this grouped order.

## 5. App-wide / quality-of-life

- ✅ **App icon (S)** — Done: the provided chain-link logo
  (`assets/icon/app_icon.png`) is now wired up as the Android launcher
  icon via `flutter_launcher_icons`. Run `flutter pub get` then
  `dart run flutter_launcher_icons` to generate it into
  `android/app/src/main/res/`.
- ✅ **Undo toast on delete (S)** — Done, for the frequent small deletes
  (a single habit log, a time entry): a Snackbar with "Undo" appears for a
  few seconds after the confirm dialog. Whole-habit/whole-project deletion
  still relies on the confirm dialog alone — restoring an entire deleted
  habit plus its full log history was judged too easy to get subtly wrong
  to add blind, so it was left as the existing one-way (but confirmed)
  delete.
- ✅ **Reorder habits/projects (S)** — Done: long-press and drag on either
  list screen; order is saved.
- ✅ **Unarchive UI (S)** — Done: Settings → Archived lists archived
  habits and projects with an "Unarchive" action, plus a separate
  "delete permanently" option for actually clearing one out for good.
- ✅ **Settings screen (M)** — Done: covers 12h/24h time, first day of the
  week, default habit frequency, and the recap notification schedule,
  alongside the theme picker. Manual dark-mode override is covered by
  the theme picker (System/Light/Dark, plus a few fixed themes).
- ✅ **First day of week setting (S)** — Done: Monday or Sunday, in
  Settings → Week. Feeds `StreakCalculator`'s and `ProjectProvider`'s
  week-boundary math (weekly habit streaks, weekly time goals, and
  Insights' "this week" figures) via a small shared `WeekConfig`
  default rather than threading the setting through every call site —
  reasonable for one global preference used in a personal app. Covered
  by new tests confirming a Sunday-start week groups dates differently
  than the Monday default.
- ✅ **Local backup/restore (M)** — Done: Settings → Backup & restore.
  Export copies the live SQLite file and opens the normal Android share
  sheet, so you choose where it lands (Google Drive, email, "Save to
  device", ...). Restore picks a file via the system file picker,
  sanity-checks it actually looks like a habits-app backup (not just
  any file), confirms with an explicit warning since it's destructive,
  then overwrites the live database and reloads. Uses the new
  `file_picker` package — like the other Android-facing pieces built
  in this environment, this one is a strong first draft that hasn't
  been run on-device yet, so give both the export and restore paths a
  real test before trusting them with your only copy of the data.
- **Android home-screen widgets (L)** — Reverted. A first pass (a habit
  progress widget + a monthly grid widget, via the `home_widget`
  package) was built and got the app compiling, but the widgets
  themselves didn't work correctly on-device and the app was crashing,
  so the `home_widget` dependency, the Dart sync service, the two
  Kotlin `AppWidgetProvider`s, their layouts/XML, and the manifest
  entries were all pulled back out rather than debugged blind. Worth
  revisiting as its own focused pass — probably starting from a minimal
  single-widget proof of concept rather than two widgets at once — once
  there's a way to actually build and inspect it step by step (e.g. via
  Android Studio directly, with `adb logcat` open) instead of iterating
  blind through a chat.
- **App lock (M)** — PIN or fingerprint lock, since this is personal
  tracking data (workouts, study habits, hours worked). Not started.
- **Turkish localization (M)** — `flutter_localizations` + an `.arb` file;
  worth it if this is meant for daily use rather than just English
  practice. Not started.

## 6. Multi-person / shared use

The brief says "we," which the current single-profile local database
doesn't really account for:

- **Per-entry "who did this" tag (S–M)** — simplest option: no real
  accounts, just an optional tag on each habit/log ("Mümtaz" / partner's
  name) so one install can track both of you without a backend.
- **Separate local profiles (M)** — switch between two local profiles
  (essentially two separate databases) on the same device — still no
  backend, but cleaner separation than tagging.
- **Real multi-device sync (L, and a real architecture decision)** — this
  is the point where "local-only" stops being enough: it needs a backend
  (Firebase is the fastest path, or a custom API). Worth a deliberate
  conversation before starting, not a bolt-on — it touches almost every
  repository/provider in the app.

## 7. Reliability & dev practice

- **CI on GitHub Actions (S)** — run `flutter analyze` + `flutter test` on
  every push, so a broken build/test is caught before it reaches your
  phone. Cheap now, saves real time later.
- **More unit tests as features land (ongoing)** — same philosophy as
  `streak_calculator_test.dart`: any pure-logic module (a new counter-
  habit calculator, a time-goal progress calculator) is worth testing the
  same way.
- **Automatic periodic local backup (M)** — belt-and-suspenders version of
  the manual backup/restore idea above — snapshot the DB on a schedule so
  a corrupted install doesn't lose years of data.

---

## If you want a starting point

Done so far (see the ✅ items above for details): habit types
(count/duration) + monthly tolerance (now day-based for both daily and
weekly habits), project notes/tags/editable entries/weekly goals/optional
task checklists, pause/resume sessions, idle detection, a theme picker
(including a custom Navy & Teal theme) and app icon, undo-on-delete for
logs and sessions, drag-to-reorder, a Settings screen (time format, first
day of week, default habit frequency, recap notifications), a yearly
heatmap per habit, cross-habit/cross-project dashboards (the "Insights"
tab), a shareable streak card, daily/weekly recap notifications, milestone
badges, unarchive UI, and local backup/restore.

The Android home-screen widgets were attempted and then reverted (see the
note above) — not currently part of the app.

Next, roughly in order of "cheapest and most immediately useful":

1. Local backup/restore (cheap insurance for an app meant to hold years of
   data).
2. Data export (CSV/JSON) — same underlying need as backup/restore, so
   worth building around the same time.
3. "Year in review" screen, once there's a real year of history to
   summarize.
4. In-progress-timer notification (a persistent "tracking time on X"
   notification while a session runs).
5. Revisit the Android home-screen widgets, scoped smaller and built with
   a tighter compile/inspect loop than a chat can offer.

The in-progress-timer notification was left out of this pass since a
*persistent* (non-dismissible, always up-to-date) notification needs a
foreground service, which is a heavier, more failure-prone piece of
native Android than the recap notifications or the widgets — worth its
own focused pass rather than bundling it in.
