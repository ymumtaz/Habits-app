import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../services/recap_scheduler.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'archived_screen.dart';
import 'backup_screen.dart';
import 'manage_session_tags_screen.dart';

/// App-wide settings: appearance (theme), language, time format, first
/// day of the week, default habit frequency, and the daily/weekly
/// recap notification schedule.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();
    final t = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(t.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(t.sectionAppearance),
          for (final option in AppThemeOption.values)
            RadioListTile<AppThemeOption>(
              value: option,
              groupValue: themeProvider.option,
              onChanged: (value) {
                if (value != null) themeProvider.setOption(value);
              },
              title: Text(option.label(t)),
              secondary: CircleAvatar(
                backgroundColor: option.swatch,
                radius: 14,
              ),
            ),
          const Divider(height: 32),
          _SectionHeader(t.sectionLanguage),
          RadioListTile<String>(
            value: 'en',
            groupValue: settings.languageCode,
            onChanged: (v) {
              if (v != null) settings.setLanguageCode(v);
            },
            title: Text(t.languageEnglish),
          ),
          RadioListTile<String>(
            value: 'tr',
            groupValue: settings.languageCode,
            onChanged: (v) {
              if (v != null) settings.setLanguageCode(v);
            },
            title: Text(t.languageTurkish),
          ),
          const Divider(height: 32),
          _SectionHeader(t.sectionTimeFormat),
          SwitchListTile(
            title: Text(t.use24HourTime),
            subtitle: Text(settings.use24HourTime ? '14:30' : '2:30 PM'),
            value: settings.use24HourTime,
            onChanged: settings.setUse24HourTime,
          ),
          const Divider(height: 32),
          _SectionHeader(t.sectionWeek),
          ListTile(
            title: Text(t.firstDayOfWeek),
            subtitle: Text(t.firstDayOfWeekSubtitle),
          ),
          RadioListTile<int>(
            value: DateTime.monday,
            groupValue: settings.firstDayOfWeek,
            onChanged: (v) {
              if (v != null) settings.setFirstDayOfWeek(v);
            },
            title: Text(t.weekdayName(DateTime.monday)),
          ),
          RadioListTile<int>(
            value: DateTime.sunday,
            groupValue: settings.firstDayOfWeek,
            onChanged: (v) {
              if (v != null) settings.setFirstDayOfWeek(v);
            },
            title: Text(t.weekdayName(DateTime.sunday)),
          ),
          const Divider(height: 32),
          _SectionHeader(t.sectionSessions),
          ListTile(
            title: Text(t.defaultSessionLength),
            subtitle: Text(t.defaultSessionLengthSubtitle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => settings.setDefaultCountdownMinutes(
                    settings.defaultCountdownMinutes - 5,
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    '${settings.defaultCountdownMinutes} ${t.minutesAbbrev}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => settings.setDefaultCountdownMinutes(
                    settings.defaultCountdownMinutes + 5,
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: Text(t.sessionTags),
            subtitle: Text(t.sessionTagsSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManageSessionTagsScreen()),
            ),
          ),
          const Divider(height: 32),
          _SectionHeader(t.sectionNotifications),
          SwitchListTile(
            title: Text(t.dailyRecap),
            subtitle: Text(
              settings.dailyRecapEnabled
                  ? t.dailyRecapEnabledSubtitle(
                      _formatTime(t, settings.dailyRecapHour, settings.dailyRecapMinute))
                  : t.dailyRecapDisabledSubtitle,
            ),
            value: settings.dailyRecapEnabled,
            onChanged: (value) async {
              await settings.setDailyRecapEnabled(value);
              if (value) await NotificationService.instance.requestPermission();
              if (context.mounted) await rescheduleRecaps(context);
            },
          ),
          if (settings.dailyRecapEnabled)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              title: Text(t.time),
              trailing: Text(
                _formatTime(t, settings.dailyRecapHour, settings.dailyRecapMinute),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: settings.dailyRecapHour,
                    minute: settings.dailyRecapMinute,
                  ),
                );
                if (picked == null) return;
                await settings.setDailyRecapTime(picked.hour, picked.minute);
                if (context.mounted) await rescheduleRecaps(context);
              },
            ),
          SwitchListTile(
            title: Text(t.weeklyRecap),
            subtitle: Text(
              settings.weeklyRecapEnabled
                  ? t.weeklyRecapEnabledSubtitle(
                      t.weekdayName(settings.weeklyRecapWeekday),
                      _formatTime(
                          t, settings.weeklyRecapHour, settings.weeklyRecapMinute),
                    )
                  : t.weeklyRecapDisabledSubtitle,
            ),
            value: settings.weeklyRecapEnabled,
            onChanged: (value) async {
              await settings.setWeeklyRecapEnabled(value);
              if (value) await NotificationService.instance.requestPermission();
              if (context.mounted) await rescheduleRecaps(context);
            },
          ),
          if (settings.weeklyRecapEnabled) ...[
            ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              title: Text(t.day),
              trailing: DropdownButton<int>(
                value: settings.weeklyRecapWeekday,
                items: [
                  for (final weekday in [
                    DateTime.monday,
                    DateTime.tuesday,
                    DateTime.wednesday,
                    DateTime.thursday,
                    DateTime.friday,
                    DateTime.saturday,
                    DateTime.sunday,
                  ])
                    DropdownMenuItem(
                        value: weekday, child: Text(t.weekdayName(weekday))),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  await settings.setWeeklyRecapTime(
                    v,
                    settings.weeklyRecapHour,
                    settings.weeklyRecapMinute,
                  );
                  if (context.mounted) await rescheduleRecaps(context);
                },
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              title: Text(t.time),
              trailing: Text(
                _formatTime(
                    t, settings.weeklyRecapHour, settings.weeklyRecapMinute),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: settings.weeklyRecapHour,
                    minute: settings.weeklyRecapMinute,
                  ),
                );
                if (picked == null) return;
                await settings.setWeeklyRecapTime(
                  settings.weeklyRecapWeekday,
                  picked.hour,
                  picked.minute,
                );
                if (context.mounted) await rescheduleRecaps(context);
              },
            ),
          ],
          const Divider(height: 32),
          _SectionHeader(t.sectionNewHabits),
          ListTile(
            title: Text(t.defaultFrequency),
            subtitle: Text(t.defaultFrequencySubtitle),
          ),
          RadioListTile<HabitFrequency>(
            value: HabitFrequency.daily,
            groupValue: settings.defaultHabitFrequency,
            onChanged: (v) {
              if (v != null) settings.setDefaultHabitFrequency(v);
            },
            title: Text(t.frequencyDaily),
          ),
          RadioListTile<HabitFrequency>(
            value: HabitFrequency.weekly,
            groupValue: settings.defaultHabitFrequency,
            onChanged: (v) {
              if (v != null) settings.setDefaultHabitFrequency(v);
            },
            title: Text(t.frequencyWeekly),
          ),
          const Divider(height: 32),
          _SectionHeader(t.sectionData),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(t.archived),
            subtitle: Text(t.archivedSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ArchivedScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(t.backupRestore),
            subtitle: Text(t.backupRestoreSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(AppLocalizations t, int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final period = hour < 12 ? t.am : t.pm;
  final m = minute.toString().padLeft(2, '0');
  return '$h:$m $period';
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
