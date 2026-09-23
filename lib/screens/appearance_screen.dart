import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_provider.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../services/recap_scheduler.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'archived_screen.dart';
import 'backup_screen.dart';

const _weekdayNames = {
  DateTime.monday: 'Monday',
  DateTime.tuesday: 'Tuesday',
  DateTime.wednesday: 'Wednesday',
  DateTime.thursday: 'Thursday',
  DateTime.friday: 'Friday',
  DateTime.saturday: 'Saturday',
  DateTime.sunday: 'Sunday',
};

/// App-wide settings: appearance (theme), time format, first day of
/// the week, default habit frequency, and the daily/weekly recap
/// notification schedule.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('Appearance'),
          for (final option in AppThemeOption.values)
            RadioListTile<AppThemeOption>(
              value: option,
              groupValue: themeProvider.option,
              onChanged: (value) {
                if (value != null) themeProvider.setOption(value);
              },
              title: Text(option.label),
              secondary: CircleAvatar(
                backgroundColor: option.swatch,
                radius: 14,
              ),
            ),
          const Divider(height: 32),
          const _SectionHeader('Time format'),
          SwitchListTile(
            title: const Text('Use 24-hour time'),
            subtitle: Text(settings.use24HourTime ? '14:30' : '2:30 PM'),
            value: settings.use24HourTime,
            onChanged: settings.setUse24HourTime,
          ),
          const Divider(height: 32),
          const _SectionHeader('Week'),
          ListTile(
            title: const Text('First day of the week'),
            subtitle: const Text(
              'Sets the week boundary used for weekly habit streaks, '
              'weekly time goals, and "this week" figures in Insights.',
            ),
          ),
          RadioListTile<int>(
            value: DateTime.monday,
            groupValue: settings.firstDayOfWeek,
            onChanged: (v) {
              if (v != null) settings.setFirstDayOfWeek(v);
            },
            title: const Text('Monday'),
          ),
          RadioListTile<int>(
            value: DateTime.sunday,
            groupValue: settings.firstDayOfWeek,
            onChanged: (v) {
              if (v != null) settings.setFirstDayOfWeek(v);
            },
            title: const Text('Sunday'),
          ),
          const Divider(height: 32),
          const _SectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Daily recap'),
            subtitle: Text(
              settings.dailyRecapEnabled
                  ? 'Reminds you at ${_formatTime(settings.dailyRecapHour, settings.dailyRecapMinute)}'
                  : 'A nightly nudge with how many habits you completed today',
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
              title: const Text('Time'),
              trailing: Text(
                _formatTime(settings.dailyRecapHour, settings.dailyRecapMinute),
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
            title: const Text('Weekly recap'),
            subtitle: Text(
              settings.weeklyRecapEnabled
                  ? 'Reminds you ${_weekdayNames[settings.weeklyRecapWeekday]} '
                      'at ${_formatTime(settings.weeklyRecapHour, settings.weeklyRecapMinute)}'
                  : 'A weekly nudge summarizing the past 7 days',
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
              title: const Text('Day'),
              trailing: DropdownButton<int>(
                value: settings.weeklyRecapWeekday,
                items: [
                  for (final entry in _weekdayNames.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
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
              title: const Text('Time'),
              trailing: Text(
                _formatTime(
                    settings.weeklyRecapHour, settings.weeklyRecapMinute),
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
          const _SectionHeader('New habits'),
          ListTile(
            title: const Text('Default frequency'),
            subtitle: const Text('Used to pre-fill the "Add habit" screen'),
          ),
          RadioListTile<HabitFrequency>(
            value: HabitFrequency.daily,
            groupValue: settings.defaultHabitFrequency,
            onChanged: (v) {
              if (v != null) settings.setDefaultHabitFrequency(v);
            },
            title: const Text('Daily'),
          ),
          RadioListTile<HabitFrequency>(
            value: HabitFrequency.weekly,
            groupValue: settings.defaultHabitFrequency,
            onChanged: (v) {
              if (v != null) settings.setDefaultHabitFrequency(v);
            },
            title: const Text('Weekly'),
          ),
          const Divider(height: 32),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Archived'),
            subtitle: const Text('View, restore, or permanently delete '
                'archived habits and projects'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ArchivedScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & restore'),
            subtitle: const Text('Export everything to a file, or restore '
                'from a previous export'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final period = hour < 12 ? 'AM' : 'PM';
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
