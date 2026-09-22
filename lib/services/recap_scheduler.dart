import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../data/settings_provider.dart';
import '../utils/recap_text.dart';
import 'notification_service.dart';

/// (Re)schedules the daily/weekly recap notifications from the current
/// [SettingsProvider] and [HabitProvider] state, or cancels whichever
/// one is turned off. Safe to call any time — e.g. once after the app
/// starts and habits have loaded, or right after a recap setting
/// changes in the Settings screen.
Future<void> rescheduleRecaps(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final habits = context.read<HabitProvider>();
  await NotificationService.instance.init();

  if (settings.dailyRecapEnabled) {
    await NotificationService.instance.scheduleDaily(
      hour: settings.dailyRecapHour,
      minute: settings.dailyRecapMinute,
      body: dailyRecapText(habits),
    );
  } else {
    await NotificationService.instance.cancelDaily();
  }

  if (settings.weeklyRecapEnabled) {
    await NotificationService.instance.scheduleWeekly(
      weekday: settings.weeklyRecapWeekday,
      hour: settings.weeklyRecapHour,
      minute: settings.weeklyRecapMinute,
      body: weeklyRecapText(habits),
    );
  } else {
    await NotificationService.instance.cancelWeekly();
  }
}
