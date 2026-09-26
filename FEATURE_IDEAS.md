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
- ✅ **Cross-habit dashboard (M)** — Done, then redesigned based on
  feedback that the ranked-list version "wasn't looking good" and
  duplicated what the habit detail page already showed better: the
  Insights → Habits tab is no longer a ranked list — it's a
  dropdown habit switcher followed by that one habit's own stats,
  gathered from its detail page (current/best streak, streak score,
  this month's completion, a "Last 7 days" strip, and — for
  count/duration habits — the "by day of the week" chart), plus an
  "Open full habit page" shortcut. Pick any habit from the dropdown
  to flip its stats in place, rather than scrolling a list or
  leaving Insights.
- ✅ **Cross-project time dashboard (M)** — Done, then redesigned the
  same way as the habits tab: Insights → Projects is now a dropdown
  project switcher, a week/month/year toggle that scopes the "Total
  tracked" figure to whichever project is selected (it used to total
  across every project regardless of which one you were looking at),
  "This week"/"This month" stats, a per-project "Last 7 days" bar
  strip, and a per-project "This month" bubble calendar — the same
  pieces shown on that project's own detail page, put together in
  one switchable view, plus an "Open full project page" shortcut.
  The earlier all-projects-at-once stacked column chart and ranked
  bar list were dropped in favor of this per-project view.
- ✅ **Insights switcher: arrows *and* a dropdown, monthly chart for
  habits too (S)** — Done: the "‹ name ›" switcher on both Insights
  tabs now also opens a dropdown of every habit/project when you tap
  the name itself (a small chevron hints at it) — same look otherwise,
  just a faster way to jump straight to one instead of stepping
  through with the arrows. The Habits tab's "By day of the week" chart
  was dropped from Insights (it's still on each habit's own detail
  page) in favor of a "This month" bubble calendar matching what the
  Projects tab already had, so both tabs now show the same last-7-days
  strip + monthly calendar shape.
  Separately, the monthly bubble calendar itself (used here and on
  each habit/project detail page) was redesigned based on feedback
  that it "didn't even display the days of the month" like the
  Google Fit reference it's modeled on: every cell now always shows
  its day number (white, bold, centered inside the filled circle for
  a day with time logged; plain muted number with no circle at all
  for a zero day — dropped the old hollow-ring treatment), and a
  "Weekly totals" list now sits below the grid, breaking the month
  down by calendar week the way Google Fit's monthly view does.
  Fixed once more based on feedback that a boundary week showed a
  truncated range like "Sep 28 – 30" instead of a real Monday–Sunday
  week: the widget now has a `gridRange()` helper describing the full
  calendar-week span it renders (padding a few days into the
  neighboring month when the 1st doesn't land on the week's first
  day), and callers fetch duration data across that whole range —
  not just the target month — so every weekly-totals row shows and
  sums a genuine full week, including the days that spill into the
  next or previous month.
- ✅ **Session journal — notes, tags, and a harder-to-fumble "end
  session" (M)** — Feedback that ending a session was a single
  instant tap, easy to trigger by accident and record a 2-second
  session in a blink, and that a session should work more like a gym
  log: a note on how it went, and a way to say what it was about.
  - A session's existing (previously under-used) `note` field is now
    a real short journal entry — labeled "Notes" everywhere it's
    edited, hinted with "How did it go? What did you do? What's
    next?" — rather than a one-line "what did you work on?" caption.
  - **Session tags (S)** — a new, separate-from-project-categories
    tag vocabulary (e.g. "Physics", "Majorana", "Coding", "Studying",
    "Reading", "Literature review" — seeded as defaults, freely
    add/rename/delete your own from Settings > Session tags, same
    add/rename/delete pattern as project categories). A session can
    carry several tags at once (many-to-many), picked from a chip
    grid with an inline "add a new tag" field (`TagPicker`, shared
    across every place tags are edited) — no need to leave the dialog
    to define a new one on the spot. Tags now render as `#tag` chips
    everywhere they're shown (the picker's own chips, the session
    list on a project's detail page, the manage-tags screen) so
    they read unambiguously as tags rather than plain words — the
    hashtag prefix is purely cosmetic, stored tag names don't carry
    it themselves.
  - **A real "End session" step (S)** — tapping "End & record"
    (whether from a project's own detail page or the active-session
    banner on the Projects list) no longer stops and records the
    timer instantly. It opens a dialog showing the elapsed duration
    (as editable hours/minutes fields — see below), the notes field,
    and the tag picker; nothing is recorded until "Record" is tapped,
    and "Cancel" leaves the session running/paused exactly as it was.
    A session under a minute at the moment the dialog opens gets a
    small flagged hint ("only a few seconds — adjust the duration
    above if that's not right") without blocking anything.
  - ✅ **Cancel an in-progress session (S)** — Done: alongside pause/
    resume/end, a running or paused session can now be cancelled
    outright — discarded with nothing recorded, rather than the only
    way out being to end it (which always saved something, even a
    near-zero duration). Available from both the active-session
    banner on the Projects list and the project's own detail page,
    behind its own confirm dialog so it isn't one accidental tap away
    from losing tracked time.
  - **Editable duration when ending (S)** — the same dialog's
    hours/minutes fields aren't just a display: forgot to end a
    session hours ago? Lower the duration before recording and only
    the time you actually worked gets saved. Implemented by folding
    the difference into the entry's existing `paused_seconds`
    bookkeeping (the same mechanism pause/resume already uses)
    instead of rewriting `started_at`, so the entry's true start time
    is preserved even after a correction.
  - Logging a past session by hand, and editing an already-recorded
    one (`add_manual_entry_dialog.dart`, used for both), gained the
    same notes-hint wording and the same tag picker, pre-filled with
    that entry's current tags when editing.
  - The sessions list on a project's detail page now shows each
    entry's tags as small chips under its note. Deleting a session
    (with Undo) and restoring it now carries its tags along too,
    rather than silently losing them.
  - Schema bump to version 10: new `session_tags` and
    `time_entry_tags` (many-to-many join) tables.
- ✅ **Last-7-days habit overview (S)** — Done, then relocated and
  split based on feedback: the aggregate bar strip (one bar per day,
  today and the six days before it, showing what percentage of active
  habits were completed) no longer lives on the Habits main page — it
  moved into Insights → Habits, at the top of that tab, since the main
  page is for quick daily action, not a dashboard. In its place, each
  individual habit's own detail page now has its own "Last 7 days"
  strip showing that specific habit's actual daily values (done/not
  done for boolean habits; the amount logged for count/duration
  habits) — a different, more useful view than the aggregate one,
  and shown for every habit type (unlike the weekday-average chart,
  which only applies to count/duration habits). Also fixed a 2px
  render-overflow ("bottom overflowed by 2.0 pixels") in the shared
  bar-strip widget these charts are built on — a `SizedBox` wrapper
  was sized a couple pixels shorter than its content.
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
- ✅ **One "Start session" flow instead of per-card timers (M)** — Done,
  redesigned based on feedback that a play/pause/stop button on every
  row of the Projects list "felt like a stopwatch" rather than a study
  log. The list is now a plain summary (name, tags, total time); there
  is a single "Start a session" entry point (a button on the Projects
  screen, or "Begin session" on a project's own detail page) that asks
  which project and how to time it — a countdown (default 25 minutes,
  adjustable in 5-minute steps, Pomodoro-style) or the original
  open-ended count-up timer. While one is active, a banner at the top
  of the Projects list (or the detail page, if you're on it) shows the
  running project, remaining/elapsed time, and pause/end controls —
  one place to manage the one session that can ever be active, instead
  of controls duplicated on every card. Each start is still its own
  separate session/log, same as before.
- ✅ **Per-project weekly/monthly time overview (S)** — Done: a
  project's detail page now shows "This week" / "This month" totals
  plus two small charts underneath — a 7-day bar strip (this
  project's minutes per day, last 7 days) and a monthly bubble
  calendar (same Google-Fit-style circles as the Insights view, but
  scoped to just this one project, tinted in its own color).
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
  "nothing on for today," not just "nothing due-or-overdue." Renamed
  from "To-dos" to "Tasks" throughout (page title, app-bar tooltip,
  the checklist's own heading and add-row hint) — same feature, just
  clearer wording.
- **Calendar view of tracked time (M)** — see which project you worked on
  each day, at a glance, across projects. Not started.
- ✅ **Visual parent/child indentation on the Projects list (S)** — Done:
  a child project now renders directly under its parent, indented, so
  the relationship reads at a glance instead of relying on a small "Part
  of X" caption. Applies to both the main reorderable list and any
  status-filtered view (a project whose parent got filtered out just
  falls back to top-level for display). Drag-to-reorder still works
  against this grouped order.
- **Clearer parent/child relationship, round 2 (S)** — Feedback that
  indentation alone still "felt like a stopwatch"-style flat list, not
  a real hierarchy. Five options were offered; tried in order:
  - ❌ **Branch connector icon** — Tried alongside color inheritance,
    then reverted on feedback ("didn't like it"): a small "↳" icon in
    front of a child's name. Not brought back.
  - ✅ **Parent-color inheritance (S)** — Reconsidered after the
    grouped card and collapsible groups landed: a new sub-project's
    color now defaults to a lightened tint of its parent's (shown as
    "Suggested from parent" next to a swatch preview, overridable by
    picking your own color as always). Only applies to new projects,
    and only before the color picker has been touched — editing an
    existing project's parent never silently recolors it.
  - ✅ **Grouped card (S)** — Done, current approach: a parent and all
    its children are now drawn as one shared rounded container
    (tinted with the top-level project's own color, a thin colored
    border, a divider between rows) instead of separate individual
    cards — so the family reads as one visual unit on the Projects
    list. A project with no children still renders as its own plain
    card, unchanged. Drag-to-reorder still works per-row underneath.
  - ✅ **Collapsible parent groups (S)** — Done, layered on top of the
    grouped card above: a family-root row now has an expand/collapse
    chevron in place of the usual "tap to open" arrow. Collapsing a
    parent hides its children (and grandchildren) entirely and
    appends a rolled-up summary to the parent's own row — "N
    sub-projects · Xh Ym more" — computed recursively so nested
    sub-projects are still counted even though only the top row
    shows. Tapping the row itself (not the chevron) still opens the
    project as normal; collapse state is a plain in-memory UI toggle,
    not persisted. Drag-to-reorder is unaffected — collapsed children
    stay in the list as zero-height placeholders rather than being
    filtered out, so drag indices never need remapping.
- **Status-hinting project icon (S)** — Feedback that the same folder
  icon on every project row didn't communicate anything.
  - ❌ **Swap the icon itself** — First tried: the avatar's whole icon
    swapped based on `ProjectStatus` (folder/pause-circle/check-circle).
    Rejected on feedback ("didn't like it").
  - ✅ **Category icon + status badge overlay (S)** — Current approach,
    replacing the swap above entirely: a `ProjectCategory` now carries
    its own icon, chosen from a wide picker (~35 icons) shown when
    creating *or* editing a category from Settings > Project
    categories. A project's avatar shows its category's icon (falling
    back to a generic folder when it has none) instead of a
    status-derived one, with a small round badge layered in the
    avatar's corner hinting at status instead — a play triangle for
    ongoing, a pause for on hold, a check for completed. A
    running/paused session gets its own highlight — a colored ring
    around the whole avatar — layered on top of that, rather than
    overriding the icon outright. New shared `ProjectAvatar` widget
    (`widgets/project_card.dart`) draws this everywhere a project's
    avatar shows: the main Projects list, a project's own
    "Sub-projects" section, and (as icons, not the avatar) the "Type"
    dropdown on the add/edit project screen now shows each category's
    icon next to its name. Schema bump to version 9
    (`project_categories.icon_code_point`); the five seeded default
    categories (Course, Research, Side project, Personal, Work) got a
    matching icon backfilled automatically for existing installs.
  - ✅ **Decluttered the project card (S)** — Done, once the icon/badge
    above already carried category and status: the category-name text
    chip and the on-hold/completed status-label chip were dropped from
    each row on the Projects list, since the avatar's icon and small
    status badge already say the same thing without spelling it out
    in words too.
- ✅ **A session in progress notification (S)** — Done: while a timer is
  running (or paused), a persistent system notification shows the
  project name and a live minute:second clock, using Android's own
  notification chronometer (`usesChronometer`) so the count ticks
  forward on its own without the app reposting it every second or
  needing a foreground service. Frozen (not ticking) while paused, and
  cancelled once nothing is active. Best-effort — a notification-plugin
  hiccup never takes down the app itself.
- ✅ **A parent project's totals include its sub-projects' time (M)** —
  Done: "a child is a sub-project of a main project at the end of the
  day" — a parent's total/weekly/monthly/last-7-days/monthly-calendar
  figures now fold in every descendant's tracked time automatically,
  not just what was logged directly on the parent itself. The one
  app-wide grand total (used by the cross-project daily/monthly
  totals) deliberately stays a plain per-project sum so nesting
  projects under a parent never inflates that figure by double-counting
  a child's time under both itself and its parent. The collapsed
  family-row summary on the Projects list ("N sub-projects") dropped
  its "· Xh more" suffix, since the parent row's own total already
  includes that time now — the suffix would have implied *extra* time
  beyond what's shown.
- ✅ **Fixed: losing the "suggested from parent" color after a misclick
  (S)** — Done: previously, tapping any other swatch by mistake on the
  add/edit project screen permanently hid the parent-tint suggestion
  for that session (it was gated on a one-way "have you touched a
  swatch yet" flag). The suggested tint is now its own selectable
  swatch (marked with a small star) that stays available in the color
  picker for as long as a parent is set, so it can always be tapped
  back to, misclick or not.
- ✅ **Move a project to a different parent from the Projects list (S)**
  — Done, after evaluating true drag-and-drop: a small "move" icon on
  each project card opens a bottom sheet to pick a new parent (or
  "No parent" to make it top-level) in one tap. A real long-press-drag-
  onto-another-project gesture was considered first, but the list
  already uses long-press-drag for its own drag-to-reorder — layering
  a second "drop onto a project" gesture on the exact same long-press-
  drag on the exact same rows would fight that existing, working
  interaction rather than complementing it, with no reliable way to
  test the result here. This gets to the same outcome (re-parent a
  project without opening its full edit screen) without touching that
  gesture at all.
- ✅ **A short title for each session (S)** — Done: "each study session
  is like a post" — ending a session (or logging/editing one manually)
  now asks for a short required title first, shown as the session's
  main line wherever sessions are listed (the notes field, still
  optional, is the body underneath). Schema bump to version 11
  (`time_entries.title`); sessions recorded before this update just
  show their timestamp as before, exactly as they did previously.

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
  the theme picker (System/Light/Dark, plus a few fixed themes). A
  "Sessions" section was added this round: a default countdown length
  (5-minute steps, same range as the dialog itself) that pre-fills the
  "Start a session" dialog's countdown field — still freely adjustable
  per session, just a different starting point than the old hardcoded
  25 minutes.
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
- ✅ **Turkish localization (M)** — Done: the whole app, not just a
  language setting, translates into Turkish. Settings → Language offers
  English/Turkish; the choice is threaded through a hand-written
  `AppLocalizations` (no codegen — a plain Dart class with one
  getter/method per string, `context.l10n` accessor), used across every
  screen, widget, notification, and even the Android home-screen-widget
  and background-notification code paths that run without a
  `BuildContext` (they read the saved language straight from
  `SharedPreferences`). Dates (`DateFormat`) pick up the active locale
  everywhere too, and grammatically sensitive strings (durations, "N of
  M this week," overdue-task labels) are built as whole sentences per
  language rather than concatenated fragments, to avoid Turkish
  word-order/agreement issues. A couple of things were deliberately left
  in English on both languages: the app's own name/brand ("Habits") and
  the two native Android widget-provider class names, which aren't
  user-facing text.

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
badges, unarchive UI, local backup/restore, a cancel option for an
in-progress session, hashtag-styled session tags, a full Turkish
translation of the app (Settings → Language), a persistent
session-in-progress notification, parent-inclusive project time
totals, and a required session title.

The Android home-screen widgets were attempted and then reverted (see the
note above) — not currently part of the app.

Next, roughly in order of "cheapest and most immediately useful":

1. Local backup/restore (cheap insurance for an app meant to hold years of
   data).
2. Data export (CSV/JSON) — same underlying need as backup/restore, so
   worth building around the same time.
3. "Year in review" screen, once there's a real year of history to
   summarize.
4. Revisit the Android home-screen widgets, scoped smaller and built with
   a tighter compile/inspect loop than a chat can offer.

The in-progress-timer notification (previously listed here as not
started) is now done — see the "A session in progress notification"
item above. It turned out not to need a foreground service after all:
Android's own notification chronometer field ticks the displayed time
forward on its own once the notification is posted, so a plain posted
system notification was enough.
