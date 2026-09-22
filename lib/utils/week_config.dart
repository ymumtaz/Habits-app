/// The user's global "first day of the week" preference — either
/// `DateTime.monday` or `DateTime.sunday` — used by [StreakCalculator]
/// and [ProjectProvider]'s week-boundary math (streaks, weekly time
/// goals, and the Insights "this week" figures).
///
/// Kept as a small static default rather than threaded as a parameter
/// through every call site: it's one global user setting, not
/// something that varies per call. [SettingsProvider] updates it
/// whenever the user changes their preference (and on app startup,
/// from whatever was last saved), so it's always in sync with what's
/// shown in Settings.
class WeekConfig {
  WeekConfig._();

  static int firstWeekday = DateTime.monday;
}
